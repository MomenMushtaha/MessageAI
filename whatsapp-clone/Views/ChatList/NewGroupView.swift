//
//  NewGroupView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct NewGroupView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var chatService = ChatService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var searchText = ""
    @State private var selectedUsers: Set<String> = []
    @State private var isLoading = false
    @State private var showingGroupDetails = false
    
    var onConversationCreated: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected Users Summary
                if !selectedUsers.isEmpty {
                    selectedUsersSummary
                }
                
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
                                SelectableUserRow(
                                    user: user,
                                    isSelected: selectedUsers.contains(user.id)
                                )
                                .onTapGesture {
                                    toggleUserSelection(user)
                                }
                                
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        showingGroupDetails = true
                    }
                    .disabled(selectedUsers.count < 2)
                }
            }
            .task {
                await loadUsers()
            }
            .sheet(isPresented: $showingGroupDetails) {
                GroupDetailsView(
                    selectedUsers: Array(selectedUsers),
                    allUsers: chatService.allUsers,
                    onGroupCreated: { conversationId in
                        dismiss()
                        onConversationCreated(conversationId)
                    }
                )
            }
        }
    }
    
    private var selectedUsersSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected: \(selectedUsers.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(selectedUsersList) { user in
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Text(user.initials)
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    }
                                
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 20, height: 20)
                                    .overlay {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white)
                                    }
                                    .offset(x: 5, y: -5)
                            }
                            .onTapGesture {
                                selectedUsers.remove(user.id)
                            }
                            
                            Text(user.displayName.components(separatedBy: " ").first ?? user.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                                .frame(width: 60)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.5))
    }
    
    private var selectedUsersList: [User] {
        chatService.allUsers.filter { selectedUsers.contains($0.id) }
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
    
    private func toggleUserSelection(_ user: User) {
        if selectedUsers.contains(user.id) {
            selectedUsers.remove(user.id)
        } else {
            selectedUsers.insert(user.id)
        }
    }
}

struct SelectableUserRow: View {
    let user: User
    let isSelected: Bool
    
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
            
            // Selection Indicator
            ZStack {
                Circle()
                    .stroke(Color.gray, lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct GroupDetailsView: View {
    let selectedUsers: [String]
    let allUsers: [User]
    
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var chatService = ChatService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var isCreating = false
    
    var onGroupCreated: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Group Icon
                Circle()
                    .fill(Color.purple.gradient)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 40)
                
                // Group Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    
                    TextField("Enter group name", text: $groupName)
                        .font(.title3)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Selected Members
                VStack(alignment: .leading, spacing: 12) {
                    Text("Members (\(selectedUsers.count + 1))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Current user
                            if let currentUser = authService.currentUser {
                                UserRow(user: currentUser)
                                Divider().padding(.leading, 76)
                            }
                            
                            // Selected users
                            ForEach(selectedUsersList) { user in
                                UserRow(user: user)
                                Divider().padding(.leading, 76)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Create Button
                Button(action: {
                    Task {
                        await createGroup()
                    }
                }) {
                    if isCreating {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Create Group")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(groupName.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
                .padding()
                .disabled(groupName.isEmpty || isCreating)
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var selectedUsersList: [User] {
        allUsers.filter { selectedUsers.contains($0.id) }
    }
    
    private func createGroup() async {
        guard let currentUserId = authService.currentUser?.id,
              !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isCreating = true
        
        do {
            var participantIds = selectedUsers
            participantIds.append(currentUserId)
            
            let conversationId = try await chatService.createOrGetConversation(
                participantIds: participantIds,
                type: .group,
                groupName: groupName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            print("✅ Group created: \(conversationId)")
            dismiss()
            onGroupCreated(conversationId)
            
        } catch {
            print("❌ Error creating group: \(error.localizedDescription)")
        }
        
        isCreating = false
    }
}

#Preview {
    NewGroupView(onConversationCreated: { _ in })
}

