//
//  ChatListView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct ChatListView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var searchText = ""
    @State private var showingNewChat = false
    @State private var selectedConversation: Conversation?
    @State private var showLogoutConfirmation = false
    
    // Mock data for now (will be replaced with real data in Step 3)
    private let mockConversations: [Conversation] = [
        Conversation(
            id: "1",
            type: .direct,
            participantIds: ["user1", "user2"],
            lastMessageText: "Hey! How are you?",
            lastMessageAt: Date().addingTimeInterval(-3600)
        ),
        Conversation(
            id: "2",
            type: .group,
            participantIds: ["user1", "user3", "user4"],
            lastMessageText: "See you tomorrow!",
            lastMessageAt: Date().addingTimeInterval(-7200),
            groupName: "Project Team"
        ),
        Conversation(
            id: "3",
            type: .direct,
            participantIds: ["user1", "user5"],
            lastMessageText: "Thanks for your help!",
            lastMessageAt: Date().addingTimeInterval(-86400)
        )
    ]
    
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
                if mockConversations.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(mockConversations) { conversation in
                                ConversationRow(conversation: conversation)
                                    .onTapGesture {
                                        selectedConversation = conversation
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
                    Button(action: { showingNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatPlaceholderView()
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ConversationDetailView(conversation: conversation)
            }
            .confirmationDialog("Are you sure you want to logout?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Logout", role: .destructive) {
                    handleLogout()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(conversation.type == .group ? Color.purple : Color.blue)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: conversation.type == .group ? "person.3.fill" : "person.fill")
                        .foregroundStyle(.white)
                }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.type == .group ? (conversation.groupName ?? "Group") : "Contact")
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
}

// Placeholder view for new chat (will implement in Step 3)
struct NewChatPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("New Chat View")
                    .font(.title2)
                Text("(Will be implemented in Step 3)")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("New Chat")
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
    ChatListView()
}

