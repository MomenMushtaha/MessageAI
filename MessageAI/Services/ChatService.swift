//
//  ChatService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class ChatService: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var messages: [String: [Message]] = [:] // conversationId -> messages
    @Published var allUsers: [User] = []
    
    private let db = Firestore.firestore()
    private var conversationsListener: ListenerRegistration?
    private var messageListeners: [String: ListenerRegistration] = [:]
    private var conversationUpdateTask: Task<Void, Never>?
    private var messageUpdateTasks: [String: Task<Void, Never>] = [:]
    
    // Performance optimizations
    private let messageProcessingQueue = DispatchQueue(label: "com.messageai.messageProcessing", qos: .userInitiated)
    private var messageCache: [String: [Message]] = [:] // In-memory cache for fast lookups
    private var lastMessageCount: [String: Int] = [:] // Track message counts to avoid redundant updates
    
    static let shared = ChatService()
    
    private init() {}
    
    // MARK: - Fetch All Users
    
    func fetchAllUsers(excludingUserId: String) async {
        do {
            print("👥 Fetching all users...")
            let snapshot = try await db.collection("users").getDocuments()
            
            allUsers = snapshot.documents.compactMap { doc -> User? in
                let data = doc.data()
                guard doc.documentID != excludingUserId else { return nil }
                
                return User(
                    id: data["id"] as? String ?? doc.documentID,
                    displayName: data["displayName"] as? String ?? "Unknown",
                    email: data["email"] as? String ?? "",
                    avatarURL: data["avatarURL"] as? String,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    isOnline: data["isOnline"] as? Bool ?? false,
                    lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue()
                )
            }
            
            // Cache all users for faster subsequent access
            CacheManager.shared.cacheUsers(allUsers)
            
            print("✅ Fetched \(allUsers.count) users")
        } catch {
            print("❌ Error fetching users: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Conversations
    
    func observeConversations(userId: String) {
        print("👂 Starting to observe conversations for user: \(userId)")
        
        conversationsListener = db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error observing conversations: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No conversations found")
                    return
                }
                
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    // Cancel any pending update task
                    self.conversationUpdateTask?.cancel()
                    
                    // Add small delay to debounce rapid updates
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    
                    let conversations = documents.compactMap { doc -> Conversation? in
                        let data = doc.data()

                        return Conversation(
                            id: doc.documentID,
                            type: ConversationType(rawValue: data["type"] as? String ?? "direct") ?? .direct,
                            participantIds: data["participantIds"] as? [String] ?? [],
                            lastMessageText: data["lastMessageText"] as? String,
                            lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue(),
                            groupName: data["groupName"] as? String,
                            groupAvatarURL: data["groupAvatarURL"] as? String,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    }

                    // Check if conversations have actually changed
                    let conversationIds = Set(conversations.map { $0.id })
                    let existingIds = Set(self.conversations.map { $0.id })
                    let hasNewConversations = conversationIds != existingIds
                    let countChanged = conversations.count != self.conversations.count
                    let timestampChanged = conversations.first?.lastMessageAt != self.conversations.first?.lastMessageAt

                    // Update if there are new conversations, count changed, or timestamp changed
                    if hasNewConversations || countChanged || timestampChanged {
                        self.conversations = conversations
                        print("✅ Loaded \(conversations.count) conversations")
                    }
                }
            }
    }
    
    func stopObservingConversations() {
        conversationsListener?.remove()
        conversationsListener = nil
        print("🛑 Stopped observing conversations")
    }
    
    // MARK: - Messages
    
    func observeMessages(conversationId: String) {
        // Don't create duplicate listeners
        if messageListeners[conversationId] != nil {
            return
        }
        
        print("👂 Starting to observe messages for conversation: \(conversationId)")
        
        // First, load from local storage (instant)
        Task { @MainActor in
            do {
                let localMessages = try LocalStorageService.shared.getMessages(for: conversationId)
                if !localMessages.isEmpty {
                    self.messages[conversationId] = localMessages
                    self.messageCache[conversationId] = localMessages
                    self.lastMessageCount[conversationId] = localMessages.count
                    print("💾 Loaded \(localMessages.count) messages from local storage")
                }
            } catch {
                print("⚠️ Failed to load local messages: \(error.localizedDescription)")
            }
        }
        
        // Then, observe Firestore for updates (limit to last 100 messages for performance)
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(toLast: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error observing messages: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No messages found")
                    return
                }
                
                // Process messages off main thread for better performance
                Task.detached(priority: .userInitiated) {
                    // Parse Firestore documents (expensive work off main thread)
                    let firestoreMessages = documents.compactMap { doc -> Message? in
                        let data = doc.data()

                        return Message(
                            id: doc.documentID,
                            conversationId: conversationId,
                            senderId: data["senderId"] as? String ?? "",
                            text: data["text"] as? String ?? "",
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                            status: data["status"] as? String ?? "sent",
                            deliveredTo: data["deliveredTo"] as? [String] ?? [],
                            readBy: data["readBy"] as? [String] ?? [],
                            deletedBy: data["deletedBy"] as? [String],
                            deletedForEveryone: data["deletedForEveryone"] as? Bool,
                            editedAt: (data["editedAt"] as? Timestamp)?.dateValue(),
                            editHistory: data["editHistory"] as? [String]
                        )
                    }
                    
                    // Save to local storage in background
                    Task.detached(priority: .background) {
                        for message in firestoreMessages {
                            try? await LocalStorageService.shared.saveMessage(message, status: message.status, isSynced: true)
                        }
                    }
                    
                    // Switch to main actor for UI updates
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        
                        // Cancel any pending update task for this conversation
                        self.messageUpdateTasks[conversationId]?.cancel()
                        
                        // Create new task for debounced update
                        let updateTask = Task { @MainActor in
                            // Add small delay to debounce rapid updates
                            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms (increased from 50ms for better batching)
                            
                            guard !Task.isCancelled else { return }
                            
                            // Merge with local messages (prefer Firestore if synced, keep local if pending)
                            let localMessages = self.messages[conversationId] ?? []
                            let pendingMessages = localMessages.filter { $0.status == "sending" || $0.status == "error" }
                            
                            // Combine: Firestore messages + pending local messages
                            var mergedMessages = firestoreMessages
                            for pendingMsg in pendingMessages {
                                if !mergedMessages.contains(where: { $0.id == pendingMsg.id }) {
                                    mergedMessages.append(pendingMsg)
                                }
                            }
                            
                            // Sort by date (efficient since likely already sorted)
                            mergedMessages.sort { $0.createdAt < $1.createdAt }
                            
                            // Check if we need to update (avoid redundant UI updates)
                            let currentCount = self.lastMessageCount[conversationId] ?? 0
                            let newCount = mergedMessages.count
                            let hasNewMessages = newCount != currentCount
                            
                            if hasNewMessages {
                                // Detect new messages for notifications
                                let previousMessages = self.messages[conversationId] ?? []
                                let newMessages = mergedMessages.filter { newMsg in
                                    !previousMessages.contains(where: { $0.id == newMsg.id })
                                }
                                
                                self.messages[conversationId] = mergedMessages
                                self.messageCache[conversationId] = mergedMessages
                                self.lastMessageCount[conversationId] = newCount
                                print("✅ Merged \(mergedMessages.count) messages (Firestore + local)")
                                
                                // Show notifications for new incoming messages
                                if !newMessages.isEmpty {
                                    self.showNotificationsForNewMessages(newMessages, conversationId: conversationId)
                                }
                            } else {
                                // Even if count is same, check if status changed (e.g., delivered, read)
                                let statusChanged = zip(self.messages[conversationId] ?? [], mergedMessages).contains { old, new in
                                    old.id == new.id && (old.status != new.status || old.deliveredTo != new.deliveredTo || old.readBy != new.readBy)
                                }
                                
                                if statusChanged {
                                    self.messages[conversationId] = mergedMessages
                                    self.messageCache[conversationId] = mergedMessages
                                    print("✅ Updated message statuses")
                                }
                            }
                        }
                        
                        self.messageUpdateTasks[conversationId] = updateTask
                    }
                }
            }
        
        messageListeners[conversationId] = listener
    }
    
    func stopObservingMessages(conversationId: String) {
        messageListeners[conversationId]?.remove()
        messageListeners[conversationId] = nil
        print("🛑 Stopped observing messages for: \(conversationId)")
    }
    
    // MARK: - Show Notifications for New Messages
    
    private func showNotificationsForNewMessages(_ messages: [Message], conversationId: String) {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }
        
        // Filter out messages from current user
        let incomingMessages = messages.filter { $0.senderId != currentUserId }
        
        guard !incomingMessages.isEmpty else { return }
        
        // Show notification for the most recent incoming message
        if let latestMessage = incomingMessages.last {
            // Get conversation to determine if it's a group
            let conversation = conversations.first(where: { $0.id == conversationId })
            let isGroup = conversation?.type == .group
            
            // Get sender name
            Task {
                var senderName = "Unknown"
                if let user = try? await getUser(userId: latestMessage.senderId) {
                    senderName = user.displayName
                }
                
                // Show notification
                NotificationService.shared.showNotification(
                    conversationId: conversationId,
                    senderName: senderName,
                    messageText: latestMessage.text,
                    senderId: latestMessage.senderId,
                    currentUserId: currentUserId,
                    isGroupChat: isGroup
                )
            }
        }
    }
    
    // MARK: - Mark Messages as Delivered
    
    func markMessagesAsDelivered(conversationId: String, userId: String) async {
        print("📬 Marking messages as delivered for user: \(userId)")
        
        do {
            // Get all messages in conversation that are not from this user
            let messagesSnapshot = try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .whereField("senderId", isNotEqualTo: userId)
                .getDocuments()
            
            let batch = db.batch()
            var updateCount = 0
            
            for doc in messagesSnapshot.documents {
                let data = doc.data()
                let deliveredTo = data["deliveredTo"] as? [String] ?? []
                
                // Only update if not already delivered to this user
                if !deliveredTo.contains(userId) {
                    let messageRef = db.collection("conversations")
                        .document(conversationId)
                        .collection("messages")
                        .document(doc.documentID)
                    
                    batch.updateData([
                        "deliveredTo": FieldValue.arrayUnion([userId])
                    ], forDocument: messageRef)
                    updateCount += 1
                }
            }
            
            if updateCount > 0 {
                try await batch.commit()
                print("✅ Marked \(updateCount) messages as delivered")
            }
        } catch {
            print("❌ Error marking messages as delivered: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Mark Messages as Read
    
    func markMessagesAsRead(conversationId: String, userId: String) async {
        print("👁️ Marking messages as read for user: \(userId)")
        
        do {
            // Get all messages in conversation that are not from this user
            let messagesSnapshot = try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .whereField("senderId", isNotEqualTo: userId)
                .getDocuments()
            
            let batch = db.batch()
            var updateCount = 0
            
            for doc in messagesSnapshot.documents {
                let data = doc.data()
                let readBy = data["readBy"] as? [String] ?? []
                let deliveredTo = data["deliveredTo"] as? [String] ?? []
                
                // Only update if not already read by this user
                if !readBy.contains(userId) {
                    let messageRef = db.collection("conversations")
                        .document(conversationId)
                        .collection("messages")
                        .document(doc.documentID)
                    
                    var updates: [String: Any] = [
                        "readBy": FieldValue.arrayUnion([userId])
                    ]
                    
                    // Also mark as delivered if not already
                    if !deliveredTo.contains(userId) {
                        updates["deliveredTo"] = FieldValue.arrayUnion([userId])
                    }
                    
                    batch.updateData(updates, forDocument: messageRef)
                    updateCount += 1
                }
            }
            
            if updateCount > 0 {
                try await batch.commit()
                print("✅ Marked \(updateCount) messages as read")
            }
        } catch {
            print("❌ Error marking messages as read: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Send Message
    
    func sendMessage(conversationId: String, senderId: String, text: String) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate message text
        guard !trimmedText.isEmpty else {
            throw ChatError.emptyMessage
        }
        
        guard trimmedText.count <= 4096 else {
            throw ChatError.messageTooLong
        }
        
        let startTime = Date()
        print("📤 Sending message to conversation: \(conversationId)")
        
        // Generate message ID upfront
        let messageId = UUID().uuidString
        let createdAt = Date()
        
        // Start performance tracking
        await PerformanceMonitor.shared.startMessageSend(messageId: messageId)
        
        // Create local message immediately (optimistic UI)
        let localMessage = Message(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            text: trimmedText,
            createdAt: createdAt,
            status: "sending"
        )
        
        // Update UI immediately (optimistic update for instant feedback)
        var currentMessages = messages[conversationId] ?? []
        currentMessages.append(localMessage)
        messages[conversationId] = currentMessages
        messageCache[conversationId] = currentMessages
        lastMessageCount[conversationId] = currentMessages.count
        
        // Save to local storage asynchronously (don't block UI)
        Task.detached(priority: .userInitiated) {
            try? await LocalStorageService.shared.saveMessage(localMessage, status: "sending", isSynced: false)
        }
        
        // Prepare Firestore data
        let messageData: [String: Any] = [
            "senderId": senderId,
            "text": trimmedText,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "sent",
            "deliveredTo": [], // Will be populated as recipients receive
            "readBy": [] // Will be populated as recipients read
        ]
        
        let conversationRef = db.collection("conversations").document(conversationId)
        let messageRef = conversationRef.collection("messages").document(messageId)
        
        // Use batch write to update conversation and add message atomically
        let batch = db.batch()
        
        // Add message
        batch.setData(messageData, forDocument: messageRef)
        
        // Update conversation's last message
        let conversationUpdate: [String: Any] = [
            "lastMessageText": trimmedText,
            "lastMessageAt": FieldValue.serverTimestamp()
        ]
        batch.updateData(conversationUpdate, forDocument: conversationRef)
        
        do {
            try await batch.commit()
            let duration = Date().timeIntervalSince(startTime)
            print("✅ Message sent to Firestore in \(Int(duration * 1000))ms")
            
            // Complete performance tracking (success)
            await PerformanceMonitor.shared.completeMessageSend(messageId: messageId, success: true)
            
            // Update local status to "sent" and mark as synced (background task)
            Task.detached(priority: .background) {
                try? await LocalStorageService.shared.updateMessageStatus(messageId, status: "sent", isSynced: true)
            }
            
            // Update message status in UI immediately
            await MainActor.run {
                if var currentMessages = self.messages[conversationId],
                   let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
                    currentMessages[index] = Message(
                        id: messageId,
                        conversationId: conversationId,
                        senderId: senderId,
                        text: trimmedText,
                        createdAt: createdAt,
                        status: "sent"
                    )
                    self.messages[conversationId] = currentMessages
                    self.messageCache[conversationId] = currentMessages
                }
            }
            
        } catch {
            print("❌ Error sending message to Firestore: \(error.localizedDescription)")
            
            // Complete performance tracking (failure)
            await PerformanceMonitor.shared.completeMessageSend(messageId: messageId, success: false)
            
            // Update local status to "error" (background task)
            Task.detached(priority: .background) {
                try? await LocalStorageService.shared.updateMessageStatus(messageId, status: "error", isSynced: false)
            }
            
            // Update UI to show error
            await MainActor.run {
                if var currentMessages = self.messages[conversationId],
                   let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
                    currentMessages[index] = Message(
                        id: messageId,
                        conversationId: conversationId,
                        senderId: senderId,
                        text: trimmedText,
                        createdAt: createdAt,
                        status: "error"
                    )
                    self.messages[conversationId] = currentMessages
                    self.messageCache[conversationId] = currentMessages
                }
            }
            
            throw error
        }
    }
    
    // MARK: - Create Conversation
    
    func createOrGetConversation(participantIds: [String], type: ConversationType = .direct, groupName: String? = nil) async throws -> String {
        // For direct chats, use deterministic ID
        if type == .direct && participantIds.count == 2 {
            let sortedIds = participantIds.sorted()
            let conversationId = sortedIds.joined(separator: "_")
            
            // Check if conversation already exists locally
            if conversations.contains(where: { $0.id == conversationId }) {
                print("✅ Conversation already exists locally: \(conversationId)")
                return conversationId
            }
            
            // Check if conversation already exists in Firestore
            let conversationRef = db.collection("conversations").document(conversationId)
            let doc = try await conversationRef.getDocument()
            
            if doc.exists {
                print("✅ Conversation already exists in Firestore: \(conversationId)")
                // Add to local array optimistically if not there yet
                if !conversations.contains(where: { $0.id == conversationId }) {
                    let conversation = Conversation(
                        id: conversationId,
                        type: .direct,
                        participantIds: participantIds,
                        lastMessageText: nil,
                        lastMessageAt: Date(),
                        groupName: nil,
                        groupAvatarURL: nil,
                        createdAt: Date()
                    )
                    conversations.insert(conversation, at: 0)
                    print("✅ Added existing conversation to local array")
                }
                return conversationId
            }
            
            // Create new conversation
            print("📝 Creating new conversation: \(conversationId)")
            let conversationData: [String: Any] = [
                "type": type.rawValue,
                "participantIds": participantIds,
                "createdAt": FieldValue.serverTimestamp(),
                "lastMessageAt": FieldValue.serverTimestamp()
            ]
            
            // Optimistically add to local array immediately
            let optimisticConversation = Conversation(
                id: conversationId,
                type: .direct,
                participantIds: participantIds,
                lastMessageText: nil,
                lastMessageAt: Date(),
                groupName: nil,
                groupAvatarURL: nil,
                createdAt: Date()
            )
            conversations.insert(optimisticConversation, at: 0)
            print("✅ Optimistically added conversation to local array")
            
            // Write to Firestore (will be confirmed by listener)
            try await conversationRef.setData(conversationData)
            print("✅ Conversation created in Firestore")
            
            return conversationId
        }
        
        // For group chats, generate random ID
        let conversationRef = db.collection("conversations").document()
        let conversationId = conversationRef.documentID
        
        print("📝 Creating new group conversation: \(conversationId)")
        let conversationData: [String: Any] = [
            "type": type.rawValue,
            "participantIds": participantIds,
            "groupName": groupName as Any,
            "createdAt": FieldValue.serverTimestamp(),
            "lastMessageAt": FieldValue.serverTimestamp()
        ]
        
        // Optimistically add to local array immediately
        let optimisticConversation = Conversation(
            id: conversationId,
            type: .group,
            participantIds: participantIds,
            lastMessageText: nil,
            lastMessageAt: Date(),
            groupName: groupName,
            groupAvatarURL: nil,
            createdAt: Date()
        )
        conversations.insert(optimisticConversation, at: 0)
        print("✅ Optimistically added group to local array")
        
        // Write to Firestore (will be confirmed by listener)
        try await conversationRef.setData(conversationData)
        print("✅ Group conversation created in Firestore")
        
        return conversationId
    }
    
    // MARK: - Delete Conversation
    
    /// Deletes a conversation and all its messages
    func deleteConversation(conversationId: String) async throws {
        print("🗑️ Deleting conversation: \(conversationId)")
        
        // Optimistically remove from local array first for instant UI feedback
        conversations.removeAll { $0.id == conversationId }
        messages.removeValue(forKey: conversationId)
        
        // Stop listening to messages for this conversation
        if let listener = messageListeners[conversationId] {
            listener.remove()
            messageListeners.removeValue(forKey: conversationId)
        }
        
        do {
            // Delete all messages in the conversation
            let messagesSnapshot = try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .getDocuments()
            
            // Batch delete messages for efficiency
            let batch = db.batch()
            for document in messagesSnapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
            print("✅ Deleted \(messagesSnapshot.documents.count) messages")
            
            // Delete the conversation document
            try await db.collection("conversations").document(conversationId).delete()
            print("✅ Conversation deleted successfully")
            
            // Clear local storage for this conversation (on main actor)
            await MainActor.run {
                try? LocalStorageService.shared.deleteMessages(for: conversationId)
                try? LocalStorageService.shared.deleteConversation(id: conversationId)
            }
            
        } catch {
            print("❌ Error deleting conversation: \(error.localizedDescription)")
            // Re-throw so UI can handle the error
            throw error
        }
    }
    
    // MARK: - Clear Chat History
    
    /// Clears chat history locally for the current user only
    /// Messages remain in Firestore and visible to other participants
    func clearChatHistory(conversationId: String) async throws {
        print("🗑️ Clearing chat history for conversation: \(conversationId)")
        
        // Delete local messages only
        try LocalStorageService.shared.deleteMessages(for: conversationId)
        
        // Clear from memory
        messages[conversationId] = []
        
        print("✅ Chat history cleared locally for conversation: \(conversationId)")
    }
    
    // MARK: - Get User
    
    func getUser(userId: String) async throws -> User? {
        // Check cache first for better performance
        if let cachedUser = CacheManager.shared.getCachedUser(id: userId) {
            return cachedUser
        }
        
        // If not in cache, fetch from Firestore
        let doc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = doc.data() else {
            return nil
        }
        
        let user = User(
            id: data["id"] as? String ?? userId,
            displayName: data["displayName"] as? String ?? "Unknown",
            email: data["email"] as? String ?? "",
            avatarURL: data["avatarURL"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            isOnline: data["isOnline"] as? Bool ?? false,
            lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue()
        )
        
        // Cache for future use
        CacheManager.shared.cacheUser(user)
        
        return user
    }

    // MARK: - Message Deletion

    /// Delete a message for the current user or for everyone
    /// - Parameters:
    ///   - messageId: The ID of the message to delete
    ///   - conversationId: The conversation containing the message
    ///   - deleteForEveryone: If true, delete for all users (sender only)
    func deleteMessage(messageId: String, conversationId: String, deleteForEveryone: Bool) async throws {
        guard let currentUserId = AuthService.shared.currentUser?.id else {
            throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Find the message in local cache for optimistic update
        guard var conversationMessages = messages[conversationId],
              let messageIndex = conversationMessages.firstIndex(where: { $0.id == messageId }) else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Message not found"])
        }

        // Store original message for rollback
        let originalMessage = conversationMessages[messageIndex]

        // OPTIMISTIC UPDATE: Modify local state immediately
        var updatedMessage = originalMessage

        if deleteForEveryone {
            // Verify user is the sender (permission check)
            guard originalMessage.senderId == currentUserId else {
                throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the sender can delete for everyone"])
            }

            updatedMessage.text = "[Message deleted]"
            updatedMessage.deletedForEveryone = true
        }

        updatedMessage.deletedBy = (updatedMessage.deletedBy ?? []) + [currentUserId]
        conversationMessages[messageIndex] = updatedMessage
        messages[conversationId] = conversationMessages

        print("🔄 Optimistically updated message \(messageId)")

        // Now update Firestore in background
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)

        do {
            if deleteForEveryone {
                print("🗑️ Deleting message \(messageId) for everyone")

                try await messageRef.updateData([
                    "text": "[Message deleted]",
                    "deletedForEveryone": true,
                    "deletedBy": FieldValue.arrayUnion([currentUserId])
                ])

                print("✅ Message deleted for everyone - confirmed by server")
            } else {
                print("🗑️ Marking message \(messageId) as deleted for user \(currentUserId)")

                try await messageRef.updateData([
                    "deletedBy": FieldValue.arrayUnion([currentUserId])
                ])

                print("✅ Message marked as deleted for current user - confirmed by server")
            }

        } catch {
            // ROLLBACK: Restore original message on failure
            print("❌ Deletion failed, rolling back to original state")

            guard var messages = messages[conversationId],
                  let index = messages.firstIndex(where: { $0.id == messageId }) else {
                throw error
            }

            messages[index] = originalMessage
            self.messages[conversationId] = messages

            throw error
        }
    }

    // MARK: - Message Editing

    /// Edit a message's text content
    /// - Parameters:
    ///   - messageId: The ID of the message to edit
    ///   - conversationId: The conversation containing the message
    ///   - newText: The new text content for the message
    func editMessage(messageId: String, conversationId: String, newText: String) async throws {
        // TODO: Implement in next step
        print("⚠️ editMessage called - not yet implemented")
        print("   messageId: \(messageId)")
        print("   conversationId: \(conversationId)")
        print("   newText: \(newText)")
    }

    // MARK: - Sync Pending Messages
    
    func syncPendingMessages() async {
        print("🔄 Syncing pending messages...")
        
        do {
            let pendingMessages = try LocalStorageService.shared.getPendingMessages()
            print("📤 Found \(pendingMessages.count) pending messages to sync")
            
            for localMessage in pendingMessages {
                let message = localMessage.toMessage()
                
                do {
                    // Try to send to Firestore
                    let messageData: [String: Any] = [
                        "senderId": message.senderId,
                        "text": message.text,
                        "createdAt": Timestamp(date: message.createdAt),
                        "status": "sent"
                    ]
                    
                    let messageRef = db.collection("conversations")
                        .document(message.conversationId)
                        .collection("messages")
                        .document(message.id)
                    
                    try await messageRef.setData(messageData)
                    
                    // Update local status
                    try? LocalStorageService.shared.updateMessageStatus(message.id, status: "sent", isSynced: true)
                    print("✅ Synced message: \(message.id)")
                    
                } catch {
                    print("❌ Failed to sync message \(message.id): \(error.localizedDescription)")
                }
            }
        } catch {
            print("❌ Error fetching pending messages: \(error.localizedDescription)")
        }
    }
    
    deinit {
        conversationsListener?.remove()
        messageListeners.values.forEach { $0.remove() }
    }
}

// MARK: - Chat Errors

enum ChatError: LocalizedError {
    case emptyMessage
    case messageTooLong
    case networkError
    case invalidConversation
    
    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Message cannot be empty"
        case .messageTooLong:
            return "Message is too long (max 4096 characters)"
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .invalidConversation:
            return "Invalid conversation"
        }
    }
}

