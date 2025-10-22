//
//  MessageBubbleView.swift
//  whatsapp-clone
//
//  Created by Momen Mush on 2025-10-21.
//

import SwiftUI
import SwiftData

struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isFromUser ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundColor(message.isFromUser ? .white : .primary)
                
                HStack(spacing: 4) {
                    if message.isAIGenerating {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("AI is typing...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if message.isFromUser {
                        Spacer()
                    }
                }
            }
            
            if !message.isFromUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}

#Preview {
    let sampleMessage1 = Message(content: "Hello, how are you?", isFromUser: true)
    let sampleMessage2 = Message(content: "I'm doing great! How can I help you today?", isFromUser: false)
    
    return VStack {
        MessageBubbleView(message: sampleMessage1)
        MessageBubbleView(message: sampleMessage2)
    }
    .padding()
    .modelContainer(for: Message.self, inMemory: true)
}