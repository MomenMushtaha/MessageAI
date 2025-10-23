//
//  ForwardMessageView.swift
//  MessageAI
//
//  View for selecting conversations to forward a message to
//

import SwiftUI

struct ForwardMessageView: View {
    let message: Message
    let onForward: ([String]) -> Void
    let onDismiss: () -> Void
    
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatService: ChatService
    
    @State private var selectedConversationIds: Set<String> = []
    @State private var searchText = ""
    @State private var conversationUsers: [String: User] = [:]
    @Environment(\.dismiss) private var dismiss
    
    private var filteredConversations: [Conversation] {
        let allConversations = chatService.conversations
        
        if searchText.isEmpty {
            return allConversations
        } else {
            return allConversations.filter { conversation in
                if conversation.type == .group {
                    return conversation.groupName?.localizedCaseInsensitiveContains(searchText) ?? false
                } else {
                    if let otherUserId = getOtherUserId(for: conversation),
                       let otherUser = conversationUsers[otherUserId] {
                        return otherUser.displayName.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message Preview
                messagePreview
                
                Divider()
                
                // Search Bar
                searchBar
                
                // Conversation List
                if filteredConversations.isEmpty {
                    emptyStateView
                } else {
                    List(filteredConversations) { conversation in
                        conversationRow(conversation)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(conversation.id)
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Forward Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Forward") {
                        forwardMessage()
                    }
                    .disabled(selectedConversationIds.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadConversationUsers()
            }
        }
    }
    
    private var messagePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrowshape.turn.up.right.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
                
                Text("Forward to...")
                    .font(.headline)
                
                Spacer()
            }
            
            Text(message.text)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.leading, 32)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search conversations", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "message.badge.waveform")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Conversations Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(searchText.isEmpty ? 
                 "Start a conversation to forward messages" :
                 "No conversations match '\(searchText)'")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: 12) {
            // Selection Indicator
            ZStack {
                Circle()
                    .stroke(selectedConversationIds.contains(conversation.id) ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if selectedConversationIds.contains(conversation.id) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 16, height: 16)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            
            // Avatar
            Circle()
                .fill(conversation.type == .group ? Color.purple : Color.blue)
                .frame(width: 44, height: 44)
                .overlay {
                    if conversation.type == .group {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                    } else if let otherUserId = getOtherUserId(for: conversation),
                              let user = conversationUsers[otherUserId] {
                        Text(user.initials)
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                    }
                }
            
            // Name and Details
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName(for: conversation))
                    .font(.system(size: 16, weight: .semibold))
                
                if let lastMessage = conversation.lastMessageText {
                    Text(lastMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Functions
    
    private func getOtherUserId(for conversation: Conversation) -> String? {
        guard conversation.type == .direct,
              let currentUserId = authService.currentUser?.id else {
            return nil
        }
        return conversation.participantIds.first { $0 != currentUserId }
    }
    
    private func displayName(for conversation: Conversation) -> String {
        if conversation.type == .group {
            return conversation.groupName ?? "Group Chat"
        } else if let otherUserId = getOtherUserId(for: conversation),
                  let user = conversationUsers[otherUserId] {
            return user.displayName
        }
        return "Chat"
    }
    
    private func toggleSelection(_ conversationId: String) {
        if selectedConversationIds.contains(conversationId) {
            selectedConversationIds.remove(conversationId)
        } else {
            selectedConversationIds.insert(conversationId)
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func loadConversationUsers() {
        Task {
            let userIds = Set(chatService.conversations
                .filter { $0.type == .direct }
                .flatMap { $0.participantIds }
                .filter { $0 != authService.currentUser?.id })
            
            for userId in userIds {
                if conversationUsers[userId] == nil {
                    if let user = try? await chatService.getUser(userId: userId) {
                        await MainActor.run {
                            conversationUsers[userId] = user
                        }
                    }
                }
            }
        }
    }
    
    private func forwardMessage() {
        let conversationIds = Array(selectedConversationIds)
        onForward(conversationIds)
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }
}

#Preview {
    ForwardMessageView(
        message: Message(
            id: "1",
            conversationId: "conv1",
            senderId: "user1",
            text: "Check out this cool message!",
            createdAt: Date()
        ),
        onForward: { conversationIds in
            print("Forwarding to \(conversationIds.count) conversations")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .environmentObject(AuthService.shared)
    .environmentObject(ChatService.shared)
}

