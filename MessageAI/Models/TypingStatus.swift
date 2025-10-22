//
//  TypingStatus.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation

struct TypingStatus: Identifiable, Codable, Hashable {
    let id: String // userId
    var conversationId: String
    var isTyping: Bool
    var lastTypingAt: Date

    init(id: String, conversationId: String, isTyping: Bool = false, lastTypingAt: Date = Date()) {
        self.id = id
        self.conversationId = conversationId
        self.isTyping = isTyping
        self.lastTypingAt = lastTypingAt
    }

    // Helper to check if typing status has expired (older than 3 seconds)
    var isExpired: Bool {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastTypingAt)
        return timeInterval > 3.0
    }

    // Helper to check if actively typing (not expired and isTyping is true)
    var isActivelyTyping: Bool {
        return isTyping && !isExpired
    }
}
