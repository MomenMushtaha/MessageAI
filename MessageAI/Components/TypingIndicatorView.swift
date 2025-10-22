//
//  TypingIndicatorView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI

struct TypingIndicatorView: View {
    let typingUsers: [TypingStatus]
    let participantUsers: [String: User]

    @State private var animationPhase = 0

    var body: some View {
        if !typingUsers.isEmpty {
            HStack(alignment: .center, spacing: 8) {
                // Animated typing dots
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 6, height: 6)
                            .opacity(animationPhase == index ? 1.0 : 0.3)
                    }
                }
                .padding(.leading, 12)
                .onAppear {
                    startAnimation()
                }

                // Typing text
                Text(typingText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
    }

    private var typingText: String {
        let count = typingUsers.count

        if count == 1 {
            // Single user typing
            if let user = participantUsers[typingUsers[0].id] {
                return "\(user.displayName) is typing..."
            }
            return "Someone is typing..."
        } else if count == 2 {
            // Two users typing
            let names = typingUsers.compactMap { participantUsers[$0.id]?.displayName }
            if names.count == 2 {
                return "\(names[0]) and \(names[1]) are typing..."
            }
            return "2 people are typing..."
        } else {
            // Multiple users typing
            return "\(count) people are typing..."
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview with one user
        TypingIndicatorView(
            typingUsers: [
                TypingStatus(id: "user1", conversationId: "conv1", isTyping: true)
            ],
            participantUsers: [
                "user1": User(id: "user1", displayName: "Alice", email: "alice@example.com")
            ]
        )

        // Preview with two users
        TypingIndicatorView(
            typingUsers: [
                TypingStatus(id: "user1", conversationId: "conv1", isTyping: true),
                TypingStatus(id: "user2", conversationId: "conv1", isTyping: true)
            ],
            participantUsers: [
                "user1": User(id: "user1", displayName: "Alice", email: "alice@example.com"),
                "user2": User(id: "user2", displayName: "Bob", email: "bob@example.com")
            ]
        )

        // Preview with multiple users
        TypingIndicatorView(
            typingUsers: [
                TypingStatus(id: "user1", conversationId: "conv1", isTyping: true),
                TypingStatus(id: "user2", conversationId: "conv1", isTyping: true),
                TypingStatus(id: "user3", conversationId: "conv1", isTyping: true)
            ],
            participantUsers: [:]
        )

        Spacer()
    }
}
