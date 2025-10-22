//
//  Message.swift
//  whatsapp-clone
//
//  Created by Momen Mush on 2025-10-21.
//

import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var content: String
    var timestamp: Date
    var isFromUser: Bool
    var isAIGenerating: Bool
    
    init(content: String, isFromUser: Bool) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFromUser = isFromUser
        self.isAIGenerating = false
    }
}