//
//  MoChainChatView.swift
//  MessageAI
//
//  MoChain AI Assistant Chat Interface
//

import SwiftUI

struct MoChainChatView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText = ""
    @State private var messages: [MoChainMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("MoChain")
                        .font(.headline)
                    Text("AI Assistant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if messages.isEmpty {
                            // Welcome message
                            VStack(spacing: 16) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 60))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .padding(.top, 40)
                                
                                Text("Hi! I'm MoChain")
                                    .font(.title.bold())
                                
                                Text("Your AI assistant for MessageAI")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    SuggestionButton(
                                        icon: "magnifyingglass",
                                        title: "Search my messages",
                                        action: { sendMessage("Search my recent messages") }
                                    )
                                    
                                    SuggestionButton(
                                        icon: "doc.text",
                                        title: "Summarize conversations",
                                        action: { sendMessage("Summarize my conversations from this week") }
                                    )
                                    
                                    SuggestionButton(
                                        icon: "checkmark.circle",
                                        title: "Find action items",
                                        action: { sendMessage("What are my action items?") }
                                    )
                                    
                                    SuggestionButton(
                                        icon: "globe",
                                        title: "Translate messages",
                                        action: { sendMessage("Help me translate a message") }
                                    )
                                }
                                .padding(.horizontal)
                                .padding(.top, 20)
                            }
                            .padding()
                        } else {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("MoChain is thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input
            VStack(spacing: 0) {
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Dismiss") {
                            errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }
                
                Divider()
                
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Ask MoChain anything...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    
                    Button {
                        sendMessage(messageText)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(messageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty || isLoading)
                }
                .padding()
            }
        }
        .onAppear {
            loadHistory()
        }
    }
    
    private func sendMessage(_ text: String) {
        guard !text.isEmpty, let userId = authService.currentUser?.id else { return }
        
        let userMessage = MoChainMessage(
            id: UUID().uuidString,
            role: .user,
            content: text,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        messageText = ""
        isLoading = true
        errorMessage = nil
        
        Task {
            await chatWithMoChain(userId: userId, message: text)
        }
    }
    
    private func chatWithMoChain(userId: String, message: String) async {
        // Build messages array for API
        let apiMessages = messages.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }
        
        guard let endpoint = AppConfig.mochainChatEndpoint else {
            await MainActor.run {
                isLoading = false
                errorMessage = "MoChain endpoint not configured"
            }
            return
        }
        
        guard let url = URL(string: endpoint) else {
            await MainActor.run {
                isLoading = false
                errorMessage = "Invalid endpoint URL"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "messages": apiMessages,
            "stream": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                
                await MainActor.run {
                    let assistantMessage = MoChainMessage(
                        id: UUID().uuidString,
                        role: .assistant,
                        content: response,
                        timestamp: Date()
                    )
                    messages.append(assistantMessage)
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadHistory() {
        // Load conversation history if needed
        // For now, start fresh each time
    }
}

// MARK: - Message Model

struct MoChainMessage: Identifiable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    enum MessageRole: String {
        case user
        case assistant
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: MoChainMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.role == .user
                            ? Color.blue
                            : Color(.systemGray5)
                    )
                    .foregroundStyle(
                        message.role == .user
                            ? .white
                            : .primary
                    )
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

// MARK: - Suggestion Button

struct SuggestionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

