//
//  AIBottomBar.swift
//  MessageAI
//
//  AI actions toolbar (Phase B)
//

import SwiftUI

struct AIBottomBar: View {
    let onSummarize: () -> Void
    let onActions: () -> Void
    let onDecisions: () -> Void
    let onSearch: () -> Void
    let onTranslate: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                AIActionButton(
                    icon: "sparkles",
                    label: "Summarize",
                    color: .purple,
                    action: onSummarize
                )

                AIActionButton(
                    icon: "checklist",
                    label: "Actions",
                    color: .blue,
                    action: onActions
                )

                AIActionButton(
                    icon: "checkmark.seal",
                    label: "Decisions",
                    color: .green,
                    action: onDecisions
                )

                AIActionButton(
                    icon: "magnifyingglass",
                    label: "Search",
                    color: .orange,
                    action: onSearch
                )

                AIActionButton(
                    icon: "translate",
                    label: "Translate",
                    color: .pink,
                    action: onTranslate
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(
            colorScheme == .dark
                ? Color(.systemGray6)
                : Color(.systemGray6).opacity(0.5)
        )
    }
}

struct AIActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 70, height: 60)
            .foregroundStyle(color)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        AIBottomBar(
            onSummarize: { print("Summarize") },
            onActions: { print("Actions") },
            onDecisions: { print("Decisions") },
            onSearch: { print("Search") },
            onTranslate: { print("Translate") }
        )
    }
}
