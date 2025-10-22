//
//  InAppNotificationBanner.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct InAppNotificationBanner: View {
    let notification: InAppNotification
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(notification.isGroupChat ? Color.purple : Color.blue)
                .frame(width: 44, height: 44)
                .overlay {
                    if notification.isGroupChat {
                        Image(systemName: "person.3.fill")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    } else {
                        Text(notification.senderInitials)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.senderName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(notification.messageText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 8)
            
            // Dismiss Button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .padding(.horizontal)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct InAppNotificationBannerContainer: View {
    @ObservedObject var notificationService = NotificationService.shared
    let onNotificationTapped: (String) -> Void
    
    var body: some View {
        ZStack(alignment: .top) {
            if let notification = notificationService.currentNotification {
                InAppNotificationBanner(
                    notification: notification,
                    onTap: {
                        onNotificationTapped(notification.conversationId)
                        notificationService.dismissNotification()
                    },
                    onDismiss: {
                        notificationService.dismissNotification()
                    }
                )
                .zIndex(999)
            }
        }
    }
}

#Preview {
    InAppNotificationBanner(
        notification: InAppNotification(
            conversationId: "123",
            senderName: "John Doe",
            messageText: "Hey! How are you doing today? Let's catch up soon!",
            isGroupChat: false
        ),
        onTap: {},
        onDismiss: {}
    )
    .padding(.top, 50)
}

