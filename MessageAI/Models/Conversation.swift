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
    var groupDescription: String?
    var groupAvatarURL: String?
    var ownerId: String? // User ID of the group owner (creator)
    var adminIds: [String]? // Array of user IDs who are admins (group creator + appointed admins)

    // Unread tracking - maps userId to unread count
    var unreadCounts: [String: Int]?

    // Message pinning
    var pinnedMessageIds: [String]?

    // Per-user settings - maps userId to their settings
    var participantSettings: [String: ParticipantSettings]?

    // Member join dates - maps userId to join date
    var memberJoinDates: [String: Date]?

    // Group permissions
    var groupPermissions: GroupPermissions?

    init(
        id: String,
        type: ConversationType = .direct,
        participantIds: [String],
        lastMessageText: String? = nil,
        lastMessageAt: Date? = nil,
        groupName: String? = nil,
        groupDescription: String? = nil,
        groupAvatarURL: String? = nil,
        ownerId: String? = nil,
        adminIds: [String]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.participantIds = participantIds
        self.lastMessageText = lastMessageText
        self.lastMessageAt = lastMessageAt
        self.groupName = groupName
        self.groupDescription = groupDescription
        self.groupAvatarURL = groupAvatarURL
        self.ownerId = ownerId
        self.adminIds = adminIds
        self.createdAt = createdAt
    }

    // Helper to check if user is the owner
    func isOwner(_ userId: String) -> Bool {
        return ownerId == userId
    }
    
    // Helper to check if user is admin
    func isAdmin(_ userId: String) -> Bool {
        return adminIds?.contains(userId) ?? false
    }

    // Helper to get unread count for a specific user
    func unreadCount(for userId: String) -> Int {
        return unreadCounts?[userId] ?? 0
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

    // Helper to check if conversation is muted for a user
    func isMuted(for userId: String) -> Bool {
        guard let settings = participantSettings?[userId] else { return false }

        // Check if mute has expired
        if let muteUntil = settings.muteUntil, muteUntil < Date() {
            return false
        }

        return settings.isMuted
    }

    // Helper to get member join date
    func joinDate(for userId: String) -> Date? {
        return memberJoinDates?[userId]
    }

    // Helper to check if user can send messages
    func canSendMessage(_ userId: String) -> Bool {
        // If admin-only messaging is enabled, only admins can send
        if groupPermissions?.onlyAdminsCanMessage == true {
            return isAdmin(userId)
        }
        return true
    }

    // Helper to check if user can add members
    func canAddMembers(_ userId: String) -> Bool {
        // If admin-only adding is enabled, only admins can add
        if groupPermissions?.onlyAdminsCanAddMembers == true {
            return isAdmin(userId)
        }
        return true
    }
}

// MARK: - Participant Settings

struct ParticipantSettings: Codable, Hashable {
    var isMuted: Bool = false
    var muteUntil: Date? = nil // Optional: mute until specific date

    init(isMuted: Bool = false, muteUntil: Date? = nil) {
        self.isMuted = isMuted
        self.muteUntil = muteUntil
    }
}

// MARK: - Group Permissions

struct GroupPermissions: Codable, Hashable {
    var onlyAdminsCanMessage: Bool = false
    var onlyAdminsCanAddMembers: Bool = false

    init(onlyAdminsCanMessage: Bool = false, onlyAdminsCanAddMembers: Bool = false) {
        self.onlyAdminsCanMessage = onlyAdminsCanMessage
        self.onlyAdminsCanAddMembers = onlyAdminsCanAddMembers
    }
}

