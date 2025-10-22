//
//  LocalConversation.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import Foundation
import SwiftData

@Model
final class LocalConversation {
    @Attribute(.unique) var id: String
    var type: String // direct or group
    var participantIds: [String]
    var lastMessageText: String?
    var lastMessageAt: Date?
    var groupName: String?
    var groupAvatarURL: String?
    var createdAt: Date
    var isSynced: Bool
    
    init(id: String, type: String, participantIds: [String], lastMessageText: String? = nil, lastMessageAt: Date? = nil, groupName: String? = nil, groupAvatarURL: String? = nil, createdAt: Date, isSynced: Bool = false) {
        self.id = id
        self.type = type
        self.participantIds = participantIds
        self.lastMessageText = lastMessageText
        self.lastMessageAt = lastMessageAt
        self.groupName = groupName
        self.groupAvatarURL = groupAvatarURL
        self.createdAt = createdAt
        self.isSynced = isSynced
    }
    
    // Convert from Firestore Conversation
    convenience init(from conversation: Conversation, isSynced: Bool = true) {
        self.init(
            id: conversation.id,
            type: conversation.type.rawValue,
            participantIds: conversation.participantIds,
            lastMessageText: conversation.lastMessageText,
            lastMessageAt: conversation.lastMessageAt,
            groupName: conversation.groupName,
            groupAvatarURL: conversation.groupAvatarURL,
            createdAt: conversation.createdAt,
            isSynced: isSynced
        )
    }
    
    // Convert to Firestore Conversation
    func toConversation() -> Conversation {
        Conversation(
            id: id,
            type: ConversationType(rawValue: type) ?? .direct,
            participantIds: participantIds,
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt,
            groupName: groupName,
            groupAvatarURL: groupAvatarURL,
            createdAt: createdAt
        )
    }
}

