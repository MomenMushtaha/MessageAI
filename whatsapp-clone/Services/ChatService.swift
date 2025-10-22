//
//  ChatService.swift
//  whatsapp-clone
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
                    
                    // Only update if changed to prevent unnecessary re-renders
                    if conversations.count != self.conversations.count ||
                       conversations.first?.lastMessageAt != self.conversations.first?.lastMessageAt {
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
                
                Task { @MainActor in
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
                            readBy: data["readBy"] as? [String] ?? []
                        )
                    }
                    
                    // Save to local storage
                    for message in firestoreMessages {
                        try? LocalStorageService.shared.saveMessage(message, status: message.status, isSynced: true)
                    }
                    
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
                    
                    // Sort by date
                    mergedMessages.sort { $0.createdAt < $1.createdAt }
                    
                    // Detect new messages for notifications
                    let previousMessages = self.messages[conversationId] ?? []
                    let newMessages = mergedMessages.filter { newMsg in
                        !previousMessages.contains(where: { $0.id == newMsg.id })
                    }
                    
                    self.messages[conversationId] = mergedMessages
                    print("✅ Merged \(mergedMessages.count) messages (Firestore + local)")
                    
                    // Show notifications for new incoming messages
                    if !newMessages.isEmpty {
                        self.showNotificationsForNewMessages(newMessages, conversationId: conversationId)
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
        
        print("📤 Sending message to conversation: \(conversationId)")
        
        // Generate message ID upfront
        let messageId = UUID().uuidString
        
        // Create local message immediately (optimistic UI)
        let localMessage = Message(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            text: trimmedText,
            createdAt: Date(),
            status: "sending"
        )
        
        // Save to local storage first (instant feedback)
        do {
            try LocalStorageService.shared.saveMessage(localMessage, status: "sending", isSynced: false)
            
            // Update local messages array immediately
            var currentMessages = messages[conversationId] ?? []
            currentMessages.append(localMessage)
            messages[conversationId] = currentMessages
        } catch {
            print("⚠️ Failed to save message locally: \(error.localizedDescription)")
        }
        
        // Then send to Firestore
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
            print("✅ Message sent to Firestore")
            
            // Update local status to "sent" and mark as synced
            try? LocalStorageService.shared.updateMessageStatus(messageId, status: "sent", isSynced: true)
            
        } catch {
            print("❌ Error sending message to Firestore: \(error.localizedDescription)")
            
            // Update local status to "error"
            try? LocalStorageService.shared.updateMessageStatus(messageId, status: "error", isSynced: false)
            
            // Update UI
            if var currentMessages = messages[conversationId],
               let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
                currentMessages[index] = Message(
                    id: messageId,
                    conversationId: conversationId,
                    senderId: senderId,
                    text: trimmedText,
                    createdAt: localMessage.createdAt,
                    status: "error"
                )
                messages[conversationId] = currentMessages
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
            
            // Check if conversation already exists
            let conversationRef = db.collection("conversations").document(conversationId)
            let doc = try await conversationRef.getDocument()
            
            if doc.exists {
                print("✅ Conversation already exists: \(conversationId)")
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
            
            try await conversationRef.setData(conversationData)
            print("✅ Conversation created")
            return conversationId
        }
        
        // For group chats, generate random ID
        let conversationRef = db.collection("conversations").document()
        let conversationData: [String: Any] = [
            "type": type.rawValue,
            "participantIds": participantIds,
            "groupName": groupName as Any,
            "createdAt": FieldValue.serverTimestamp(),
            "lastMessageAt": FieldValue.serverTimestamp()
        ]
        
        try await conversationRef.setData(conversationData)
        print("✅ Group conversation created: \(conversationRef.documentID)")
        return conversationRef.documentID
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
    let text: String
    let createdAt: Date
    var status: String // sending, sent, delivered, read
    var deliveredTo: [String] // Array of user IDs who have received the message
    var readBy: [String] // Array of user IDs who have read the message
    
    init(id: String, conversationId: String, senderId: String, text: String, createdAt: Date, status: String = "sent", deliveredTo: [String] = [], readBy: [String] = []) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.createdAt = createdAt
        self.status = status
        self.deliveredTo = deliveredTo
        self.readBy = readBy
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

