//
//  Conversation.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation

enum ConversationType: String, Codable {
    case direct
    case group
}

struct Conversation: Identifiable, Codable, Hashable {
    let id: String
    var type: ConversationType
    var participantIds: [String]
    var lastMessageText: String?
    var lastMessageAt: Date?
    var createdAt: Date
    
    // Group-specific properties
    var groupName: String?
    var groupAvatarURL: String?
    
    init(
        id: String,
        type: ConversationType = .direct,
        participantIds: [String],
        lastMessageText: String? = nil,
        lastMessageAt: Date? = nil,
        groupName: String? = nil,
        groupAvatarURL: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.participantIds = participantIds
        self.lastMessageText = lastMessageText
        self.lastMessageAt = lastMessageAt
        self.groupName = groupName
        self.groupAvatarURL = groupAvatarURL
        self.createdAt = createdAt
    }
    
    // Helper to get conversation title (for display)
    func title(currentUserId: String, users: [User]) -> String {
        if type == .group {
            return groupName ?? "Group Chat"
        } else {
            // For direct chats, show the other person's name
            let otherUserId = participantIds.first { $0 != currentUserId }
            let otherUser = users.first { $0.id == otherUserId }
            return otherUser?.displayName ?? "Unknown User"
        }
    }
}



