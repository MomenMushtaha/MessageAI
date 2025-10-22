//
//  User.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var email: String
    var avatarURL: String?
    var createdAt: Date
    
    init(id: String, displayName: String, email: String, avatarURL: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }
    
    // Helper to get initials for avatar
    var initials: String {
        let names = displayName.components(separatedBy: " ")
        let initials = names.compactMap { $0.first }.prefix(2)
        return String(initials).uppercased()
    }
}

