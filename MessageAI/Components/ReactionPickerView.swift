//
//  ReactionPickerView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI

struct ReactionPickerView: View {
    let onReactionSelected: (String) -> Void
    let onDismiss: () -> Void

    // Common emoji reactions
    private let reactions = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(reactions, id: \.self) { emoji in
                Button(action: {
                    onReactionSelected(emoji)
                }) {
                    Text(emoji)
                        .font(.system(size: 32))
                        .scaleEffect(1.0)
                }
                .buttonStyle(ReactionButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// Custom button style for reactions with scale animation
struct ReactionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.3 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 40) {
        Text("Tap an emoji to react")
            .font(.caption)
            .foregroundColor(.secondary)

        ReactionPickerView(
            onReactionSelected: { emoji in
                print("Selected: \(emoji)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )

        Spacer()
    }
    .padding()
}