// MARK: - Message Model

struct Message: Identifiable, Codable, Hashable {
    let id: String
    let conversationId: String
    let senderId: String
    var text: String // mutable for "delete for everyone" and editing
    let createdAt: Date
    var status: String // sending, sent, delivered, read
    var deliveredTo: [String] // Array of user IDs who have received the message
    var readBy: [String] // Array of user IDs who have read the message
    var deletedBy: [String]? // Array of user IDs who have deleted this message
    var deletedForEveryone: Bool? // Flag indicating message was deleted for everyone
    var editedAt: Date? // Timestamp when message was last edited
    var editHistory: [String]? // Array of previous message text versions (optional)

    init(id: String, conversationId: String, senderId: String, text: String, createdAt: Date, status: String = "sent", deliveredTo: [String] = [], readBy: [String] = [], deletedBy: [String]? = nil, deletedForEveryone: Bool? = nil, editedAt: Date? = nil, editHistory: [String]? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.createdAt = createdAt
        self.status = status
        self.deliveredTo = deliveredTo
        self.readBy = readBy
        self.deletedBy = deletedBy
        self.deletedForEveryone = deletedForEveryone
        self.editedAt = editedAt
        self.editHistory = editHistory
    }
    
    // Helper to determine overall status for UI display
    func displayStatus(for conversation: Conversation, currentUserId: String) -> String {
        // Only show status for messages sent by current user
        guard senderId == currentUserId else { return "" }
        
        // If still sending or error, show that status
        if status == "sending" || status == "error" {
            return status
        }
        
        // Get other participants (excluding sender)
        let otherParticipants = conversation.participantIds.filter { $0 != senderId }
        
        if otherParticipants.isEmpty {
            return "sent"
        }
        
        // Check if all recipients have read
        let allRead = otherParticipants.allSatisfy { readBy.contains($0) }
        if allRead {
            return "read"
        }
        
        // Check if all recipients have received
        let allDelivered = otherParticipants.allSatisfy { deliveredTo.contains($0) }
        if allDelivered {
            return "delivered"
        }
        
        // Otherwise just sent
        return "sent"
    }
}

// MARK: - Message Deletion Helpers

extension Message {
    /// Check if this message is deleted for a specific user
    func isDeleted(for userId: String) -> Bool {
        return deletedBy?.contains(userId) ?? false
    }

    /// Check if message is deleted for everyone
    var isDeletedForEveryone: Bool {
        return deletedForEveryone == true
    }
}

// MARK: - Message Editing Helpers

extension Message {
    /// Check if this message can be edited
    /// Rules: Only sender, within 15 minutes, not deleted
    func canEdit(by userId: String) -> Bool {
        // Must be the sender
        guard senderId == userId else { return false }

        // Cannot edit deleted messages
        guard !isDeleted(for: userId) else { return false }

        // Must be within 15 minutes of creation
        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        return createdAt > fifteenMinutesAgo
    }

    /// Check if this message was edited
    var wasEdited: Bool {
        return editedAt != nil
    }
}

