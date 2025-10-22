//
//  LocalMessage.swift
//  MessageAI
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
    var deliveredToString: String // Comma-separated user IDs
    var readByString: String // Comma-separated user IDs
    
    init(id: String, conversationId: String, senderId: String, text: String, createdAt: Date, status: String = "sending", isSynced: Bool = false, deliveredTo: [String] = [], readBy: [String] = []) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.createdAt = createdAt
        self.status = status
        self.isSynced = isSynced
        self.deliveredToString = deliveredTo.joined(separator: ",")
        self.readByString = readBy.joined(separator: ",")
    }
    
    // Helper properties for array access
    var deliveredTo: [String] {
        get { deliveredToString.isEmpty ? [] : deliveredToString.components(separatedBy: ",") }
        set { deliveredToString = newValue.joined(separator: ",") }
    }
    
    var readBy: [String] {
        get { readByString.isEmpty ? [] : readByString.components(separatedBy: ",") }
        set { readByString = newValue.joined(separator: ",") }
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
            isSynced: isSynced,
            deliveredTo: message.deliveredTo,
            readBy: message.readBy
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
            status: status,
            deliveredTo: deliveredTo,
            readBy: readBy
        )
    }
}

