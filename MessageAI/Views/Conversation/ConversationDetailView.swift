//
//  ConversationDetailView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI
import FirebaseFirestore

struct ConversationDetailView: View {
    let conversation: Conversation
    let otherUser: User?
    
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatService: ChatService
    @State private var messageText = ""
    @State private var isSending = false
    @State private var participantUsers: [String: User] = [:] // userId -> User cache
    @State private var showParticipantList = false
    @State private var otherUserPresence: (isOnline: Bool, lastSeen: Date?) = (false, nil)
    @State private var presenceListener: ListenerRegistration?
    @State private var showScrollToBottom = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showClearHistoryAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if currentMessages.isEmpty {
                                emptyMessagesView
                            } else {
                                ForEach(currentMessages) { message in
                                    MessageBubbleRow(
                                        message: message,
                                        isFromCurrentUser: message.senderId == authService.currentUser?.id,
                                        senderName: participantUsers[message.senderId]?.displayName,
                                        conversation: conversation,
                                        currentUserId: authService.currentUser?.id ?? ""
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: currentMessages.count) { oldValue, newValue in
                        if newValue > oldValue, let lastMessage = currentMessages.last {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let lastMessage = currentMessages.last {
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Scroll to Bottom Button
                if showScrollToBottom {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if let lastMessage = currentMessages.last {
                                // Use ScrollViewReader's proxy - need to pass it
                            }
                        }
                    }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white, .blue)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Message Input
            messageInputView
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    if conversation.type == .group {
                        showParticipantList = true
                    }
                }) {
                    VStack(spacing: 2) {
                        Text(displayTitle)
                            .font(.headline)
                        
                        if conversation.type == .direct {
                            HStack(spacing: 4) {
                                if otherUserPresence.isOnline {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                }
                                Text(presenceStatusText)
                                    .font(.caption)
                                    .foregroundStyle(otherUserPresence.isOnline ? .green : .secondary)
                            }
                        } else {
                            Text("\(conversation.participantIds.count) participants")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive, action: {
                        showClearHistoryAlert = true
                    }) {
                        Label("Clear Chat History", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.blue)
                }
            }
        }
        .sheet(isPresented: $showParticipantList) {
            ParticipantListView(
                participantIds: conversation.participantIds,
                participantUsers: participantUsers
            )
        }
        .onAppear {
            // Load participant users first (especially important for new groups)
            loadParticipantUsers()
            
            // Then start observing messages
            chatService.observeMessages(conversationId: conversation.id)
            markMessagesAsDeliveredAndRead()
            startObservingPresence()
            
            // Track current conversation for notifications
            NotificationService.shared.setCurrentConversation(conversation.id)
        }
        .onDisappear {
            chatService.stopObservingMessages(conversationId: conversation.id)
            stopObservingPresence()
            
            // Clear current conversation
            NotificationService.shared.setCurrentConversation(nil)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Clear Chat History?", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task {
                    await clearChatHistory()
                }
            }
        } message: {
            Text("This will delete all messages from this chat on your device only. Other participants will still see the messages.")
        }
    }
    
    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            if participantUsers.isEmpty && conversation.type == .group {
                // Loading state for new groups
                ProgressView()
                    .padding()
                Text("Loading group...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: conversation.type == .group ? "person.3.fill" : "message.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text(conversation.type == .group ? "Group created!" : "No messages yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Start a conversation!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private var messageInputView: some View {
        VStack(spacing: 4) {
            // Character count warning (only show when approaching limit)
            if messageText.count > 3500 {
                HStack {
                    Spacer()
                    Text("\(messageText.count) / 4096")
                        .font(.caption2)
                        .foregroundStyle(messageText.count > 4096 ? .red : .secondary)
                        .padding(.trailing, 16)
                }
            }
            
            HStack(spacing: 12) {
                // Text Field
                HStack {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .font(.body)
                }
                .background(Color(.systemGray6))
                .cornerRadius(24)
            
            // Send Button
            Button(action: {
                Task {
                    await sendMessage()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(messageText.isEmpty ? Color(.systemGray4) : Color.blue)
                        .frame(width: 38, height: 38)
                    
                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
                .disabled(messageText.isEmpty || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
        )
    }
    
    private var currentMessages: [Message] {
        chatService.messages[conversation.id] ?? []
    }
    
    private var displayTitle: String {
        if conversation.type == .group {
            return conversation.groupName ?? "Group Chat"
        } else {
            return otherUser?.displayName ?? "Chat"
        }
    }
    
    private var presenceStatusText: String {
        if conversation.type != .direct {
            return ""
        }
        
        if otherUserPresence.isOnline {
            return "Online"
        }
        
        guard let lastSeen = otherUserPresence.lastSeen else {
            return "Last seen recently"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastSeen)
        
        if timeInterval < 60 {
            return "Last seen just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "Last seen \(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "Last seen \(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "Last seen \(days)d ago"
        }
    }
    
    private func loadParticipantUsers() {
        Task {
            // Load all participant users upfront (important for group chats)
            await MainActor.run {
                print("📥 Loading \(conversation.participantIds.count) participant users...")
            }
            
            for participantId in conversation.participantIds {
                if participantUsers[participantId] == nil {
                    if let user = try? await chatService.getUser(userId: participantId) {
                        await MainActor.run {
                            participantUsers[participantId] = user
                            print("✅ Loaded user: \(user.displayName)")
                        }
                    }
                }
            }
            
            await MainActor.run {
                print("✅ All \(participantUsers.count) participant users loaded")
            }
        }
    }
    
    private func markMessagesAsDeliveredAndRead() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            // First mark as delivered
            await chatService.markMessagesAsDelivered(conversationId: conversation.id, userId: currentUserId)
            
            // Then mark as read (since user is viewing the conversation)
            await chatService.markMessagesAsRead(conversationId: conversation.id, userId: currentUserId)
        }
    }
    
    private func startObservingPresence() {
        // Only observe presence for direct conversations
        guard conversation.type == .direct,
              let otherUserId = conversation.participantIds.first(where: { $0 != authService.currentUser?.id }) else {
            return
        }
        
        presenceListener = PresenceService.shared.observeUserPresence(userId: otherUserId) { isOnline, lastSeen in
            Task { @MainActor in
                self.otherUserPresence = (isOnline, lastSeen)
            }
        }
    }
    
    private func stopObservingPresence() {
        presenceListener?.remove()
        presenceListener = nil
    }
    
    private func sendMessage() async {
        guard let currentUserId = authService.currentUser?.id else {
            return
        }
        
        let textToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate before sending
        guard !textToSend.isEmpty else {
            errorMessage = "Please enter a message"
            showErrorAlert = true
            return
        }
        
        guard textToSend.count <= 4096 else {
            errorMessage = "Message is too long (max 4096 characters)"
            showErrorAlert = true
            return
        }
        
        messageText = ""
        isSending = true
        
        do {
            try await chatService.sendMessage(
                conversationId: conversation.id,
                senderId: currentUserId,
                text: textToSend
            )
        } catch {
            print("❌ Error sending message: \(error.localizedDescription)")
            // Show error to user
            errorMessage = error.localizedDescription
            showErrorAlert = true
            // Restore message text on error
            messageText = textToSend
        }
        
        isSending = false
    }
    
    private func clearChatHistory() async {
        do {
            try await chatService.clearChatHistory(conversationId: conversation.id)
            print("✅ Chat history cleared successfully")
        } catch {
            print("❌ Error clearing chat history: \(error.localizedDescription)")
            errorMessage = "Failed to clear chat history: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

struct MessageBubbleRow: View, Equatable {
    let message: Message
    let isFromCurrentUser: Bool
    let senderName: String?
    let conversation: Conversation
    let currentUserId: String
    
    // Equatable conformance for performance optimization
    static func == (lhs: MessageBubbleRow, rhs: MessageBubbleRow) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.status == rhs.message.status &&
        lhs.message.text == rhs.message.text &&
        lhs.senderName == rhs.senderName
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Show sender name for group chats (incoming messages only)
                if !isFromCurrentUser, let senderName = senderName {
                    Text(senderName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.blue)
                        .padding(.leading, 12)
                        .padding(.top, 2)
                }
                
                // Message bubble
                HStack(alignment: .bottom, spacing: 4) {
                    Text(message.text)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            bubbleBackground
                        )
                        .foregroundStyle(isFromCurrentUser ? .white : .primary)
                        .clipShape(BubbleShape(isFromCurrentUser: isFromCurrentUser))
                    
                    // Timestamp and status in the corner
                    if isFromCurrentUser {
                        VStack(alignment: .trailing, spacing: 2) {
                            Spacer()
                            HStack(spacing: 2) {
                                Text(message.createdAt, style: .time)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                statusIcon
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
                
                // Timestamp for incoming messages
                if !isFromCurrentUser {
                    Text(message.createdAt, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if isFromCurrentUser {
                if message.displayStatus(for: conversation, currentUserId: currentUserId) == "error" {
                    LinearGradient(
                        colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                Color(.systemGray5)
            }
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        let displayStatus = message.displayStatus(for: conversation, currentUserId: currentUserId)
        
        switch displayStatus {
        case "sending":
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 10, height: 10)
                .tint(.white.opacity(0.8))
        case "sent":
            Image(systemName: "checkmark")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))
        case "delivered":
            Image(systemName: "checkmark.checkmark")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))
        case "read":
            Image(systemName: "checkmark.checkmark")
                .font(.system(size: 10))
                .foregroundStyle(.cyan)
        case "error":
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white)
        default:
            EmptyView()
        }
    }
}

// MARK: - Custom Bubble Shape

struct BubbleShape: Shape {
    let isFromCurrentUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isFromCurrentUser ?
                [.topLeft, .topRight, .bottomLeft] :
                [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}

struct ParticipantListView: View {
    let participantIds: [String]
    let participantUsers: [String: User]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(participantIds, id: \.self) { participantId in
                        if let user = participantUsers[participantId] {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text(user.initials)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                    }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                
                                Text("Loading...")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("\(participantIds.count) Participants")
                }
            }
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConversationDetailView(
            conversation: Conversation(
                id: "1",
                type: .direct,
                participantIds: ["user1", "user2"]
            ),
            otherUser: User(
                id: "user2",
                displayName: "John Doe",
                email: "john@example.com",
                createdAt: Date()
            )
        )
    }
}

