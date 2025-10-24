//
//  AIResultCard.swift
//  MessageAI
//
//  AI result display card (Phase B)
//

import SwiftUI

struct AIResultCard: View {
    let title: String
    let content: String
    let sources: [String]
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            if isExpanded {
                // Content
                Text(content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                // Sources
                if !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sources (\(sources.count) messages)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sources.prefix(10), id: \.self) { sourceId in
                                    Text(sourceId.prefix(8))
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    AIResultCard(
        title: "Summary",
        content: """
        ## Key Points
        - Design review needed for new onboarding
        - ETA to ship is next Friday
        - Decision: go with Option B

        ## Open Questions
        - Need migration script by Thursday

        ## Next Steps
        - Sam to prepare migration script
        - QA to test payment flow
        """,
        sources: ["msg1", "msg2", "msg3"]
    )
}
