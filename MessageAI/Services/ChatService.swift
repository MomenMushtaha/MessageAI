//
//  ChatService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import FirebaseDatabase
import Combine
import UIKit

@MainActor
class ChatService: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var messages: [String: [Message]] = [:] // conversationId -> messages
    @Published var allUsers: [User] = []

    private let db = Database.database().reference()
    private var conversationsListener: DatabaseHandle?
    private var messageListeners: [String: DatabaseHandle] = [:]
    private var conversationUpdateTask: Task<Void, Never>?
    private var messageUpdateTasks: [String: Task<Void, Never>] = [:]

    // Performance optimizations
    private let messageProcessingQueue = DispatchQueue(label: "com.messageai.messageProcessing", qos: .userInitiated)
    private var messageCache: [String: [Message]] = [:] // In-memory cache for fast lookups
    private var lastMessageCount: [String: Int] = [:] // Track message counts to avoid redundant updates

    // Pagination
    private let messagesPerPage = 50
    @Published var isLoadingMoreMessages: [String: Bool] = [:] // conversationId -> isLoading
    @Published var hasMoreMessages: [String: Bool] = [:] // conversationId -> hasMore
    
    static let shared = ChatService()
    
    private init() {}
    
    // MARK: - Participant Helpers
    
    private func buildParticipantMap(from participantIds: [String]) -> [String: Bool] {
        var map: [String: Bool] = [:]
        for id in participantIds {
            map[id] = true
        }
        return map
    }
    
    private func extractParticipantIds(from data: [String: Any]) -> [String] {
        if let ids = data["participantIds"] as? [String] {
            return ids
        }
        
        if let anyIds = data["participantIds"] as? [Any] {
            return anyIds.compactMap { $0 as? String }
        }
        
        if let map = data["participantMap"] as? [String: Any] {
            return map.compactMap { key, value in
                if let boolValue = value as? Bool {
                    return boolValue ? key : nil
                }
                
                if let dictValue = value as? [String: Any] {
                    if let isParticipant = dictValue["isParticipant"] as? Bool {
                        return isParticipant ? key : nil
                    }
                    if let enabled = dictValue["enabled"] as? Bool {
                        return enabled ? key : nil
                    }
                }
                
                return nil
            }
        }
        
        return []
    }
    
    // MARK: - Fetch All Users
    
    func fetchAllUsers(excludingUserId: String) async {
        do {
            print("👥 Fetching all users (excluding: \(excludingUserId))...")
            let snapshot = try await db.child("users").getData()

            print("📊 Snapshot exists: \(snapshot.exists())")

            guard snapshot.exists() else {
                print("⚠️ /users node does not exist in Firebase RTDB")
                allUsers = []
                return
            }

            guard let usersDict = snapshot.value as? [String: [String: Any]] else {
                print("⚠️ Could not parse users data as [String: [String: Any]]")
                print("⚠️ Actual type: \(type(of: snapshot.value))")
                allUsers = []
                return
            }

            print("📊 Found \(usersDict.count) total users in database")
            print("📋 All user IDs in database: \(usersDict.keys.sorted())")

            allUsers = usersDict.compactMap { (userId, data) -> User? in
                print("🔍 Processing user ID: \(userId)")

                guard userId != excludingUserId else {
                    print("⏭️ Skipping current user: \(userId)")
                    return nil
                }

                let displayName = data["displayName"] as? String ?? "Unknown"
                let email = data["email"] as? String ?? ""
                print("✅ Adding user: \(userId) - \(displayName) (\(email))")

                return User(
                    id: data["id"] as? String ?? userId,
                    displayName: displayName,
                    email: email,
                    avatarURL: data["avatarURL"] as? String,
                    createdAt: Date(timeIntervalSince1970: (data["createdAt"] as? TimeInterval ?? 0) / 1000),
                    isOnline: data["isOnline"] as? Bool ?? false,
                    lastSeen: {
                        if let timestamp = data["lastSeen"] as? TimeInterval {
                            return Date(timeIntervalSince1970: timestamp / 1000)
                        }
                        return nil
                    }()
                )
            }

            // Cache all users for faster subsequent access
            CacheManager.shared.cacheUsers(allUsers)

            print("✅ Fetched \(allUsers.count) users (excluding current user)")
            print("📋 Final user list: \(allUsers.map { "\($0.displayName) (\($0.email))" }.joined(separator: ", "))")
        } catch {
            print("❌ Error fetching users: \(error.localizedDescription)")
            allUsers = []
        }
    }
    
    // MARK: - Conversations
    
    func observeConversations(userId: String) {
        print("👂 Starting to observe conversations for user: \(userId)")
        
        // First, load from local storage (instant)
        Task { @MainActor in
            do {
                let localConversations = try LocalStorageService.shared.getConversations(for: userId)
                if !localConversations.isEmpty {
                    self.conversations = localConversations
                    print("💾 Loaded \(localConversations.count) conversations from local storage")
                }
            } catch {
                print("⚠️ Failed to load local conversations: \(error.localizedDescription)")
            }
        }
        
        conversationsListener = db.child("conversations")
            .queryOrdered(byChild: "lastMessageAt")
            .observe(.value, with: { [weak self] snapshot in
                guard let self = self else { return }
                
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    // Cancel any pending update task
                    self.conversationUpdateTask?.cancel()
                    
                    // Add small delay to debounce rapid updates
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    
                    guard let conversationsDict = snapshot.value as? [String: [String: Any]] else {
                        print("⚠️ No conversations found")
                        return
                    }
                    
                    var allConversations = conversationsDict.compactMap { (convId, data) -> Conversation? in
                        let participantIds = self.extractParticipantIds(from: data)
                        guard participantIds.contains(userId) else {
                            return nil
                        }

                        // Parse group-specific fields
                        let ownerId = data["ownerId"] as? String
                        let adminIds = data["adminIds"] as? [String]
                        let groupDescription = data["groupDescription"] as? String
                        
                        // Parse unread counts
                        var unreadCounts: [String: Int]?
                        if let unreadData = data["unreadCounts"] as? [String: Int] {
                            unreadCounts = unreadData
                        }
                        
                        // Parse pinned messages
                        var pinnedMessageIds: [String]?
                        if let pinnedData = data["pinnedMessageIds"] as? [String] {
                            pinnedMessageIds = pinnedData
                        }
                        
                        // Parse member join dates
                        var memberJoinDates: [String: Date]?
                        if let joinDatesData = data["memberJoinDates"] as? [String: TimeInterval] {
                            memberJoinDates = joinDatesData.mapValues { Date(timeIntervalSince1970: $0 / 1000) }
                        }
                        
                        // Parse participant settings
                        var participantSettings: [String: ParticipantSettings]?
                        if let settingsData = data["participantSettings"] as? [String: [String: Any]] {
                            participantSettings = settingsData.compactMapValues { settings in
                                let isMuted = settings["isMuted"] as? Bool ?? false
                                var muteUntil: Date?
                                if let muteTimestamp = settings["muteUntil"] as? TimeInterval {
                                    muteUntil = Date(timeIntervalSince1970: muteTimestamp / 1000)
                                }
                                return ParticipantSettings(isMuted: isMuted, muteUntil: muteUntil)
                            }
                        }
                        
                        // Parse group permissions
                        var groupPermissions: GroupPermissions?
                        if let permissionsData = data["groupPermissions"] as? [String: Any] {
                            let onlyAdminsCanMessage = permissionsData["onlyAdminsCanMessage"] as? Bool ?? false
                            let onlyAdminsCanAddMembers = permissionsData["onlyAdminsCanAddMembers"] as? Bool ?? false
                            groupPermissions = GroupPermissions(
                                onlyAdminsCanMessage: onlyAdminsCanMessage,
                                onlyAdminsCanAddMembers: onlyAdminsCanAddMembers
                            )
                        }

                        var conversation = Conversation(
                            id: convId,
                            type: ConversationType(rawValue: data["type"] as? String ?? "direct") ?? .direct,
                            participantIds: participantIds,
                            lastMessageText: data["lastMessageText"] as? String,
                            lastMessageAt: {
                                if let timestamp = data["lastMessageAt"] as? TimeInterval {
                                    return Date(timeIntervalSince1970: timestamp / 1000)
                                }
                                return nil
                            }(),
                            groupName: data["groupName"] as? String,
                            groupDescription: groupDescription,
                            groupAvatarURL: data["groupAvatarURL"] as? String,
                            ownerId: ownerId,
                            adminIds: adminIds,
                            createdAt: Date(timeIntervalSince1970: (data["createdAt"] as? TimeInterval ?? 0) / 1000)
                        )
                        
                        // Set additional properties
                        conversation.unreadCounts = unreadCounts
                        conversation.pinnedMessageIds = pinnedMessageIds
                        conversation.participantSettings = participantSettings
                        conversation.memberJoinDates = memberJoinDates
                        conversation.groupPermissions = groupPermissions
                        
                        return conversation
                    }

                    // Filter out conversations the user has deleted (unless new messages arrived)
                    var conversations: [Conversation] = []
                    for conv in allConversations {
                        // Check if user has deleted this conversation
                        let deletedSnapshot = try? await self.db.child("conversations")
                            .child(conv.id)
                            .child("participantSettings")
                            .child(userId)
                            .child("deletedAt")
                            .getData()

                        // Check if conversation was deleted
                        if let deletedTimestamp = deletedSnapshot?.value as? TimeInterval {
                            // Conversation was deleted - only show if there are new messages after deletion
                            if let lastMessageAt = conv.lastMessageAt {
                                let lastMessageTimestamp = lastMessageAt.timeIntervalSince1970 * 1000
                                if lastMessageTimestamp > deletedTimestamp {
                                    // New messages since deletion - show the conversation
                                    print("📬 Conversation \(conv.id) reappearing (new messages after deletion)")
                                    conversations.append(conv)
                                } else {
                                    // No new messages - keep it hidden
                                    print("🗑️ Hiding conversation \(conv.id) (deleted by user, no new messages)")
                                }
                            } else {
                                // No lastMessageAt - keep it hidden
                                print("🗑️ Hiding conversation \(conv.id) (deleted by user, no messages)")
                            }
                        } else {
                            // Not deleted - always show
                            conversations.append(conv)
                        }
                    }

                    // Sort by most recent
                    conversations.sort { ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt) }

                    // Check if conversations have actually changed
                    let conversationIds = Set(conversations.map { $0.id })
                    let existingIds = Set(self.conversations.map { $0.id })
                    let hasNewConversations = conversationIds != existingIds
                    let countChanged = conversations.count != self.conversations.count

                    // Update if there are new conversations or count changed
                    if hasNewConversations || countChanged {
                        self.conversations = conversations
                        print("✅ Loaded \(conversations.count) conversations")
                        
                        // Save conversations to local storage in background
                        Task.detached(priority: .background) {
                            for conversation in conversations {
                                try? await LocalStorageService.shared.saveConversation(conversation, isSynced: true)
                            }
                        }
                    }
                }
            })
    }
    
    func stopObservingConversations() {
        if let handle = conversationsListener {
            db.child("conversations").removeObserver(withHandle: handle)
        conversationsListener = nil
        }
        print("🛑 Stopped observing conversations")
    }
    
    // MARK: - Messages
    
    func observeMessages(conversationId: String) {
        // Don't create duplicate listeners
        if messageListeners[conversationId] != nil {
            return
        }
        
        print("👂 Starting to observe messages for conversation: \(conversationId)")

        // Initialize pagination state
        hasMoreMessages[conversationId] = true

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
        
        // Then, observe Realtime Database for updates (limit to recent messages for performance)
        let handle = db.child("conversations").child(conversationId).child("messages")
            .queryLimited(toLast: UInt(messagesPerPage))
            .observe(.value, with: { [weak self] snapshot in
                guard let self = self else { return }

                Task.detached(priority: .userInitiated) {
                    // Get current user ID and clearedAt timestamp
                    let currentUserId = await AuthService.shared.currentUser?.id
                    var clearedAt: TimeInterval = 0

                    if let userId = currentUserId {
                        do {
                            let clearedSnapshot = try await self.db.child("conversations")
                                .child(conversationId)
                                .child("participantSettings")
                                .child(userId)
                                .child("clearedAt")
                                .getData()

                            if let timestamp = clearedSnapshot.value as? TimeInterval {
                                clearedAt = timestamp
                                print("📋 User cleared chat at: \(Date(timeIntervalSince1970: timestamp / 1000))")
                            }
                        } catch {
                            print("⚠️ Failed to fetch clearedAt timestamp: \(error)")
                        }
                    }

                    // Parse database snapshot (expensive work off main thread)
                    guard let messagesDict = snapshot.value as? [String: [String: Any]] else {
                    print("⚠️ No messages found")
                    return
                }

                    let allMessages = messagesDict.compactMap { (msgId, data) -> Message? in
                        let editedAtDate: Date? = {
                            if let timestamp = data["editedAt"] as? TimeInterval { return Date(timeIntervalSince1970: timestamp / 1000) }
                            return nil
                        }()
                        return Message(
                            id: msgId,
                            conversationId: conversationId,
                            senderId: data["senderId"] as? String ?? "",
                            text: data["text"] as? String ?? "",
                            createdAt: Date(timeIntervalSince1970: (data["createdAt"] as? TimeInterval ?? 0) / 1000),
                            status: data["status"] as? String ?? "sent",
                            deliveredTo: data["deliveredTo"] as? [String] ?? [],
                            readBy: data["readBy"] as? [String] ?? [],
                            deletedBy: data["deletedBy"] as? [String],
                            deletedForEveryone: data["deletedForEveryone"] as? Bool,
                            editedAt: editedAtDate,
                            editHistory: data["editHistory"] as? [String],
                            reactions: data["reactions"] as? [String: [String]],
                            mediaType: data["mediaType"] as? String,
                            mediaURL: data["mediaURL"] as? String,
                            thumbnailURL: data["thumbnailURL"] as? String,
                            audioDuration: data["audioDuration"] as? TimeInterval,
                            videoDuration: data["videoDuration"] as? TimeInterval
                        )
                    }

                    // Filter messages based on clearedAt timestamp
                    let dbMessages: [Message]
                    if clearedAt > 0 {
                        dbMessages = allMessages.filter { message in
                            let messageTimestamp = message.createdAt.timeIntervalSince1970 * 1000
                            return messageTimestamp > clearedAt
                        }
                        let filteredCount = allMessages.count - dbMessages.count
                        if filteredCount > 0 {
                            print("🔽 Filtered out \(filteredCount) messages (cleared by user)")
                        }
                    } else {
                        dbMessages = allMessages
                    }

                    // Save to local storage in background
                    Task.detached(priority: .background) {
                        for message in dbMessages {
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
                            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                            
                            guard !Task.isCancelled else { return }
                            
                            // Merge with local messages (prefer DB if synced, keep local if pending)
                            let localMessages = self.messages[conversationId] ?? []
                            let pendingMessages = localMessages.filter { $0.status == "sending" || $0.status == "error" }
                            
                            // Combine: DB messages + pending local messages
                            var mergedMessages = dbMessages
                            for pendingMsg in pendingMessages {
                                if !mergedMessages.contains(where: { $0.id == pendingMsg.id }) {
                                    mergedMessages.append(pendingMsg)
                                }
                            }
                            
                            // Sort by date
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
                                print("✅ Merged \(mergedMessages.count) messages (DB + local)")
                                
                                // Show notifications for new incoming messages
                                if !newMessages.isEmpty {
                                    self.showNotificationsForNewMessages(newMessages, conversationId: conversationId)
                                }
                            }
                        }
                        
                        self.messageUpdateTasks[conversationId] = updateTask
                    }
                }
            })
        
        messageListeners[conversationId] = handle
    }
    
    func stopObservingMessages(conversationId: String) {
        if let handle = messageListeners[conversationId] {
            db.child("conversations").child(conversationId).child("messages").removeObserver(withHandle: handle)
        messageListeners[conversationId] = nil
        }
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

    // MARK: - Send Message
    
    func sendMessage(conversationId: String, senderId: String, text: String) async throws {
        // Check rate limit
        let rateLimitCheck = await RateLimiter.shared.canSendMessage()
        guard rateLimitCheck.allowed else {
            throw NSError(domain: "ChatService", code: 429, userInfo: [NSLocalizedDescriptionKey: rateLimitCheck.reason ?? "Rate limit exceeded"])
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate message text
        guard !trimmedText.isEmpty else {
            throw ChatError.emptyMessage
        }

        guard trimmedText.count <= 4096 else {
            throw ChatError.messageTooLong
        }

        // Record message sent for rate limiting
        await RateLimiter.shared.recordMessageSent()

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
        
        // Prepare database data
        let messageData: [String: Any] = [
            "senderId": senderId,
            "text": trimmedText,
            "createdAt": ServerValue.timestamp(),
            "status": "sent",
            "deliveredTo": [], // Will be populated as recipients receive
            "readBy": [] // Will be populated as recipients read
        ]
        
        let conversationRef = db.child("conversations").child(conversationId)
        let messageRef = conversationRef.child("messages").child(messageId)
        
        do {
            // Write message
            try await messageRef.setValue(messageData)
        
        // Update conversation's last message
        let conversationUpdate: [String: Any] = [
            "lastMessageText": trimmedText,
                "lastMessageAt": ServerValue.timestamp()
        ]
            try await conversationRef.updateChildValues(conversationUpdate)
        
            let duration = Date().timeIntervalSince(startTime)
            print("✅ Message sent to Realtime Database in \(Int(duration * 1000))ms")
            
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
            print("❌ Error sending message to Realtime Database: \(error.localizedDescription)")
            
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
    
    func createOrGetConversation(participantIds: [String], type: ConversationType = .direct, groupName: String? = nil, ownerId: String? = nil) async throws -> String {
        // For direct chats, use deterministic ID
        if type == .direct && participantIds.count == 2 {
            let sortedIds = participantIds.sorted()
            let conversationId = sortedIds.joined(separator: "_")
            let participantMap = buildParticipantMap(from: sortedIds)
            
            // Check if conversation already exists locally
            if conversations.contains(where: { $0.id == conversationId }) {
                print("✅ Conversation already exists locally: \(conversationId)")
                return conversationId
            }
            
            // Check if conversation already exists in database
            let conversationRef = db.child("conversations").child(conversationId)
            let snapshot = try await conversationRef.getData()
            
            if snapshot.exists() {
                print("✅ Conversation already exists in database: \(conversationId)")
                
                if snapshot.childSnapshot(forPath: "participantMap").value == nil {
                    try await conversationRef.child("participantMap").setValue(participantMap)
                    print("🧩 Backfilled participantMap for existing conversation")
                }

                // Add to local array optimistically if not there yet
                if !conversations.contains(where: { $0.id == conversationId }) {
                    let conversation = Conversation(
                        id: conversationId,
                        type: .direct,
                        participantIds: sortedIds,
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
                "participantIds": sortedIds,
                "participantMap": participantMap,
                "createdAt": ServerValue.timestamp(),
                "lastMessageAt": ServerValue.timestamp()
            ]
            
            // Optimistically add to local array immediately
            let optimisticConversation = Conversation(
                id: conversationId,
                type: .direct,
                participantIds: sortedIds,
                lastMessageText: nil,
                lastMessageAt: Date(),
                groupName: nil,
                groupAvatarURL: nil,
                createdAt: Date()
            )
            conversations.insert(optimisticConversation, at: 0)
            print("✅ Optimistically added conversation to local array")
            
            // Write to database (will be confirmed by listener)
            try await conversationRef.setValue(conversationData)
            print("✅ Conversation created in database")
            
            return conversationId
        }
        
        // For group chats, generate random ID
        let conversationId = UUID().uuidString
        let conversationRef = db.child("conversations").child(conversationId)
        
        print("📝 Creating new group conversation: \(conversationId)")
        let participantMap = buildParticipantMap(from: participantIds)
        
        // For groups, set the owner and make them the first admin
        var conversationData: [String: Any] = [
            "type": type.rawValue,
            "participantIds": participantIds,
            "participantMap": participantMap,
            "groupName": groupName as Any,
            "createdAt": ServerValue.timestamp(),
            "lastMessageAt": ServerValue.timestamp()
        ]
        
        if let ownerId = ownerId {
            conversationData["ownerId"] = ownerId
            conversationData["adminIds"] = [ownerId] // Owner is the first admin
        }
        
        // Optimistically add to local array immediately
        let optimisticConversation = Conversation(
            id: conversationId,
            type: .group,
            participantIds: participantIds,
            lastMessageText: nil,
            lastMessageAt: Date(),
            groupName: groupName,
            groupAvatarURL: nil,
            ownerId: ownerId,
            adminIds: ownerId != nil ? [ownerId!] : nil,
            createdAt: Date()
        )
        conversations.insert(optimisticConversation, at: 0)
        print("✅ Optimistically added group to local array")
        
        // Write to database (will be confirmed by listener)
        try await conversationRef.setValue(conversationData)
        print("✅ Group conversation created in database with owner: \(ownerId ?? "none")")
        
        return conversationId
    }
    
    // MARK: - Mark Messages as Delivered/Read
    
    func markMessagesAsDelivered(conversationId: String, userId: String) async {
        print("📬 Marking messages as delivered for user: \(userId)")
        
        do {
            let messagesSnapshot = try await db.child("conversations")
                .child(conversationId)
                .child("messages")
                .getData()
            
            guard let messagesDict = messagesSnapshot.value as? [String: [String: Any]] else {
                print("⚠️ No messages found")
                return
            }
            
            var updateCount = 0
            
            for (messageId, messageData) in messagesDict {
                let senderId = messageData["senderId"] as? String ?? ""
                
                // Only mark messages not from this user
                guard senderId != userId else { continue }
                
                let deliveredTo = messageData["deliveredTo"] as? [String] ?? []
                
                // Only update if not already delivered
                if !deliveredTo.contains(userId) {
                    var newDeliveredTo = deliveredTo
                    newDeliveredTo.append(userId)
                    
                    try await db.child("conversations")
                        .child(conversationId)
                        .child("messages")
                        .child(messageId)
                        .child("deliveredTo")
                        .setValue(newDeliveredTo)
                    
                    updateCount += 1
                }
            }
            
            if updateCount > 0 {
                print("✅ Marked \(updateCount) messages as delivered")
            }
        } catch {
            print("❌ Error marking messages as delivered: \(error.localizedDescription)")
        }
    }
    
    func markMessagesAsRead(conversationId: String, userId: String) async {
        print("👁️ Marking messages as read for user: \(userId)")
        
        do {
            // Check if user has read receipts enabled
            let userSnapshot = try await db.child("users").child(userId).getData()
            let userData = userSnapshot.value as? [String: Any]
            let privacySettings = userData?["privacySettings"] as? [String: Any]
            let shouldMarkAsRead = privacySettings?["showReadReceipts"] as? Bool ?? true
            
            let messagesSnapshot = try await db.child("conversations")
                .child(conversationId)
                .child("messages")
                .getData()
            
            guard let messagesDict = messagesSnapshot.value as? [String: [String: Any]] else {
                print("⚠️ No messages found")
                return
            }
            
            var updateCount = 0
            
            for (messageId, messageData) in messagesDict {
                let senderId = messageData["senderId"] as? String ?? ""
                
                // Only mark messages not from this user
                guard senderId != userId else { continue }
                
                let readBy = messageData["readBy"] as? [String] ?? []
                let deliveredTo = messageData["deliveredTo"] as? [String] ?? []
                
                var updates: [String: Any] = [:]
                
                // Mark as read if privacy allows
                if shouldMarkAsRead && !readBy.contains(userId) {
                    var newReadBy = readBy
                    newReadBy.append(userId)
                    updates["readBy"] = newReadBy
                }
                
                // Always mark as delivered
                if !deliveredTo.contains(userId) {
                    var newDeliveredTo = deliveredTo
                    newDeliveredTo.append(userId)
                    updates["deliveredTo"] = newDeliveredTo
                }
                
                if !updates.isEmpty {
                    try await db.child("conversations")
                        .child(conversationId)
                        .child("messages")
                        .child(messageId)
                        .updateChildValues(updates)
                    
                    updateCount += 1
                }
            }
            
            if updateCount > 0 {
                print("✅ Marked \(updateCount) messages as read/delivered")
                
                // Clear unread count for this conversation
                try await db.child("conversations")
                    .child(conversationId)
                    .child("unreadCounts")
                    .child(userId)
                    .setValue(0)
            }
        } catch {
            print("❌ Error marking messages as read: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Message Actions
    
    func deleteMessage(messageId: String, conversationId: String, deleteForEveryone: Bool) async throws {
        guard let currentUserId = AuthService.shared.currentUser?.id else {
            throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        print("🗑️ Deleting message \(messageId) - deleteForEveryone: \(deleteForEveryone)")
        
        let messageRef = db.child("conversations")
            .child(conversationId)
            .child("messages")
            .child(messageId)
        
        // Get current message to validate permissions
        let snapshot = try await messageRef.getData()
        guard let messageData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Message not found"])
        }

        let senderId = messageData["senderId"] as? String ?? ""

        if deleteForEveryone {
            // Only sender can delete for everyone
            guard senderId == currentUserId else {
                throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the sender can delete for everyone"])
            }

            // Completely remove the message from the database
            try await messageRef.removeValue()

            print("✅ Message deleted for everyone (removed from database)")
                    } else {
            // Mark as deleted for current user only
            var deletedBy = messageData["deletedBy"] as? [String] ?? []
            if !deletedBy.contains(currentUserId) {
                deletedBy.append(currentUserId)
            }
            
            try await messageRef.child("deletedBy").setValue(deletedBy)
            
            print("✅ Message marked as deleted for current user")
        }
        
        // Delete from local storage if needed
        if deleteForEveryone {
            try? LocalStorageService.shared.deleteMessage(messageId: messageId)
        }

        // Update local cache
        await MainActor.run {
            if var conversationMessages = messages[conversationId],
               let index = conversationMessages.firstIndex(where: { $0.id == messageId }) {
                if deleteForEveryone {
                    // Remove the message completely from local cache
                    conversationMessages.remove(at: index)
                    messages[conversationId] = conversationMessages
                    messageCache[conversationId] = conversationMessages
                    lastMessageCount[conversationId] = conversationMessages.count
                } else {
                    // Just mark as deleted for current user
                    var updatedMessage = conversationMessages[index]
                    updatedMessage.deletedBy = (updatedMessage.deletedBy ?? []) + [currentUserId]
                    conversationMessages[index] = updatedMessage
                    messages[conversationId] = conversationMessages
                }
            }
        }
    }
    
    func editMessage(messageId: String, conversationId: String, newText: String) async throws {
        guard let currentUserId = AuthService.shared.currentUser?.id else {
            throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let trimmedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Message cannot be empty"])
        }

        print("✏️ Editing message \(messageId)")
        
        let messageRef = db.child("conversations")
            .child(conversationId)
            .child("messages")
            .child(messageId)
        
        // Get current message
        let snapshot = try await messageRef.getData()
        guard let messageData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Message not found"])
        }

        let senderId = messageData["senderId"] as? String ?? ""
        let originalText = messageData["text"] as? String ?? ""
        let createdAtTimestamp = messageData["createdAt"] as? TimeInterval ?? 0
        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp / 1000)
        
        // Verify user can edit (sender only, within 15 minutes)
        guard senderId == currentUserId else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only edit your own messages"])
        }
        
        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        guard createdAt > fifteenMinutesAgo else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Messages can only be edited within 15 minutes"])
        }

            // Prepare edit history
        var editHistory = messageData["editHistory"] as? [String] ?? []
        editHistory.append(originalText)

        // Update message
        try await messageRef.updateChildValues([
                "text": trimmedText,
            "editedAt": ServerValue.timestamp(),
                "editHistory": editHistory
            ])

        print("✅ Message edited successfully")
        
        // Update local cache
        await MainActor.run {
            if var conversationMessages = messages[conversationId],
               let index = conversationMessages.firstIndex(where: { $0.id == messageId }) {
                var updatedMessage = conversationMessages[index]
                updatedMessage.text = trimmedText
                updatedMessage.editedAt = Date()
                updatedMessage.editHistory = editHistory
                conversationMessages[index] = updatedMessage
                messages[conversationId] = conversationMessages
            }
        }
    }
    
    func addReaction(emoji: String, messageId: String, conversationId: String, userId: String) async throws {
        print("➕ Adding reaction \(emoji) to message \(messageId)")
        
        let messageRef = db.child("conversations")
            .child(conversationId)
            .child("messages")
            .child(messageId)
        
        // Get current reactions
        let snapshot = try await messageRef.child("reactions").getData()
        var reactions = (snapshot.value as? [String: [String]]) ?? [:]
        var userIds = reactions[emoji] ?? []

        // Toggle: if user already reacted with this emoji, remove it
        if let index = userIds.firstIndex(of: userId) {
            userIds.remove(at: index)
            if userIds.isEmpty {
                reactions.removeValue(forKey: emoji)
            } else {
                reactions[emoji] = userIds
            }
            print("➖ Removed reaction \(emoji)")
        } else {
            // Add user to this emoji's reactions
            userIds.append(userId)
            reactions[emoji] = userIds
            print("➕ Added reaction \(emoji)")
        }
        
        // Update in database
        if reactions.isEmpty {
            try await messageRef.child("reactions").removeValue()
        } else {
            try await messageRef.child("reactions").setValue(reactions)
        }

        print("✅ Reaction updated successfully")
        
        // Update local cache
        await MainActor.run {
            if var conversationMessages = messages[conversationId],
               let index = conversationMessages.firstIndex(where: { $0.id == messageId }) {
                var updatedMessage = conversationMessages[index]
                updatedMessage.reactions = reactions.isEmpty ? nil : reactions
                conversationMessages[index] = updatedMessage
                messages[conversationId] = conversationMessages
            }
        }
    }
    
    func forwardMessage(message: Message, to conversationIds: [String], from currentUserId: String) async throws {
        guard !conversationIds.isEmpty else {
            print("⚠️ No conversations selected for forwarding")
            return
        }

        print("📤 Forwarding message to \(conversationIds.count) conversation(s)")

        for conversationId in conversationIds {
            do {
                // Create forwarded message text
                let forwardedText = "Forwarded: \(message.text)"

                // Send message to each conversation
                try await sendMessage(
                    conversationId: conversationId,
                    senderId: currentUserId,
                    text: forwardedText
                )

                print("✅ Message forwarded to conversation: \(conversationId)")
            } catch {
                print("❌ Failed to forward to \(conversationId): \(error.localizedDescription)")
                throw error
            }
        }

        print("✅ Message forwarded successfully to all conversations")
    }

    func clearChatHistory(conversationId: String) async throws {
        guard let currentUserId = AuthService.shared.currentUser?.id else {
            throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        print("🗑️ Clearing chat history for conversation: \(conversationId)")

        // Save clear timestamp to Firebase (persists across devices)
        let clearTimestamp = Date().timeIntervalSince1970 * 1000 // milliseconds
        try await db.child("conversations")
            .child(conversationId)
            .child("participantSettings")
            .child(currentUserId)
            .child("clearedAt")
            .setValue(clearTimestamp)

        // Delete local messages
        try LocalStorageService.shared.deleteMessages(for: conversationId)

        // Clear from memory
        await MainActor.run {
            messages[conversationId] = []
            messageCache[conversationId] = []
            lastMessageCount[conversationId] = 0
        }

        print("✅ Chat history cleared permanently for user: \(currentUserId)")
    }
    
    func deleteConversation(conversationId: String) async throws {
        guard let currentUserId = AuthService.shared.currentUser?.id else {
            throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        print("🗑️ Deleting conversation for user: \(currentUserId)")

        // Stop listening
        stopObservingMessages(conversationId: conversationId)

        // First, clear chat history (hides messages)
        try await clearChatHistory(conversationId: conversationId)

        // Mark conversation as deleted for current user (persists across devices)
        try await db.child("conversations")
            .child(conversationId)
            .child("participantSettings")
            .child(currentUserId)
            .child("deletedAt")
            .setValue(Date().timeIntervalSince1970 * 1000)

        // Update local state - remove from UI
        await MainActor.run {
            conversations.removeAll { $0.id == conversationId }
            messages.removeValue(forKey: conversationId)
            messageCache.removeValue(forKey: conversationId)
        }

        // Clear local storage
        try LocalStorageService.shared.deleteMessages(for: conversationId)
        try LocalStorageService.shared.deleteConversation(id: conversationId)

        print("✅ Conversation deleted for current user (messages and conversation hidden)")
    }
    
    func pinMessage(conversationId: String, messageId: String, userId: String) async throws {
        print("📌 Pinning message \(messageId)")
        
        let conversationRef = db.child("conversations").child(conversationId)
        
        // Get current conversation
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }

        let type = ConversationType(rawValue: convData["type"] as? String ?? "direct") ?? .direct
        let adminIds = convData["adminIds"] as? [String] ?? []
        
        // Check permissions: direct = anyone, groups = admins only
        if type == .group && !adminIds.contains(userId) {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can pin messages in groups"])
        }
        
        // Get current pinned messages
        var pinnedIds = convData["pinnedMessageIds"] as? [String] ?? []
        
        // Check limit (max 3)
        guard pinnedIds.count < 3 else {
            throw NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Maximum 3 pinned messages allowed"])
        }
        
        // Check if already pinned
        guard !pinnedIds.contains(messageId) else {
            return
        }
        
        // Add to pinned
        pinnedIds.append(messageId)
        try await conversationRef.child("pinnedMessageIds").setValue(pinnedIds)
        
        print("✅ Message pinned successfully")
    }
    
    func unpinMessage(conversationId: String, messageId: String, userId: String) async throws {
        print("📌 Unpinning message \(messageId)")
        
        let conversationRef = db.child("conversations").child(conversationId)
        
        // Get current conversation
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }

        let type = ConversationType(rawValue: convData["type"] as? String ?? "direct") ?? .direct
        let adminIds = convData["adminIds"] as? [String] ?? []
        
        // Check permissions
        if type == .group && !adminIds.contains(userId) {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can unpin messages in groups"])
        }
        
        // Remove from pinned
        var pinnedIds = convData["pinnedMessageIds"] as? [String] ?? []
        pinnedIds.removeAll { $0 == messageId }
        
        if pinnedIds.isEmpty {
            try await conversationRef.child("pinnedMessageIds").removeValue()
        } else {
            try await conversationRef.child("pinnedMessageIds").setValue(pinnedIds)
        }
        
        print("✅ Message unpinned successfully")
    }
    
    func searchMessages(conversationId: String, query: String) -> [Message] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Search in cached messages
        guard let allMessages = messages[conversationId] else {
            return []
        }
        
        let results = allMessages.filter { message in
            message.text.lowercased().contains(trimmedQuery)
        }
        
        print("🔍 Found \(results.count) messages matching '\(query)'")
        return results
    }
    
    // MARK: - Pagination
    
    func loadOlderMessages(conversationId: String) async {
        // Prevent multiple simultaneous loads
        guard isLoadingMoreMessages[conversationId] != true else {
            print("⚠️ Already loading more messages")
            return
        }

        guard hasMoreMessages[conversationId] != false else {
            print("📭 No more messages to load")
            return
        }

        await MainActor.run {
            isLoadingMoreMessages[conversationId] = true
        }

        do {
            // Get clearedAt timestamp for current user
            var clearedAt: TimeInterval = 0
            if let currentUserId = AuthService.shared.currentUser?.id {
                do {
                    let clearedSnapshot = try await db.child("conversations")
                        .child(conversationId)
                        .child("participantSettings")
                        .child(currentUserId)
                        .child("clearedAt")
                        .getData()

                    if let timestamp = clearedSnapshot.value as? TimeInterval {
                        clearedAt = timestamp
                    }
                } catch {
                    // No clearedAt timestamp exists
                }
            }

            let currentMessages = await MainActor.run { messages[conversationId] ?? [] }
            guard let oldestMessage = currentMessages.first else {
                await MainActor.run {
                    isLoadingMoreMessages[conversationId] = false
                    hasMoreMessages[conversationId] = false
                }
                return
            }

            // If the oldest message is at or before clearedAt, don't load more
            if clearedAt > 0 {
                let oldestTimestamp = oldestMessage.createdAt.timeIntervalSince1970 * 1000
                if oldestTimestamp <= clearedAt {
                    print("📋 No more messages to load (reached clear point)")
                    await MainActor.run {
                        isLoadingMoreMessages[conversationId] = false
                        hasMoreMessages[conversationId] = false
                    }
                    return
                }
            }

            print("📥 Loading messages before \(oldestMessage.createdAt)")

            // Query for older messages (before oldest)
            let snapshot = try await db.child("conversations")
                .child(conversationId)
                .child("messages")
                .queryOrdered(byChild: "createdAt")
                .queryEnding(atValue: oldestMessage.createdAt.timeIntervalSince1970 * 1000)
                .queryLimited(toLast: UInt(messagesPerPage))
                .getData()

            guard let messagesDict = snapshot.value as? [String: [String: Any]] else {
                await MainActor.run {
                    isLoadingMoreMessages[conversationId] = false
                    hasMoreMessages[conversationId] = false
                }
                return
            }

            let allOlderMessages = messagesDict.compactMap { (msgId, data) -> Message? in
                Message(
                    id: msgId,
                    conversationId: conversationId,
                    senderId: data["senderId"] as? String ?? "",
                    text: data["text"] as? String ?? "",
                    createdAt: Date(timeIntervalSince1970: (data["createdAt"] as? TimeInterval ?? 0) / 1000),
                    status: data["status"] as? String ?? "sent",
                    deliveredTo: data["deliveredTo"] as? [String] ?? [],
                    readBy: data["readBy"] as? [String] ?? []
                )
            }.filter { $0.id != oldestMessage.id } // Exclude the pivot message

            // Filter based on clearedAt timestamp
            let olderMessages: [Message]
            if clearedAt > 0 {
                olderMessages = allOlderMessages.filter { message in
                    let messageTimestamp = message.createdAt.timeIntervalSince1970 * 1000
                    return messageTimestamp > clearedAt
                }
            } else {
                olderMessages = allOlderMessages
            }
            
            print("✅ Loaded \(olderMessages.count) older messages")
            
            await MainActor.run {
                hasMoreMessages[conversationId] = olderMessages.count >= messagesPerPage
                
                if !olderMessages.isEmpty {
                    var updatedMessages = currentMessages
                    updatedMessages.insert(contentsOf: olderMessages, at: 0)
                    updatedMessages.sort { $0.createdAt < $1.createdAt }
                    
                    messages[conversationId] = updatedMessages
                    messageCache[conversationId] = updatedMessages
                }
                
                isLoadingMoreMessages[conversationId] = false
            }
        } catch {
            print("❌ Error loading older messages: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingMoreMessages[conversationId] = false
            }
        }
    }
    
    // MARK: - Media Messages
    
    func sendImageMessage(conversationId: String, senderId: String, image: UIImage, progressHandler: ((Double) -> Void)? = nil) async throws {
        let startTime = Date()
        print("📷 Sending image message to conversation: \(conversationId)")
        
        let messageId = UUID().uuidString
        let createdAt = Date()
        
        // Start performance tracking
        await PerformanceMonitor.shared.startMessageSend(messageId: messageId)
        
        // Create local message immediately (optimistic UI)
        let localMessage = Message(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            text: "",
            createdAt: createdAt,
            status: "sending",
            mediaType: "image"
        )
        
        // Update UI immediately
        await MainActor.run {
            var currentMessages = messages[conversationId] ?? []
            currentMessages.append(localMessage)
            messages[conversationId] = currentMessages
            messageCache[conversationId] = currentMessages
            lastMessageCount[conversationId] = currentMessages.count
        }
        
        do {
            // Upload image to S3 / CloudFront
            print("📤 Uploading image to S3...")
            let (fullURL, thumbnailURL) = try await MediaService.shared.uploadImage(
                image,
                conversationId: conversationId,
                messageId: messageId,
                userId: senderId,
                progressHandler: progressHandler
            )
            
            print("✅ Image uploaded")
            
            // Save to Realtime Database
            let messageData: [String: Any] = [
                "senderId": senderId,
                "text": "",
                "createdAt": ServerValue.timestamp(),
                "status": "sent",
                "deliveredTo": [],
                "readBy": [],
                "mediaType": "image",
                "mediaURL": fullURL,
                "thumbnailURL": thumbnailURL
            ]
            
            try await db.child("conversations")
                .child(conversationId)
                .child("messages")
                .child(messageId)
                .setValue(messageData)
            
            // Update conversation
            try await db.child("conversations")
                .child(conversationId)
                .updateChildValues([
                    "lastMessageText": "📷 Image",
                    "lastMessageAt": ServerValue.timestamp()
                ])
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ Image message sent in \(Int(duration * 1000))ms")
            
            await PerformanceMonitor.shared.completeMessageSend(messageId: messageId, success: true)
            
            // Update local message
            await MainActor.run {
                if var currentMessages = messages[conversationId],
                   let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
                    currentMessages[index] = Message(
                        id: messageId,
                        conversationId: conversationId,
                        senderId: senderId,
                        text: "",
                        createdAt: createdAt,
                        status: "sent",
                        mediaType: "image",
                        mediaURL: fullURL,
                        thumbnailURL: thumbnailURL
                    )
                    messages[conversationId] = currentMessages
                    messageCache[conversationId] = currentMessages
                }
            }
        } catch {
            print("❌ Error sending image: \(error.localizedDescription)")
            await PerformanceMonitor.shared.completeMessageSend(messageId: messageId, success: false)
            
            await MainActor.run {
                if var currentMessages = messages[conversationId],
                   let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
                    currentMessages[index].status = "error"
                    messages[conversationId] = currentMessages
                }
            }
            throw error
        }
    }
    
    func sendVideoMessage(conversationId: String, senderId: String, videoURL: URL, progressHandler: ((Double) -> Void)? = nil) async throws {
        print("🎥 Sending video message")
        
        let messageId = UUID().uuidString
        let createdAt = Date()
        
        // Create local message (optimistic UI)
        let localMessage = Message(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            text: "",
            createdAt: createdAt,
            status: "sending",
            mediaType: "video"
        )
        
        await MainActor.run {
            var currentMessages = messages[conversationId] ?? []
            currentMessages.append(localMessage)
            messages[conversationId] = currentMessages
        }
        
        do {
            // Upload video
            let (videoDownloadURL, thumbnailURL, duration) = try await MediaService.shared.uploadVideo(
                videoURL,
                conversationId: conversationId,
                messageId: messageId,
                userId: senderId,
                progressHandler: progressHandler
            )
            
            // Save to database
            let messageData: [String: Any] = [
                "senderId": senderId,
                "text": "",
                "createdAt": ServerValue.timestamp(),
                "status": "sent",
                "deliveredTo": [],
                "readBy": [],
                "mediaType": "video",
                "mediaURL": videoDownloadURL,
                "thumbnailURL": thumbnailURL,
                "videoDuration": duration
            ]
            
            try await db.child("conversations")
                .child(conversationId)
                .child("messages")
                .child(messageId)
                .setValue(messageData)
            
            try await db.child("conversations")
                .child(conversationId)
                .updateChildValues([
                    "lastMessageText": "🎥 Video",
                    "lastMessageAt": ServerValue.timestamp()
                ])
            
            print("✅ Video message sent")
            
            // Update local
            await MainActor.run {
                if var currentMessages = messages[conversationId],
                   let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
                    currentMessages[index] = Message(
                        id: messageId,
                        conversationId: conversationId,
                        senderId: senderId,
                        text: "",
                        createdAt: createdAt,
                        status: "sent",
                        mediaType: "video",
                        mediaURL: videoDownloadURL,
                        thumbnailURL: thumbnailURL,
                        videoDuration: duration
                    )
                    messages[conversationId] = currentMessages
                }
            }
        } catch {
            print("❌ Error sending video: \(error.localizedDescription)")
            await MainActor.run {
                if var currentMessages = messages[conversationId],
                   let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
                    currentMessages[index].status = "error"
                    messages[conversationId] = currentMessages
                }
            }
            throw error
        }
    }
    
    func sendVoiceMessage(conversationId: String, senderId: String, audioData: Data, duration: TimeInterval, progressHandler: ((Double) -> Void)? = nil) async throws {
        print("🎤 Sending voice message")
        
        let messageId = UUID().uuidString
        let createdAt = Date()
        
        // Create local message (optimistic UI)
        let localMessage = Message(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            text: "",
            createdAt: createdAt,
            status: "sending",
            mediaType: "audio",
            audioDuration: duration
        )
        
        await MainActor.run {
            var currentMessages = messages[conversationId] ?? []
            currentMessages.append(localMessage)
            messages[conversationId] = currentMessages
        }
        
        do {
            // Upload audio
            let audioURL = try await MediaService.shared.uploadAudio(
                audioData,
                conversationId: conversationId,
                messageId: messageId,
                userId: senderId,
                duration: duration,
                progressHandler: progressHandler
            )
            
            // Save to database
            let messageData: [String: Any] = [
                "senderId": senderId,
                "text": "",
                "createdAt": ServerValue.timestamp(),
                "status": "sent",
                "deliveredTo": [],
                "readBy": [],
                "mediaType": "audio",
                "mediaURL": audioURL,
                "audioDuration": duration
            ]
            
            try await db.child("conversations")
                .child(conversationId)
                .child("messages")
                .child(messageId)
                .setValue(messageData)
            
            try await db.child("conversations")
                .child(conversationId)
                .updateChildValues([
                    "lastMessageText": "🎤 Voice message",
                    "lastMessageAt": ServerValue.timestamp()
                ])
            
            print("✅ Voice message sent")
            
            // Update local
            await MainActor.run {
                if var currentMessages = messages[conversationId],
                   let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
                    currentMessages[index] = Message(
                        id: messageId,
                        conversationId: conversationId,
                        senderId: senderId,
                        text: "",
                        createdAt: createdAt,
                        status: "sent",
                        mediaType: "audio",
                        mediaURL: audioURL,
                        audioDuration: duration
                    )
                    messages[conversationId] = currentMessages
                }
            }
        } catch {
            print("❌ Error sending voice message: \(error.localizedDescription)")
            await MainActor.run {
                if var currentMessages = messages[conversationId],
                   let index = currentMessages.firstIndex(where: { $0.id == messageId }) {
                    currentMessages[index].status = "error"
                    messages[conversationId] = currentMessages
                }
            }
            throw error
        }
    }
    
    // MARK: - Group Management
    
    func updateGroupInfo(conversationId: String, groupName: String?, groupDescription: String?, adminId: String) async throws {
        print("✏️ Updating group info")
        
        let conversationRef = db.child("conversations").child(conversationId)

        // Verify admin permissions
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }

        let type = ConversationType(rawValue: convData["type"] as? String ?? "direct") ?? .direct
        guard type == .group else {
            throw NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Not a group conversation"])
        }

        let adminIds = convData["adminIds"] as? [String] ?? []
        guard adminIds.contains(adminId) else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can update group info"])
        }
        
        var updates: [String: Any] = [:]
        if let name = groupName {
            updates["groupName"] = name
        }
        if let description = groupDescription {
            updates["groupDescription"] = description
        }
        
        guard !updates.isEmpty else { return }
        
        try await conversationRef.updateChildValues(updates)
        print("✅ Updated group info")
    }
    
    func updateGroupAvatar(conversationId: String, image: UIImage, adminId: String) async throws {
        print("📷 Updating group avatar")
        
        // Verify permissions first
        let conversationRef = db.child("conversations").child(conversationId)
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        let adminIds = convData["adminIds"] as? [String] ?? []
        guard adminIds.contains(adminId) else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can update group avatar"])
        }
        
        // Upload avatar to S3
        let avatarURL = try await MediaService.shared.uploadGroupAvatar(image, conversationId: conversationId, adminId: adminId)
        
        // Update conversation
        try await conversationRef.child("groupAvatarURL").setValue(avatarURL)
        
        print("✅ Updated group avatar")
    }
    
    func toggleMuteNotifications(conversationId: String, userId: String, isMuted: Bool) async throws {
        print("🔔 Toggling mute: \(isMuted)")
        
        try await db.child("conversations")
            .child(conversationId)
            .child("participantSettings")
            .child(userId)
            .child("isMuted")
            .setValue(isMuted)
        
        print("✅ Mute toggled to \(isMuted)")
    }
    
    func updateGroupPermissions(conversationId: String, onlyAdminsCanMessage: Bool?, onlyAdminsCanAddMembers: Bool?, adminId: String) async throws {
        print("🔐 Updating group permissions")
        
        let conversationRef = db.child("conversations").child(conversationId)
        
        // Verify admin
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        let adminIds = convData["adminIds"] as? [String] ?? []
        guard adminIds.contains(adminId) else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can update permissions"])
        }
        
        var updates: [String: Any] = [:]
        if let onlyAdminsCanMessage = onlyAdminsCanMessage {
            updates["groupPermissions/onlyAdminsCanMessage"] = onlyAdminsCanMessage
        }
        if let onlyAdminsCanAddMembers = onlyAdminsCanAddMembers {
            updates["groupPermissions/onlyAdminsCanAddMembers"] = onlyAdminsCanAddMembers
        }

        guard !updates.isEmpty else { return }

        try await conversationRef.updateChildValues(updates)
        print("✅ Updated group permissions")
    }

    func leaveGroup(conversationId: String, userId: String) async throws {
        print("🚪 Leaving group")

        let conversationRef = db.child("conversations").child(conversationId)

        // Get conversation
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }

        // Check if user is the owner
        let ownerId = convData["ownerId"] as? String
        if ownerId == userId {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Group owner cannot leave. Delete the group instead."])
        }

        let adminIds = convData["adminIds"] as? [String] ?? []
        
        // Remove from participants and admins
        var participantIds = extractParticipantIds(from: convData)
        participantIds.removeAll { $0 == userId }
        
        var newAdminIds = adminIds
        newAdminIds.removeAll { $0 == userId }
        
        var updates: [String: Any] = [
            "participantIds": participantIds,
            "adminIds": newAdminIds,
            "participantMap/\(userId)": NSNull()
        ]
        
        try await conversationRef.updateChildValues(updates)
        
        print("✅ Left group")
    }
    
    func deleteGroup(conversationId: String, userId: String) async throws {
        print("🗑️ Deleting group")

        let conversationRef = db.child("conversations").child(conversationId)

        // Get conversation
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }

        // Verify user is the owner
        let ownerId = convData["ownerId"] as? String
        guard ownerId == userId else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the group owner can delete the group"])
        }
        
        // Delete all messages in this conversation
        let messagesRef = db.child("conversations").child(conversationId).child("messages")
        try await messagesRef.removeValue()
        
        // Delete the conversation itself
        try await conversationRef.removeValue()
        
        // Remove from local array
        await MainActor.run {
            conversations.removeAll { $0.id == conversationId }
            messages.removeValue(forKey: conversationId)
        }
        
        print("✅ Group deleted successfully")
    }
    
    func makeAdmin(conversationId: String, userId: String, currentAdminId: String) async throws {
        print("👑 Making user admin")
        
        let conversationRef = db.child("conversations").child(conversationId)
        
        // Verify current user is admin
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        let adminIds = convData["adminIds"] as? [String] ?? []
        guard adminIds.contains(currentAdminId) else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can make others admin"])
        }
        
        // Add to admins
        var newAdminIds = adminIds
        if !newAdminIds.contains(userId) {
            newAdminIds.append(userId)
        }
        
        try await conversationRef.child("adminIds").setValue(newAdminIds)
        print("✅ User promoted to admin")
    }
    
    func removeAdmin(conversationId: String, userId: String, currentAdminId: String) async throws {
        print("👑 Removing admin status")
        
        let conversationRef = db.child("conversations").child(conversationId)
        
        // Verify current user is admin
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }

        var adminIds = convData["adminIds"] as? [String] ?? []
        guard adminIds.contains(currentAdminId) else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can remove admin status"])
        }
        
        // Prevent removing last admin
        guard adminIds.count > 1 else {
            throw NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot remove the last admin"])
        }
        
        adminIds.removeAll { $0 == userId }
        try await conversationRef.child("adminIds").setValue(adminIds)
        print("✅ Admin status removed")
    }
    
    func removeParticipant(conversationId: String, userId: String, adminId: String) async throws {
        print("🚫 Removing participant")
        
        let conversationRef = db.child("conversations").child(conversationId)
        
        // Verify admin
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        let adminIds = convData["adminIds"] as? [String] ?? []
        guard adminIds.contains(adminId) else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can remove participants"])
        }
        
        // Remove from participants and admins
        var participantIds = extractParticipantIds(from: convData)
        participantIds.removeAll { $0 == userId }
        
        var newAdminIds = adminIds
        newAdminIds.removeAll { $0 == userId }
        
        var updates: [String: Any] = [
            "participantIds": participantIds,
            "adminIds": newAdminIds,
            "participantMap/\(userId)": NSNull()
        ]
        
        try await conversationRef.updateChildValues(updates)
        
        print("✅ Participant removed")
    }
    
    func addParticipants(conversationId: String, userIds: [String], adminId: String) async throws {
        print("➕ Adding participants")
        
        let conversationRef = db.child("conversations").child(conversationId)
        
        // Verify admin
        let snapshot = try await conversationRef.getData()
        guard let convData = snapshot.value as? [String: Any] else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        let adminIds = convData["adminIds"] as? [String] ?? []
        guard adminIds.contains(adminId) else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only admins can add participants"])
        }
        
        // Add to participants
        var participantIds = extractParticipantIds(from: convData)
        var mapUpdates: [String: Any] = [:]
        for userId in userIds {
            if !participantIds.contains(userId) {
                participantIds.append(userId)
            }
            mapUpdates["participantMap/\(userId)"] = true
        }
        
        var updates: [String: Any] = ["participantIds": participantIds]
        for (key, value) in mapUpdates {
            updates[key] = value
        }
        
        try await conversationRef.updateChildValues(updates)
        print("✅ Added \(userIds.count) participant(s)")
    }
    
    // MARK: - Get User
    
    func getUser(userId: String) async throws -> User? {
        // Check cache first for better performance
        if let cachedUser = CacheManager.shared.getCachedUser(id: userId) {
            return cachedUser
        }
        
        // If not in cache, fetch from database
        let snapshot = try await db.child("users").child(userId).getData()
        
        guard let data = snapshot.value as? [String: Any] else {
            return nil
        }
        
        let user = User(
            id: data["id"] as? String ?? userId,
            displayName: data["displayName"] as? String ?? "Unknown",
            email: data["email"] as? String ?? "",
            avatarURL: data["avatarURL"] as? String,
            createdAt: Date(timeIntervalSince1970: (data["createdAt"] as? TimeInterval ?? 0) / 1000),
            isOnline: data["isOnline"] as? Bool ?? false,
            lastSeen: {
                if let timestamp = data["lastSeen"] as? TimeInterval {
                    return Date(timeIntervalSince1970: timestamp / 1000)
                }
                return nil
            }()
        )
        
        // Cache for future use
        CacheManager.shared.cacheUser(user)
        
        return user
    }
    
    deinit {
        if let handle = conversationsListener {
            db.child("conversations").removeObserver(withHandle: handle)
        }
        messageListeners.forEach { (convId, handle) in
            db.child("conversations").child(convId).child("messages").removeObserver(withHandle: handle)
        }
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
    var reactions: [String: [String]]? // Dictionary of emoji -> array of user IDs who reacted
    var mediaType: String? // Type of media: "image", "video", "audio", "file"
    var mediaURL: String? // URL to full-size media served via CloudFront
    var thumbnailURL: String? // URL to thumbnail for images/videos
    var audioDuration: TimeInterval? // Duration in seconds for audio messages
    var videoDuration: TimeInterval? // Duration in seconds for video messages

    init(id: String, conversationId: String, senderId: String, text: String, createdAt: Date, status: String = "sent", deliveredTo: [String] = [], readBy: [String] = [], deletedBy: [String]? = nil, deletedForEveryone: Bool? = nil, editedAt: Date? = nil, editHistory: [String]? = nil, reactions: [String: [String]]? = nil, mediaType: String? = nil, mediaURL: String? = nil, thumbnailURL: String? = nil, audioDuration: TimeInterval? = nil, videoDuration: TimeInterval? = nil) {
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
        self.reactions = reactions
        self.mediaType = mediaType
        self.mediaURL = mediaURL
        self.thumbnailURL = thumbnailURL
        self.audioDuration = audioDuration
        self.videoDuration = videoDuration
    }
    
    // MARK: - Message Deletion Helpers
    
    /// Check if this message is deleted for a specific user
    func isDeleted(for userId: String) -> Bool {
        return deletedBy?.contains(userId) ?? false
    }
    
    /// Check if message is deleted for everyone
    var isDeletedForEveryone: Bool {
        return deletedForEveryone == true
    }
    
    // MARK: - Message Editing Helpers
    
    /// Check if this message was edited
    var wasEdited: Bool {
        return editedAt != nil
    }
    
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

#if DEBUG
extension ChatService {
    /// Clear in-memory state and cancel listeners so each integration test starts fresh.
    func resetForTesting() {
        if let handle = conversationsListener {
            db.child("conversations").removeObserver(withHandle: handle)
        }
        conversationsListener = nil
        
        messageListeners.forEach { (convId, handle) in
            db.child("conversations").child(convId).child("messages").removeObserver(withHandle: handle)
        }
        messageListeners.removeAll()
        
        conversationUpdateTask?.cancel()
        conversationUpdateTask = nil
        
        messageUpdateTasks.values.forEach { $0.cancel() }
        messageUpdateTasks.removeAll()
        
        conversations.removeAll()
        messages.removeAll()
        allUsers.removeAll()
        messageCache.removeAll()
        lastMessageCount.removeAll()
        isLoadingMoreMessages.removeAll()
        hasMoreMessages.removeAll()
    }
}
#endif
