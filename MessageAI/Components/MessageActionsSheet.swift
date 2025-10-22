//
//  MessageActionsSheet.swift
//  MessageAI
//
//  Message actions sheet for long-press menu
//

import SwiftUI

struct MessageActionsSheet: View {
    let message: Message
    let currentUserId: String
    let onDelete: (Bool) -> Void // Parameter: deleteForEveryone
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Message Options")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            .padding()

            Divider()

            // Message Preview (truncated)
            HStack {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.vertical, 8)

            Divider()

            // Delete for me
            Button(action: {
                onDelete(false)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red)
                        .frame(width: 24)

                    Text("Delete for Me")
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
            }

            Divider()

            // Delete for everyone (only if sender)
            if message.senderId == currentUserId {
                Button(action: {
                    onDelete(true)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.body)
                            .foregroundColor(.red)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete for Everyone")
                                .foregroundColor(.primary)
                            Text("Remove this message for all participants")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }

                Divider()
            }

            // Cancel
            Button(action: onDismiss) {
                Text("Cancel")
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 20)
        .padding()
        .presentationDetents([.height(message.senderId == currentUserId ? 320 : 240)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        MessageActionsSheet(
            message: Message(
                id: "1",
                conversationId: "c1",
                senderId: "u1",
                text: "This is a test message that could be quite long and span multiple lines",
                createdAt: Date(),
                status: "sent"
            ),
            currentUserId: "u1",
            onDelete: { deleteForEveryone in
                print("Delete tapped: deleteForEveryone=\(deleteForEveryone)")
            },
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
    .background(Color.black.opacity(0.3))
}
