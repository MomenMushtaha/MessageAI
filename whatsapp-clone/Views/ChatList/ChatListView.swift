//
//  ChatListView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct ChatListView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var chatService = ChatService.shared
    @State private var searchText = ""
    @State private var showingNewChat = false
    @State private var showingNewGroup = false
    @State private var selectedConversationId: String?
    @State private var showLogoutConfirmation = false
    @State private var conversationUsers: [String: User] = [:] // userId -> User
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search", text: $searchText)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Conversations List
                if chatService.conversations.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredConversations) { conversation in
                                ConversationRow(
                                    conversation: conversation,
                                    currentUserId: authService.currentUser?.id ?? "",
                                    otherUser: getOtherUser(for: conversation)
                                )
                                .onTapGesture {
                                    selectedConversationId = conversation.id
                                }
                                
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showLogoutConfirmation = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                        .foregroundStyle(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingNewChat = true }) {
                            Label("New Chat", systemImage: "message")
                        }
                        
                        Button(action: { showingNewGroup = true }) {
                            Label("New Group", systemImage: "person.3")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatView(onConversationCreated: { conversationId in
                    selectedConversationId = conversationId
                })
            }
            .sheet(isPresented: $showingNewGroup) {
                NewGroupView(onConversationCreated: { conversationId in
                    selectedConversationId = conversationId
                })
            }
            .navigationDestination(item: $selectedConversationId) { conversationId in
                if let conversation = chatService.conversations.first(where: { $0.id == conversationId }) {
                    ConversationDetailView(
                        conversation: conversation,
                        otherUser: getOtherUser(for: conversation)
                    )
                }
            }
            .confirmationDialog("Are you sure you want to logout?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Logout", role: .destructive) {
                    handleLogout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                startObservingConversations()
            }
            .onDisappear {
                chatService.stopObservingConversations()
            }
        }
    }
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return chatService.conversations
        } else {
            return chatService.conversations.filter { conversation in
                if conversation.type == .group {
                    return conversation.groupName?.localizedCaseInsensitiveContains(searchText) ?? false
                } else {
                    let otherUser = getOtherUser(for: conversation)
                    return otherUser?.displayName.localizedCaseInsensitiveContains(searchText) ?? false
                }
            }
        }
    }
    
    private func getOtherUser(for conversation: Conversation) -> User? {
        guard conversation.type == .direct,
              let currentUserId = authService.currentUser?.id else {
            return nil
        }
        
        let otherUserId = conversation.participantIds.first { $0 != currentUserId }
        
        guard let otherUserId = otherUserId else { return nil }
        
        // Return cached user if available
        if let cachedUser = conversationUsers[otherUserId] {
            return cachedUser
        }
        
        // Fetch user asynchronously
        Task {
            if let user = try? await chatService.getUser(userId: otherUserId) {
                await MainActor.run {
                    conversationUsers[otherUserId] = user
                }
            }
        }
        
        return nil
    }
    
    private func startObservingConversations() {
        guard let currentUserId = authService.currentUser?.id else { return }
        chatService.observeConversations(userId: currentUserId)
    }
    
    private func handleLogout() {
        do {
            try authService.logout()
        } catch {
            print("Logout error: \(error.localizedDescription)")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "message.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Conversations")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the compose button to start a new chat")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: String
    let otherUser: User?
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(conversation.type == .group ? Color.purple : Color.blue)
                .frame(width: 52, height: 52)
                .overlay {
                    if conversation.type == .group {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(.white)
                    } else if let user = otherUser {
                        Text(user.initials)
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white)
                    }
                }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.headline)
                    
                    Spacer()
                    
                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(lastMessageAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let lastMessage = conversation.lastMessageText {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var displayName: String {
        if conversation.type == .group {
            return conversation.groupName ?? "Group Chat"
        } else {
            return otherUser?.displayName ?? "Loading..."
        }
    }
}


#Preview {
    ChatListView()
}

