//
//  LocalStorageService.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import Foundation
import SwiftData

@MainActor
class LocalStorageService {
    private let modelContext: ModelContext
    
    static let shared = LocalStorageService()
    
    private init() {
        // This will be injected from the environment
        // For now, create a temporary context
        let container = try! ModelContainer(for: LocalMessage.self, LocalConversation.self)
        self.modelContext = ModelContext(container)
    }
    
    // Inject model context from app
    func setModelContext(_ context: ModelContext) {
        // Update context if needed
    }
    
    // MARK: - Messages
    
    func saveMessage(_ message: Message, status: String = "sent", isSynced: Bool = true) throws {
        let localMessage = LocalMessage(from: message, isSynced: isSynced)
        localMessage.status = status
        modelContext.insert(localMessage)
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
            // Update existing
            existing.lastMessageText = conversation.lastMessageText
            existing.lastMessageAt = conversation.lastMessageAt
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
}

