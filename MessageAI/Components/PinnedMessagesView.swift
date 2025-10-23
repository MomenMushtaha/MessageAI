//
//  PinnedMessagesView.swift
//  MessageAI
//
//  Created by MessageAI - Phase 6: Message Pinning
//

import SwiftUI

struct PinnedMessagesView: View {
    let pinnedMessages: [Message]
    let onTapMessage: (Message) -> Void
    let onUnpin: (Message) -> Void
    let canUnpin: Bool

    var body: some View {
        if !pinnedMessages.isEmpty {
            VStack(spacing: 0) {
                ForEach(pinnedMessages) { message in
                    PinnedMessageRow(
                        message: message,
                        onTap: {
                            onTapMessage(message)
                        },
                        onUnpin: canUnpin ? {
                            onUnpin(message)
                        } : nil
                    )

                    if message.id != pinnedMessages.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }

                Divider()
            }
            .background(Color(.systemBackground))
        }
    }
}

struct PinnedMessageRow: View {
    let message: Message
    let onTap: () -> Void
    let onUnpin: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Pin Icon
                Image(systemName: "pin.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
                    .frame(width: 24, height: 24)

                // Message Preview
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pinned Message")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)

                    Text(messagePreviewText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                Spacer()

                // Unpin Button (if allowed)
                if let onUnpin = onUnpin {
                    Button(action: onUnpin) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Navigate Icon
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var messagePreviewText: String {
        if message.mediaType == "image" {
            return "📷 Photo"
        } else if message.mediaType == "video" {
            return "🎥 Video"
        } else if message.mediaType == "audio" {
            return "🎤 Voice message"
        } else {
            return message.text
        }
    }
}
