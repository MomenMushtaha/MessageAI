//
//  ForwardMessageView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI

struct ForwardMessageView: View {
    let message: Message
    let onForward: ([String]) -> Void // Callback with selected conversation IDs
    let onDismiss: () -> Void

    @EnvironmentObject var chatService: ChatService
    @EnvironmentObject var authService: AuthService

    @State private var selectedConversationIds: Set<String> = []
    @State private var searchText = ""

    private var filteredConversations: [Conversation] {
        let conversations = chatService.conversations

        if searchText.isEmpty {
            return conversations
        }

        return conversations.filter { conversation in
            let name = conversation.type == .group ? (conversation.groupName ?? "Group") : "Chat"
            return name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search conversations", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))

                // Message preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Forward message:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(message.text)
                        .font(.subheadline)
                        .lineLimit(2)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding()

                Divider()

                // Conversation list
                if filteredConversations.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No conversations found")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredConversations) { conversation in
                            ForwardConversationRow(
                                conversation: conversation,
                                isSelected: selectedConversationIds.contains(conversation.id)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(conversation.id)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Forward to...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        onForward(Array(selectedConversationIds))
                        onDismiss()
                    }
                    .disabled(selectedConversationIds.isEmpty)
                }
            }
        }
    }

    private func toggleSelection(_ conversationId: String) {
        if selectedConversationIds.contains(conversationId) {
            selectedConversationIds.remove(conversationId)
        } else {
            selectedConversationIds.insert(conversationId)
        }
    }
}

struct ForwardConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool

    private var displayName: String {
        conversation.type == .group ? (conversation.groupName ?? "Group Chat") : "Chat"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .secondary)
                .font(.title3)

            // Conversation avatar placeholder
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)

                Text(displayName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            // Conversation name
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(conversation.type == .group ? "Group chat" : "Direct message")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ForwardMessageView(
        message: Message(
            id: "1",
            conversationId: "c1",
            senderId: "u1",
            text: "This is a message to forward",
            createdAt: Date()
        ),
        onForward: { conversationIds in
            print("Forward to: \(conversationIds)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .environmentObject(ChatService.shared)
    .environmentObject(AuthService.shared)
}
