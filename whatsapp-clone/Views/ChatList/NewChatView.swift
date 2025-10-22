//
//  NewChatView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct NewChatView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var chatService = ChatService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var isLoading = false
    
    var onConversationCreated: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search users", text: $searchText)
                    
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
                
                // Users List
                if isLoading {
                    ProgressView("Loading users...")
                        .padding()
                } else if filteredUsers.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredUsers) { user in
                                UserRow(user: user)
                                    .onTapGesture {
                                        Task {
                                            await createConversation(with: user)
                                        }
                                    }
                                
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    private var filteredUsers: [User] {
        if searchText.isEmpty {
            return chatService.allUsers
        } else {
            return chatService.allUsers.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Users Found")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty ? "No other users have signed up yet" : "No users match your search")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    private func loadUsers() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        isLoading = true
        await chatService.fetchAllUsers(excludingUserId: currentUserId)
        isLoading = false
    }
    
    private func createConversation(with user: User) async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        do {
            let conversationId = try await chatService.createOrGetConversation(
                participantIds: [currentUserId, user.id],
                type: .direct
            )
            
            dismiss()
            onConversationCreated(conversationId)
            
        } catch {
            print("❌ Error creating conversation: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

struct UserRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue)
                .frame(width: 52, height: 52)
                .overlay {
                    Text(user.initials)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    NewChatView(onConversationCreated: { _ in })
}

