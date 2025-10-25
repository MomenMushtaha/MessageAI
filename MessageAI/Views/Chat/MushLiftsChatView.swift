//
//  MushLiftsChatView.swift
//  MessageAI
//
//  MushLifts AI Fitness Assistant Chat Interface
//

import SwiftUI

struct MushLiftsChatView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText = ""
    @State private var messages: [MushLiftsMessage] = []
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
                            colors: [.green, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("MushLifts")
                        .font(.headline)
                    Text("Your online fitness trainer and nutritionist")
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
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .padding(.top, 40)
                                
                                Text("Hi! I'm MushLifts")
                                    .font(.title.bold())
                                
                                Text("Your online fitness trainer and nutritionist")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    FitnessSuggestionButton(
                                        icon: "figure.run",
                                        title: "Create a workout plan",
                                        gradient: [.green, .orange],
                                        action: { sendMessage("Create a workout plan for me") }
                                    )
                                    
                                    FitnessSuggestionButton(
                                        icon: "fork.knife",
                                        title: "Get nutrition advice",
                                        gradient: [.green, .orange],
                                        action: { sendMessage("Help me plan my meals for the week") }
                                    )
                                    
                                    FitnessSuggestionButton(
                                        icon: "chart.line.uptrend.xyaxis",
                                        title: "Track my progress",
                                        gradient: [.green, .orange],
                                        action: { sendMessage("How can I track my fitness progress?") }
                                    )
                                    
                                    FitnessSuggestionButton(
                                        icon: "heart.text.square",
                                        title: "Fitness tips & motivation",
                                        gradient: [.green, .orange],
                                        action: { sendMessage("Give me some fitness motivation") }
                                    )
                                }
                                .padding(.horizontal)
                                .padding(.top, 20)
                            }
                            .padding()
                        } else {
                            ForEach(messages) { message in
                                FitnessMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("MushLifts is thinking...")
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
                    TextField("Ask about fitness, workouts, nutrition...", text: $messageText, axis: .vertical)
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
                            .foregroundStyle(
                                messageText.isEmpty ? .gray : 
                                LinearGradient(
                                    colors: [.green, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
        
        let userMessage = MushLiftsMessage(
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
            await chatWithMushLifts(userId: userId, message: text)
        }
    }
    
    private func chatWithMushLifts(userId: String, message: String) async {
        // Build messages array for API
        let apiMessages = messages.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }
        
        guard let endpoint = AppConfig.mushLiftsChatEndpoint else {
            await MainActor.run {
                isLoading = false
                errorMessage = "MushLifts endpoint not configured"
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
                    let assistantMessage = MushLiftsMessage(
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

struct MushLiftsMessage: Identifiable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    enum MessageRole: String {
        case user
        case assistant
    }
}

// MARK: - Fitness Message Bubble

struct FitnessMessageBubble: View {
    let message: MushLiftsMessage
    
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
                            ? LinearGradient(
                                colors: [.green, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color(.systemGray5), Color(.systemGray5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
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

// MARK: - Fitness Suggestion Button

struct FitnessSuggestionButton: View {
    let icon: String
    let title: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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

