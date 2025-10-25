//
//  LocalStorageService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import SwiftData

@MainActor
class LocalStorageService {
    private static var _modelContext: ModelContext?
    
    private var modelContext: ModelContext {
        guard let context = Self._modelContext else {
            fatalError("ModelContext must be set before using LocalStorageService. Call LocalStorageService.initialize(with:) in your app initialization.")
        }
        return context
    }
    
    static let shared = LocalStorageService()
    
    private init() {}
    
    // Initialize with model context from app
    static func initialize(with context: ModelContext) {
        _modelContext = context
        print("✅ LocalStorageService initialized with ModelContext")
    }
    
    // MARK: - Messages
    
    func saveMessage(_ message: Message, status: String = "sent", isSynced: Bool = true) throws {
        let predicate = #Predicate<LocalMessage> { $0.id == message.id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let existing = try modelContext.fetch(descriptor).first {
            existing.text = message.text
            existing.createdAt = message.createdAt
            existing.status = status
            existing.isSynced = isSynced
            existing.deliveredTo = message.deliveredTo
            existing.readBy = message.readBy
            existing.mediaType = message.mediaType
            existing.mediaURL = message.mediaURL
            existing.thumbnailURL = message.thumbnailURL
            existing.audioDuration = message.audioDuration
            existing.videoDuration = message.videoDuration
        } else {
            let localMessage = LocalMessage(from: message, isSynced: isSynced)
            localMessage.status = status
            modelContext.insert(localMessage)
        }
        try modelContext.save()
        print("💾 Saved message locally: \(message.id)")
    }
    
    func updateMessageStatus(_ messageId: String, status: String, isSynced: Bool = true) throws {
        let predicate = #Predicate<LocalMessage> { $0.id == messageId }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        if let localMessage = try modelContext.fetch(descriptor).first {
            localMessage.status = status
            localMessage.isSynced = isSynced
            try modelContext.save()
            print("💾 Updated message status: \(messageId) -> \(status)")
        }
    }
    
    func getMessages(for conversationId: String) throws -> [Message] {
        let predicate = #Predicate<LocalMessage> { $0.conversationId == conversationId }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.createdAt)]
        
        let localMessages = try modelContext.fetch(descriptor)
        return localMessages.map { $0.toMessage() }
    }
    
    func getPendingMessages() throws -> [LocalMessage] {
        let predicate = #Predicate<LocalMessage> { !$0.isSynced || $0.status == "sending" }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Conversations
    
    func saveConversation(_ conversation: Conversation, isSynced: Bool = true) throws {
        // Check if conversation already exists
        let predicate = #Predicate<LocalConversation> { $0.id == conversation.id }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        if let existing = try modelContext.fetch(descriptor).first {
            // Update all fields
            existing.type = conversation.type.rawValue
            existing.participantIds = conversation.participantIds
            existing.lastMessageText = conversation.lastMessageText
            existing.lastMessageAt = conversation.lastMessageAt
            existing.groupName = conversation.groupName
            existing.groupDescription = conversation.groupDescription
            existing.groupAvatarURL = conversation.groupAvatarURL
            existing.ownerId = conversation.ownerId
            existing.adminIds = conversation.adminIds
            existing.isSynced = isSynced
        } else {
            // Insert new
            let localConversation = LocalConversation(from: conversation, isSynced: isSynced)
            modelContext.insert(localConversation)
        }
        
        try modelContext.save()
        print("💾 Saved conversation locally: \(conversation.id)")
    }
    
    func getConversations(for userId: String) throws -> [Conversation] {
        let predicate = #Predicate<LocalConversation> { $0.participantIds.contains(userId) }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.lastMessageAt, order: .reverse)]
        
        let localConversations = try modelContext.fetch(descriptor)
        return localConversations.map { $0.toConversation() }
    }
    
    // MARK: - Sync Status
    
    func markAsSynced(_ messageId: String) throws {
        let predicate = #Predicate<LocalMessage> { $0.id == messageId }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        if let localMessage = try modelContext.fetch(descriptor).first {
            localMessage.isSynced = true
            try modelContext.save()
        }
    }
    
    // MARK: - Cleanup
    
    func deleteOldMessages(olderThan days: Int = 30) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = #Predicate<LocalMessage> { $0.createdAt < cutoffDate }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        let oldMessages = try modelContext.fetch(descriptor)
        for message in oldMessages {
            modelContext.delete(message)
        }
        try modelContext.save()
        print("🗑️ Deleted \(oldMessages.count) old messages")
    }
    
    /// Delete a specific message by ID
    func deleteMessage(messageId: String) throws {
        let predicate = #Predicate<LocalMessage> { $0.id == messageId }
        let descriptor = FetchDescriptor(predicate: predicate)

        if let message = try modelContext.fetch(descriptor).first {
            modelContext.delete(message)
            try modelContext.save()
            print("🗑️ Deleted local message: \(messageId)")
        }
    }

    /// Delete all messages for a specific conversation
    func deleteMessages(for conversationId: String) throws {
        let predicate = #Predicate<LocalMessage> { $0.conversationId == conversationId }
        let descriptor = FetchDescriptor(predicate: predicate)

        let messages = try modelContext.fetch(descriptor)
        for message in messages {
            modelContext.delete(message)
        }
        try modelContext.save()
        print("🗑️ Deleted \(messages.count) local messages for conversation: \(conversationId)")
    }
    
    /// Delete a specific conversation
    func deleteConversation(id conversationId: String) throws {
        let predicate = #Predicate<LocalConversation> { $0.id == conversationId }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        if let conversation = try modelContext.fetch(descriptor).first {
            modelContext.delete(conversation)
            try modelContext.save()
            print("🗑️ Deleted local conversation: \(conversationId)")
        }
    }
}
