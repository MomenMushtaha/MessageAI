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
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            
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
                
                Task { @MainActor in
                    self.conversations = documents.compactMap { doc -> Conversation? in
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
                    
                    print("✅ Loaded \(self.conversations.count) conversations")
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
        
        // Then, observe Firestore for updates
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
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
                            status: data["status"] as? String ?? "sent"
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
                    
                    self.messages[conversationId] = mergedMessages
                    print("✅ Merged \(mergedMessages.count) messages (Firestore + local)")
                }
            }
        
        messageListeners[conversationId] = listener
    }
    
    func stopObservingMessages(conversationId: String) {
        messageListeners[conversationId]?.remove()
        messageListeners[conversationId] = nil
        print("🛑 Stopped observing messages for: \(conversationId)")
    }
    
    // MARK: - Send Message
    
    func sendMessage(conversationId: String, senderId: String, text: String) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        print("📤 Sending message to conversation: \(conversationId)")
        
        // Generate message ID upfront
        let messageId = UUID().uuidString
        
        // Create local message immediately (optimistic UI)
        let localMessage = Message(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            text: text,
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
            "text": text,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "sent"
        ]
        
        let conversationRef = db.collection("conversations").document(conversationId)
        let messageRef = conversationRef.collection("messages").document(messageId)
        
        // Use batch write to update conversation and add message atomically
        let batch = db.batch()
        
        // Add message
        batch.setData(messageData, forDocument: messageRef)
        
        // Update conversation's last message
        let conversationUpdate: [String: Any] = [
            "lastMessageText": text,
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
                    text: text,
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
        let doc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = doc.data() else {
            return nil
        }
        
        return User(
            id: data["id"] as? String ?? userId,
            displayName: data["displayName"] as? String ?? "Unknown",
            email: data["email"] as? String ?? "",
            avatarURL: data["avatarURL"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
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

// MARK: - Message Model

struct Message: Identifiable, Codable, Hashable {
    let id: String
    let conversationId: String
    let senderId: String
    let text: String
    let createdAt: Date
    var status: String // sending, sent, delivered, read
    
    init(id: String, conversationId: String, senderId: String, text: String, createdAt: Date, status: String = "sent") {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.createdAt = createdAt
        self.status = status
    }
}

