//
//  TypingIndicatorView.swift
//  MessageAI
//
//  Displays "User is typing..." indicator
//

import SwiftUI
import Combine

struct TypingIndicatorView: View {
    let typingUsers: [TypingStatus]
    let participantUsers: [String: User]
    
    @State private var animationPhase: Int = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    private var activeTypers: [TypingStatus] {
        // Only show users who are actively typing (not expired)
        return typingUsers.filter { $0.isActivelyTyping }
    }
    
    private var displayText: String {
        let count = activeTypers.count
        
        guard count > 0 else { return "" }
        
        if count == 1 {
            let userId = activeTypers[0].id
            let name = participantUsers[userId]?.displayName.split(separator: " ").first ?? "Someone"
            return "\(name) is typing"
        } else if count == 2 {
            let userId1 = activeTypers[0].id
            let userId2 = activeTypers[1].id
            let name1 = participantUsers[userId1]?.displayName.split(separator: " ").first ?? "Someone"
            let name2 = participantUsers[userId2]?.displayName.split(separator: " ").first ?? "Someone"
            return "\(name1) and \(name2) are typing"
        } else {
            return "\(count) people are typing"
        }
    }
    
    var body: some View {
        if !activeTypers.isEmpty {
            HStack(spacing: 6) {
                // Animated typing dots
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .opacity(animationPhase == index ? 1.0 : 0.4)
                            .animation(.easeInOut(duration: 0.5).repeatForever(), value: animationPhase)
                    }
                }
                
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(.systemGray6).opacity(0.5))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onReceive(timer) { _ in
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// Alternative: Bubble-style typing indicator (WhatsApp style)
struct BubbleTypingIndicatorView: View {
    @State private var animationPhase: Int = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            
            // Typing bubble
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            
            Spacer(minLength: 50)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

#Preview("Text Indicator") {
    VStack {
        Spacer()
        
        TypingIndicatorView(
            typingUsers: [
                TypingStatus(id: "1", conversationId: "conv1", isTyping: true),
                TypingStatus(id: "2", conversationId: "conv1", isTyping: true)
            ],
            participantUsers: [
                "1": User(id: "1", displayName: "John Doe", email: "john@test.com", createdAt: Date()),
                "2": User(id: "2", displayName: "Jane Smith", email: "jane@test.com", createdAt: Date())
            ]
        )
        
        Spacer()
    }
}

#Preview("Bubble Indicator") {
    VStack {
        Spacer()
        BubbleTypingIndicatorView()
        Spacer()
    }
}

#Preview("Multiple States") {
    VStack(spacing: 20) {
        Text("Single User")
            .font(.caption)
        TypingIndicatorView(
            typingUsers: [
                TypingStatus(id: "1", conversationId: "conv1", isTyping: true)
            ],
            participantUsers: [
                "1": User(id: "1", displayName: "John Doe", email: "john@test.com", createdAt: Date())
            ]
        )
        
        Divider()
        
        Text("Two Users")
            .font(.caption)
        TypingIndicatorView(
            typingUsers: [
                TypingStatus(id: "1", conversationId: "conv1", isTyping: true),
                TypingStatus(id: "2", conversationId: "conv1", isTyping: true)
            ],
            participantUsers: [
                "1": User(id: "1", displayName: "John Doe", email: "john@test.com", createdAt: Date()),
                "2": User(id: "2", displayName: "Jane Smith", email: "jane@test.com", createdAt: Date())
            ]
        )
        
        Divider()
        
        Text("Three+ Users")
            .font(.caption)
        TypingIndicatorView(
            typingUsers: [
                TypingStatus(id: "1", conversationId: "conv1", isTyping: true),
                TypingStatus(id: "2", conversationId: "conv1", isTyping: true),
                TypingStatus(id: "3", conversationId: "conv1", isTyping: true)
            ],
            participantUsers: [
                "1": User(id: "1", displayName: "John", email: "john@test.com", createdAt: Date()),
                "2": User(id: "2", displayName: "Jane", email: "jane@test.com", createdAt: Date()),
                "3": User(id: "3", displayName: "Bob", email: "bob@test.com", createdAt: Date())
            ]
        )
        
        Spacer()
    }
    .padding()
}

