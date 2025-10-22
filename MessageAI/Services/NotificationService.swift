//
//  NotificationService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import SwiftUI
import Combine

struct InAppNotification: Identifiable {
    let id = UUID()
    let conversationId: String
    let senderName: String
    let senderInitials: String
    let messageText: String
    let timestamp: Date
    let isGroupChat: Bool
    
    init(conversationId: String, senderName: String, messageText: String, isGroupChat: Bool = false) {
        self.conversationId = conversationId
        self.senderName = senderName
        self.messageText = messageText
        self.timestamp = Date()
        self.isGroupChat = isGroupChat
        
        // Generate initials from sender name
        let names = senderName.components(separatedBy: " ")
        let initials = names.compactMap { $0.first }.prefix(2)
        self.senderInitials = String(initials).uppercased()
    }
}

@MainActor
class NotificationService: ObservableObject {
    @Published var currentNotification: InAppNotification?
    @Published var currentConversationId: String? // Track which conversation is currently open
    
    static let shared = NotificationService()
    
    private var dismissTimer: Timer?
    
    private init() {}
    
    // MARK: - Show Notification
    
    func showNotification(
        conversationId: String,
        senderName: String,
        messageText: String,
        senderId: String,
        currentUserId: String?,
        isGroupChat: Bool = false
    ) {
        // Don't show notification if:
        // 1. Message is from current user
        // 2. Conversation is currently open
        // 3. There's already a notification showing (to avoid rapid-fire)
        
        guard senderId != currentUserId else {
            print("🔕 Not showing notification: message from current user")
            return
        }
        
        guard currentConversationId != conversationId else {
            print("🔕 Not showing notification: conversation is currently open")
            return
        }
        
        // Cancel existing timer if any
        dismissTimer?.invalidate()
        
        // Create and show notification
        let notification = InAppNotification(
            conversationId: conversationId,
            senderName: senderName,
            messageText: messageText,
            isGroupChat: isGroupChat
        )
        
        currentNotification = notification
        print("🔔 Showing notification from: \(senderName)")
        
        // Auto-dismiss after 4 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismissNotification()
            }
        }
    }
    
    // MARK: - Dismiss Notification
    
    func dismissNotification() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        withAnimation {
            currentNotification = nil
        }
        
        print("🔕 Notification dismissed")
    }
    
    // MARK: - Track Current Conversation
    
    func setCurrentConversation(_ conversationId: String?) {
        currentConversationId = conversationId
        print("📍 Current conversation: \(conversationId ?? "none")")
    }
    
    deinit {
        dismissTimer?.invalidate()
    }
}

