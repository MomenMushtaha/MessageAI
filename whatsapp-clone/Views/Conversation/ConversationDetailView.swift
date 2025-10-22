//
//  ConversationDetailView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct ConversationDetailView: View {
    let conversation: Conversation
    let otherUser: User?
    
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var chatService = ChatService.shared
    @State private var messageText = ""
    @State private var isSending = false
    @State private var participantUsers: [String: User] = [:] // userId -> User cache
    @State private var showParticipantList = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if currentMessages.isEmpty {
                            emptyMessagesView
                        } else {
                            ForEach(currentMessages) { message in
                                MessageBubbleRow(
                                    message: message,
                                    isFromCurrentUser: message.senderId == authService.currentUser?.id,
                                    senderName: getSenderName(for: message)
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: currentMessages.count) { oldValue, newValue in
                    if newValue > oldValue, let lastMessage = currentMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = currentMessages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
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
                            Text("Tap to view profile")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(conversation.participantIds.count) participants")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showParticipantList) {
            ParticipantListView(
                participantIds: conversation.participantIds,
                participantUsers: participantUsers
            )
        }
        .onAppear {
            chatService.observeMessages(conversationId: conversation.id)
            loadParticipantUsers()
        }
        .onDisappear {
            chatService.stopObservingMessages(conversationId: conversation.id)
        }
    }
    
    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No messages yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Start a conversation!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private var messageInputView: some View {
        HStack(spacing: 12) {
            // Text Field
            HStack {
                TextField("Message", text: $messageText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .background(Color(.systemGray6))
            .cornerRadius(20)
            
            // Send Button
            Button(action: {
                Task {
                    await sendMessage()
                }
            }) {
                if isSending {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(messageText.isEmpty ? .gray : .blue)
                }
            }
            .disabled(messageText.isEmpty || isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
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
    
    private func getSenderName(for message: Message) -> String? {
        guard conversation.type == .group else { return nil }
        
        if message.senderId == authService.currentUser?.id {
            return "You"
        }
        
        // Return cached user name if available
        if let user = participantUsers[message.senderId] {
            return user.displayName
        }
        
        // Fetch user asynchronously if not in cache
        if !participantUsers.keys.contains(message.senderId) {
            Task {
                if let user = try? await chatService.getUser(userId: message.senderId) {
                    await MainActor.run {
                        participantUsers[message.senderId] = user
                    }
                }
            }
        }
        
        return "Loading..."
    }
    
    private func loadParticipantUsers() {
        guard conversation.type == .group else { return }
        
        Task {
            for participantId in conversation.participantIds {
                if participantUsers[participantId] == nil {
                    if let user = try? await chatService.getUser(userId: participantId) {
                        await MainActor.run {
                            participantUsers[participantId] = user
                        }
                    }
                }
            }
        }
    }
    
    private func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUserId = authService.currentUser?.id else {
            return
        }
        
        let textToSend = messageText
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
            // Restore message text on error
            messageText = textToSend
        }
        
        isSending = false
    }
}

struct MessageBubbleRow: View {
    let message: Message
    let isFromCurrentUser: Bool
    let senderName: String?
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Show sender name for group chats (incoming messages only)
                if !isFromCurrentUser, let senderName = senderName {
                    Text(senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                }
                
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isFromCurrentUser ? (message.status == "error" ? Color.red.opacity(0.7) : Color.blue) : Color(.systemGray5))
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    // Status indicator for sent messages
                    if isFromCurrentUser {
                        statusIcon
                    }
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case "sending":
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 12, height: 12)
        case "sent":
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case "delivered":
            Image(systemName: "checkmark.checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case "read":
            Image(systemName: "checkmark.checkmark")
                .font(.caption2)
                .foregroundStyle(.blue)
        case "error":
            Image(systemName: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.red)
        default:
            EmptyView()
        }
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

