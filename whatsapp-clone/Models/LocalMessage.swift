//
//  LocalMessage.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import Foundation
import SwiftData

@Model
final class LocalMessage {
    @Attribute(.unique) var id: String
    var conversationId: String
    var senderId: String
    var text: String
    var createdAt: Date
    var status: String // sending, sent, delivered, read, error
    var isSynced: Bool
    
    init(id: String, conversationId: String, senderId: String, text: String, createdAt: Date, status: String = "sending", isSynced: Bool = false) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.createdAt = createdAt
        self.status = status
        self.isSynced = isSynced
    }
    
    // Convert from Firestore Message
    convenience init(from message: Message, isSynced: Bool = true) {
        self.init(
            id: message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            text: message.text,
            createdAt: message.createdAt,
            status: message.status,
            isSynced: isSynced
        )
    }
    
    // Convert to Firestore Message
    func toMessage() -> Message {
        Message(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            text: text,
            createdAt: createdAt,
            status: status
        )
    }
}

