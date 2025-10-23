//
//  User.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var email: String
    var avatarURL: String?
    var bio: String?
    var createdAt: Date
    var isOnline: Bool
    var lastSeen: Date?

    init(id: String, displayName: String, email: String, avatarURL: String? = nil, bio: String? = nil, createdAt: Date = Date(), isOnline: Bool = false, lastSeen: Date? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
        self.bio = bio
        self.createdAt = createdAt
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
    
    // Helper to get initials for avatar
    var initials: String {
        let names = displayName.components(separatedBy: " ")
        let initials = names.compactMap { $0.first }.prefix(2)
        return String(initials).uppercased()
    }
    
    // Helper to get last seen text
    var lastSeenText: String {
        if isOnline {
            return "Online"
        }
        
        guard let lastSeen = lastSeen else {
            return "Last seen recently"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastSeen)
        
        if timeInterval < 60 {
            return "Last seen just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "Last seen \(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "Last seen \(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "Last seen \(days) day\(days == 1 ? "" : "s") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "Last seen \(formatter.string(from: lastSeen))"
        }
    }
}

