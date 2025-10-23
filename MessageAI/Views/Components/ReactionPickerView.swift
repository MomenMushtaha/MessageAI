//
//  ReactionPickerView.swift
//  MessageAI
//
//  Emoji reaction picker for messages
//

import SwiftUI

struct ReactionPickerView: View {
    let onReactionSelected: (String) -> Void
    let onDismiss: () -> Void
    
    // Common emoji reactions (WhatsApp style)
    // Using Unicode literals to avoid text input system issues
    private let reactions = ["👍", "❤️", "😂", "😮", "😢", "🙏", "🔥", "🎉"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar for drag to dismiss (optional)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            // Reaction buttons
            HStack(spacing: 8) {
                ForEach(Array(reactions.enumerated()), id: \.offset) { index, emoji in
                    Button(action: {
                        selectReaction(emoji)
                    }) {
                        // Use Text with explicit font to avoid input system
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to avoid conflicts
                    .contentShape(Circle()) // Ensure tap area is defined
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: -2)
        )
        .padding(.horizontal, 8)
    }
    
    private func selectReaction(_ emoji: String) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        onReactionSelected(emoji)
        onDismiss()
    }
}

// Custom button style for scale effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Alternative: Full-screen emoji picker (more comprehensive)
struct FullReactionPickerView: View {
    let onReactionSelected: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedCategory: EmojiCategory = .frequent
    
    enum EmojiCategory: String, CaseIterable {
        case frequent = "🕐"
        case smileys = "😀"
        case people = "👋"
        case nature = "🌿"
        case food = "🍎"
        case activity = "⚽️"
        case travel = "✈️"
        case objects = "💡"
        case symbols = "❤️"
        case flags = "🏁"
        
        var emojis: [String] {
            switch self {
            case .frequent:
                return ["👍", "❤️", "😂", "😮", "😢", "🙏", "🔥", "🎉", "👏", "💯", "✅", "🎊"]
            case .smileys:
                return ["😀", "😃", "😄", "😁", "😅", "😂", "🤣", "😊", "😇", "🙂", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸", "🤩", "🥳"]
            case .people:
                return ["👋", "🤚", "🖐", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏"]
            case .nature:
                return ["🌿", "🍀", "🍁", "🍂", "🍃", "🌾", "🌱", "🌲", "🌳", "🌴", "🌵", "🌷", "🌸", "🌹", "🥀", "🌺", "🌻", "🌼", "🌽", "🌾", "💐", "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨"]
            case .food:
                return ["🍎", "🍏", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶", "🌽", "🥕", "🧄", "🧅", "🥔", "🍠", "🥐"]
            case .activity:
                return ["⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🥅", "⛳️", "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛷", "⛸", "🥌"]
            case .travel:
                return ["✈️", "🚀", "🛸", "🚁", "🛶", "⛵️", "🚤", "🛳", "⛴", "🚢", "🚂", "🚃", "🚄", "🚅", "🚆", "🚇", "🚈", "🚉", "🚊", "🚝", "🚞", "🚋", "🚌", "🚍", "🚎", "🚐", "🚑", "🚒", "🚓", "🚔"]
            case .objects:
                return ["💡", "🔦", "🏮", "🪔", "📱", "💻", "⌚️", "📷", "📹", "🎥", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙", "🎚", "🎛", "🧭", "⏱", "⏲", "⏰", "🕰", "⌛️", "⏳", "📡", "🔋", "🔌", "💡"]
            case .symbols:
                return ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❤️‍🔥", "❤️‍🩹", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉", "☸️", "✡️", "🔯", "🕎", "☯️", "☦️"]
            case .flags:
                return ["🏁", "🚩", "🎌", "🏴", "🏳️", "🏳️‍🌈", "🏳️‍⚧️", "🏴‍☠️", "🇺🇳", "🇦🇫", "🇦🇽", "🇦🇱", "🇩🇿", "🇦🇸", "🇦🇩", "🇦🇴", "🇦🇮", "🇦🇶", "🇦🇬", "🇦🇷", "🇦🇲", "🇦🇼", "🇦🇺", "🇦🇹", "🇦🇿", "🇧🇸", "🇧🇭", "🇧🇩", "🇧🇧"]
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(EmojiCategory.allCases, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category.rawValue)
                                    .font(.system(size: 28))
                                    .opacity(selectedCategory == category ? 1.0 : 0.5)
                                    .scaleEffect(selectedCategory == category ? 1.2 : 1.0)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 50)
                .background(Color(.systemGray6))
                
                // Emoji grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(selectedCategory.emojis, id: \.self) { emoji in
                            Button(action: {
                                selectReaction(emoji)
                            }) {
                                Text(emoji)
                                    .font(.system(size: 32))
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("React")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func selectReaction(_ emoji: String) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        onReactionSelected(emoji)
        onDismiss()
    }
}

#Preview("Simple Picker") {
    VStack {
        Spacer()
        ReactionPickerView(
            onReactionSelected: { emoji in
                print("Selected: \(emoji)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
    }
    .background(Color.black.opacity(0.3))
}

#Preview("Full Picker") {
    FullReactionPickerView(
        onReactionSelected: { emoji in
            print("Selected: \(emoji)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}

