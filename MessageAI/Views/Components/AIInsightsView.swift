//
//  AIInsightsView.swift
//  MessageAI
//
//  AI Insights interface for Remote Team Professional features
//

import SwiftUI

struct AIInsightsView: View {
    let conversationId: String
    let messages: [Message]
    
    @StateObject private var aiService = AIService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: InsightTab = .summary
    @State private var summary: ConversationSummary?
    @State private var actionItems: [ActionItem] = []
    @State private var decisions: [Decision] = []
    @State private var isLoading = false
    @State private var error: String?
    
    enum InsightTab: String, CaseIterable {
        case summary = "Summary"
        case actions = "Actions"
        case decisions = "Decisions"
        case priority = "Priority"
        case search = "Search"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Insight Type", selection: $selectedTab) {
                    ForEach(InsightTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                if isLoading {
                    loadingView
                } else if let error = error {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshInsights) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            await loadAllInsights()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch selectedTab {
                case .summary:
                    summaryView
                case .actions:
                    actionItemsView
                case .decisions:
                    decisionsView
                case .priority:
                    priorityView
                case .search:
                    searchView
                }
            }
            .padding()
        }
    }
    
    // MARK: - Summary View
    
    @ViewBuilder
    private var summaryView: some View {
        if let summary = summary {
            VStack(alignment: .leading, spacing: 20) {
                // Main Summary
                InsightCard(
                    title: "Conversation Summary",
                    icon: "text.bubble.fill",
                    color: .blue
                ) {
                    Text(summary.summary)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                // Main Topics
                if !summary.mainTopics.isEmpty {
                    InsightCard(
                        title: "Main Topics",
                        icon: "list.bullet",
                        color: .purple
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(summary.mainTopics, id: \.self) { topic in
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(.purple)
                                    Text(topic)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
                
                // Key Decisions
                if !summary.keyDecisions.isEmpty {
                    InsightCard(
                        title: "Key Decisions",
                        icon: "checkmark.seal.fill",
                        color: .green
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(summary.keyDecisions, id: \.self) { decision in
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(.green)
                                    Text(decision)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
                
                // Important Info
                if !summary.importantInfo.isEmpty {
                    InsightCard(
                        title: "Important Information",
                        icon: "exclamationmark.triangle.fill",
                        color: .orange
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(summary.importantInfo, id: \.self) { info in
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(.orange)
                                    Text(info)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
                
                // Timestamp
                Text("Generated \(formatRelativeTime(summary.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            emptyStateView(
                icon: "text.bubble",
                title: "No Summary Available",
                message: "Tap refresh to generate a summary"
            )
        }
    }
    
    // MARK: - Action Items View
    
    @ViewBuilder
    private var actionItemsView: some View {
        if !actionItems.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Stats
                HStack(spacing: 20) {
                    StatBadge(
                        value: "\(actionItems.count)",
                        label: "Total",
                        color: .blue
                    )
                    StatBadge(
                        value: "\(actionItems.filter { !$0.completed }.count)",
                        label: "Pending",
                        color: .orange
                    )
                    StatBadge(
                        value: "\(actionItems.filter { $0.priority == .high }.count)",
                        label: "High Priority",
                        color: .red
                    )
                }
                
                // Action Items List
                ForEach(actionItems) { item in
                    ActionItemCard(item: item) {
                        // Toggle completion
                        if let index = actionItems.firstIndex(where: { $0.id == item.id }) {
                            actionItems[index].completed.toggle()
                        }
                    }
                }
            }
        } else {
            emptyStateView(
                icon: "checkmark.circle",
                title: "No Action Items",
                message: "No tasks or action items detected in this conversation"
            )
        }
    }
    
    // MARK: - Decisions View
    
    @ViewBuilder
    private var decisionsView: some View {
        if !decisions.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(decisions) { decision in
                    DecisionCard(decision: decision)
                }
            }
        } else {
            emptyStateView(
                icon: "checkmark.seal",
                title: "No Decisions Tracked",
                message: "No clear decisions detected in this conversation"
            )
        }
    }
    
    // MARK: - Priority View
    
    @ViewBuilder
    private var priorityView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Message Priority Analysis")
                .font(.headline)
            
            Text("AI analyzes messages in real-time to detect urgency and priority. High-priority messages are highlighted automatically.")
                .font(.body)
                .foregroundColor(.secondary)
            
            InsightCard(
                title: "Priority Detection",
                icon: "exclamationmark.triangle.fill",
                color: .red
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(
                        icon: "bolt.fill",
                        text: "Urgency indicators (ASAP, urgent, critical)",
                        color: .red
                    )
                    FeatureRow(
                        icon: "clock.fill",
                        text: "Time sensitivity (today, now, immediately)",
                        color: .orange
                    )
                    FeatureRow(
                        icon: "flag.fill",
                        text: "Action requirements (need, must, required)",
                        color: .yellow
                    )
                }
            }
            
            // Show high priority messages
            let highPriorityCount = messages.filter { msg in
                msg.text.localizedCaseInsensitiveContains("urgent") ||
                msg.text.localizedCaseInsensitiveContains("asap") ||
                msg.text.localizedCaseInsensitiveContains("critical")
            }.count
            
            if highPriorityCount > 0 {
                InsightCard(
                    title: "High Priority Messages",
                    icon: "exclamationmark.circle.fill",
                    color: .red
                ) {
                    Text("\(highPriorityCount) high-priority messages detected in this conversation")
                        .font(.body)
                }
            }
        }
    }
    
    // MARK: - Search View
    
    @ViewBuilder
    private var searchView: some View {
        SmartSearchView(messages: messages)
    }
    
    // MARK: - Helper Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("AI is analyzing conversation...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            Text("Error")
                .font(.title2.bold())
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await loadAllInsights()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadAllInsights() async {
        isLoading = true
        error = nil
        
        do {
            async let summaryTask = aiService.summarizeConversation(
                messages: messages,
                conversationId: conversationId
            )
            async let actionItemsTask = aiService.extractActionItems(
                messages: messages,
                conversationId: conversationId
            )
            async let decisionsTask = aiService.trackDecisions(
                messages: messages,
                conversationId: conversationId
            )
            
            let (summaryResult, actionItemsResult, decisionsResult) = try await (
                summaryTask,
                actionItemsTask,
                decisionsTask
            )
            
            summary = summaryResult
            actionItems = actionItemsResult
            decisions = decisionsResult
            
        } catch {
            self.error = error.localizedDescription
            print("❌ Error loading insights: \(error)")
        }
        
        isLoading = false
    }
    
    private func refreshInsights() {
        Task {
            await loadAllInsights()
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct InsightCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ActionItemCard: View {
    let item: ActionItem
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.completed ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.task)
                    .font(.body)
                    .strikethrough(item.completed)
                    .foregroundColor(item.completed ? .secondary : .primary)
                
                HStack {
                    if let assignee = item.assignee {
                        Label(assignee, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if let deadline = item.deadline {
                        Label(deadline, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    priorityBadge(item.priority)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func priorityBadge(_ priority: ActionPriority) -> some View {
        Text(priority.rawValue.uppercased())
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor(priority).opacity(0.2))
            .foregroundColor(priorityColor(priority))
            .cornerRadius(4)
    }
    
    private func priorityColor(_ priority: ActionPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

struct DecisionCard: View {
    let decision: Decision
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(confidenceColor)
                Text(decision.decision)
                    .font(.headline)
            }
            
            if !decision.context.isEmpty {
                Text(decision.context)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if !decision.participants.isEmpty {
                    Label("\(decision.participants.count) participants", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text(decision.timestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                confidenceBadge
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var confidenceColor: Color {
        switch decision.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .gray
        }
    }
    
    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
            Text(decision.confidence.rawValue)
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.2))
        .foregroundColor(confidenceColor)
        .cornerRadius(4)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

struct SmartSearchView: View {
    let messages: [Message]
    
    @State private var searchQuery = ""
    @State private var searchResults: [Message] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search Input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Ask anything about this conversation...", text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Button(action: performSearch) {
                HStack {
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isSearching ? "Searching..." : "AI Search")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(searchQuery.isEmpty || isSearching)
            
            // Info
            InsightCard(
                title: "Semantic Search",
                icon: "brain.head.profile",
                color: .purple
            ) {
                Text("AI understands the meaning of your query, not just keywords. Try asking questions like 'What did we decide about the budget?' or 'Who is responsible for the design?'")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Results
            if !searchResults.isEmpty {
                Text("Found \(searchResults.count) relevant messages")
                    .font(.headline)
                    .padding(.top)
                
                ForEach(searchResults) { message in
                    SearchResultRow(message: message)
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        
        Task {
            do {
                searchResults = try await AIService.shared.semanticSearch(
                    query: searchQuery,
                    messages: messages
                )
            } catch {
                print("❌ Search error: \(error)")
            }
            isSearching = false
        }
    }
}

struct SearchResultRow: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.text)
                .font(.body)
            
            Text(formatDate(message.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    AIInsightsView(
        conversationId: "test",
        messages: [
            Message(
                id: "1",
                conversationId: "test",
                senderId: "user1",
                text: "We need to complete the project by Friday. It's urgent!",
                createdAt: Date(),
                status: "sent"
            ),
            Message(
                id: "2",
                conversationId: "test",
                senderId: "user2",
                text: "I'll handle the design part. Sarah, can you do the research?",
                createdAt: Date(),
                status: "sent"
            )
        ]
    )
}

