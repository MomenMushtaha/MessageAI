//
//  ChatListView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatService: ChatService
    @State private var searchText = ""
    @State private var showingNewChat = false
    @State private var showingNewGroup = false
    @State private var selectedConversationId: String?
    @State private var showLogoutConfirmation = false
    @State private var conversationUsers: [String: User] = [:] // userId -> User
    @State private var isLoadingUsers = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showPerformanceMonitor = false
    
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
                    List {
                        ForEach(filteredConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                currentUserId: authService.currentUser?.id ?? "",
                                otherUser: conversationUsers[getOtherUserId(for: conversation) ?? ""]
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedConversationId = conversation.id
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteConversation(conversation)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteConversation(conversation)
                                } label: {
                                    Label("Delete \(conversation.type == .group ? "Group" : "Chat")", systemImage: "trash")
                                }
                            }
                            
                            Divider()
                                .padding(.leading, 76)
                        }
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showLogoutConfirmation = true }) {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        
                        Button(action: { showPerformanceMonitor = true }) {
                            Label("Performance Monitor", systemImage: "chart.xyaxis.line")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
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
                .environmentObject(authService)
                .environmentObject(chatService)
            }
            .sheet(isPresented: $showingNewGroup) {
                NewGroupView(onConversationCreated: { conversationId in
                    selectedConversationId = conversationId
                })
                .environmentObject(authService)
                .environmentObject(chatService)
            }
            .sheet(isPresented: $showPerformanceMonitor) {
                PerformanceMonitorView()
            }
            .navigationDestination(item: $selectedConversationId) { conversationId in
                if let conversation = chatService.conversations.first(where: { $0.id == conversationId }) {
                    let otherUserId = getOtherUserId(for: conversation)
                    ConversationDetailView(
                        conversation: conversation,
                        otherUser: otherUserId != nil ? conversationUsers[otherUserId!] : nil
                    )
                    .onAppear {
                        // Ensure users are loaded when navigating to a conversation
                        if conversation.type == .direct, let userId = otherUserId, conversationUsers[userId] == nil {
                            Task {
                                if let user = try? await chatService.getUser(userId: userId) {
                                    await MainActor.run {
                                        conversationUsers[userId] = user
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Conversation not loaded yet (e.g., just created group)
                    // Show loading state while Firestore listener catches up
                    VStack(spacing: 16) {
                        ProgressView()
                            .padding()
                        Text("Loading conversation...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .onAppear {
                        print("⚠️ Conversation not found yet: \(conversationId)")
                        print("📊 Available conversations: \(chatService.conversations.map { $0.id })")
                    }
                }
            }
            .confirmationDialog("Are you sure you want to logout?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Logout", role: .destructive) {
                    handleLogout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete Failed", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage)
            }
            .onAppear {
                startObservingConversations()
                preloadConversationUsers()
            }
            .onChange(of: chatService.conversations) { _, _ in
                preloadConversationUsers()
            }
            .onDisappear {
                chatService.stopObservingConversations()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConversation"))) { notification in
                // Handle notification tap to open specific conversation
                if let conversationId = notification.userInfo?["conversationId"] as? String {
                    print("📱 Opening conversation from notification: \(conversationId)")
                    selectedConversationId = conversationId
                }
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
                    if let otherUserId = getOtherUserId(for: conversation),
                       let otherUser = conversationUsers[otherUserId] {
                        return otherUser.displayName.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                }
            }
        }
    }
    
    private func getOtherUserId(for conversation: Conversation) -> String? {
        guard conversation.type == .direct,
              let currentUserId = authService.currentUser?.id else {
            return nil
        }
        return conversation.participantIds.first { $0 != currentUserId }
    }
    
    private func preloadConversationUsers() {
        guard !isLoadingUsers else { return }
        isLoadingUsers = true
        
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
            
            await MainActor.run {
                isLoadingUsers = false
            }
        }
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
    
    private func deleteConversation(_ conversation: Conversation) {
        Task {
            do {
                try await chatService.deleteConversation(conversationId: conversation.id)
                print("✅ Successfully deleted conversation")
                
                // If we're currently viewing this conversation, navigate away
                if selectedConversationId == conversation.id {
                    selectedConversationId = nil
                }
            } catch {
                deleteErrorMessage = "Failed to delete \(conversation.type == .group ? "group" : "chat"): \(error.localizedDescription)"
                showDeleteError = true
                print("❌ Error deleting conversation: \(error.localizedDescription)")
            }
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

struct ConversationRow: View, Equatable {
    let conversation: Conversation
    let currentUserId: String
    let otherUser: User?

    // Equatable conformance for performance optimization
    static func == (lhs: ConversationRow, rhs: ConversationRow) -> Bool {
        lhs.conversation.id == rhs.conversation.id &&
        lhs.conversation.lastMessageText == rhs.conversation.lastMessageText &&
        lhs.conversation.lastMessageAt == rhs.conversation.lastMessageAt &&
        lhs.otherUser?.id == rhs.otherUser?.id &&
        lhs.otherUser?.isOnline == rhs.otherUser?.isOnline
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
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
                
                // Online indicator for direct chats
                if conversation.type == .direct, let user = otherUser, user.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.system(size: 17, weight: .semibold))

                    Spacer()

                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(lastMessageAt, style: .relative)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    if let lastMessage = conversation.lastMessageText {
                        Text(lastMessage)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    // Unread badge
                    if conversation.unreadCount(for: currentUserId) > 0 {
                        Text("\(conversation.unreadCount(for: currentUserId))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
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

