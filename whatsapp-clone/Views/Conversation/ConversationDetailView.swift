//
//  ConversationDetailView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var messageText = ""
    @State private var messages: [MockMessage] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyMessagesView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleRow(message: message, isFromCurrentUser: message.isFromCurrentUser)
                        }
                    }
                }
                .padding()
            }
            
            // Message Input
            messageInputView
        }
        .navigationTitle(conversation.type == .group ? (conversation.groupName ?? "Group") : "Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.type == .group ? (conversation.groupName ?? "Group") : "Contact")
                        .font(.headline)
                    
                    if conversation.type == .direct {
                        Text("Online")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(conversation.participantIds.count) participants")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            loadMockMessages()
        }
    }
    
    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No messages yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Start a conversation!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private var messageInputView: some View {
        HStack(spacing: 12) {
            // Text Field
            HStack {
                TextField("Message", text: $messageText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .background(Color(.systemGray6))
            .cornerRadius(20)
            
            // Send Button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(messageText.isEmpty ? .gray : .blue)
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = MockMessage(
            id: UUID().uuidString,
            text: messageText,
            isFromCurrentUser: true,
            timestamp: Date()
        )
        
        messages.append(newMessage)
        messageText = ""
        
        // Simulate response after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let responseMessage = MockMessage(
                id: UUID().uuidString,
                text: "Thanks for your message!",
                isFromCurrentUser: false,
                timestamp: Date()
            )
            messages.append(responseMessage)
        }
    }
    
    private func loadMockMessages() {
        // Load some mock messages for demonstration
        messages = [
            MockMessage(
                id: "1",
                text: "Hey there!",
                isFromCurrentUser: false,
                timestamp: Date().addingTimeInterval(-3600)
            ),
            MockMessage(
                id: "2",
                text: "Hi! How are you?",
                isFromCurrentUser: true,
                timestamp: Date().addingTimeInterval(-3500)
            ),
            MockMessage(
                id: "3",
                text: "I'm doing great, thanks for asking!",
                isFromCurrentUser: false,
                timestamp: Date().addingTimeInterval(-3400)
            )
        ]
    }
}

struct MessageBubbleRow: View {
    let message: MockMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
}

// Mock message model for Step 1
struct MockMessage: Identifiable {
    let id: String
    let text: String
    let isFromCurrentUser: Bool
    let timestamp: Date
}

#Preview {
    NavigationStack {
        ConversationDetailView(
            conversation: Conversation(
                id: "1",
                type: .direct,
                participantIds: ["user1", "user2"]
            )
        )
    }
}

