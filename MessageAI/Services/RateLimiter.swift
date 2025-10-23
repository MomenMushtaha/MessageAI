//
//  RateLimiter.swift
//  MessageAI
//
//  Created by MessageAI - Phase 7: Rate Limiting
//

import Foundation

/// Rate limiter to prevent spam and abuse
@MainActor
class RateLimiter {
    static let shared = RateLimiter()

    private init() {}

    // Track last action timestamps
    private var lastMessageTime: Date?
    private var lastTypingTime: Date?
    private var messageCount: Int = 0
    private var messageCountResetTime: Date?

    // Rate limit configurations
    private let minimumMessageInterval: TimeInterval = 0.5 // 500ms between messages
    private let minimumTypingInterval: TimeInterval = 2.0 // 2 seconds between typing indicators
    private let maxMessagesPerMinute: Int = 30 // Maximum 30 messages per minute
    private let messageCountWindow: TimeInterval = 60.0 // 1 minute window

    /// Check if user can send a message
    func canSendMessage() -> (allowed: Bool, reason: String?) {
        let now = Date()

        // Check minimum interval between messages
        if let lastTime = lastMessageTime {
            let timeSinceLastMessage = now.timeIntervalSince(lastTime)
            if timeSinceLastMessage < minimumMessageInterval {
                let waitTime = minimumMessageInterval - timeSinceLastMessage
                return (false, "Please wait \(String(format: "%.1f", waitTime)) seconds before sending another message")
            }
        }

        // Check messages per minute limit
        if let resetTime = messageCountResetTime {
            if now.timeIntervalSince(resetTime) > messageCountWindow {
                // Reset counter
                messageCount = 0
                messageCountResetTime = now
            }
        } else {
            messageCountResetTime = now
        }

        if messageCount >= maxMessagesPerMinute {
            return (false, "You're sending messages too quickly. Please wait a moment.")
        }

        return (true, nil)
    }

    /// Record a message send action
    func recordMessageSent() {
        lastMessageTime = Date()
        messageCount += 1
    }

    /// Check if user can send a typing indicator
    func canSendTypingIndicator() -> Bool {
        let now = Date()

        if let lastTime = lastTypingTime {
            let timeSinceLastTyping = now.timeIntervalSince(lastTime)
            if timeSinceLastTyping < minimumTypingInterval {
                return false
            }
        }

        return true
    }

    /// Record a typing indicator send action
    func recordTypingIndicatorSent() {
        lastTypingTime = Date()
    }

    /// Reset rate limits (useful for testing or after user logout)
    func reset() {
        lastMessageTime = nil
        lastTypingTime = nil
        messageCount = 0
        messageCountResetTime = nil
    }
}

/// Rate limiter errors
enum RateLimitError: LocalizedError {
    case messageTooFast
    case tooManyMessages
    case typingTooFast

    var errorDescription: String? {
        switch self {
        case .messageTooFast:
            return "Please wait before sending another message"
        case .tooManyMessages:
            return "You're sending too many messages. Please slow down."
        case .typingTooFast:
            return "Typing indicator rate limit exceeded"
        }
    }
}
