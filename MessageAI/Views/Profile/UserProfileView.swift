//
//  UserProfileView.swift
//  MessageAI
//
//  Created by MessageAI - Phase 6: Advanced Features
//

import SwiftUI

struct UserProfileView: View {
    let user: User

    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatService: ChatService
    @Environment(\.dismiss) private var dismiss

    @State private var showEditProfile = false
    @State private var sharedGroups: [Conversation] = []

    private var isOwnProfile: Bool {
        user.id == authService.currentUser?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar Section
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 120, height: 120)
                            .overlay {
                                Text(user.initials)
                                    .font(.system(size: 48, weight: .medium))
                                    .foregroundStyle(.white)
                            }

                        VStack(spacing: 4) {
                            Text(user.displayName)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Online Status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(user.isOnline ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)

                            Text(user.isOnline ? "Online" : "Offline")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !user.isOnline, let lastSeen = user.lastSeen {
                                Text("• Last seen \(lastSeen, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 32)

                    // Info Section
                    VStack(spacing: 16) {
                        InfoRow(icon: "calendar", title: "Joined", value: user.createdAt.formatted(date: .long, time: .omitted))

                        if !sharedGroups.isEmpty {
                            InfoRow(icon: "person.3.fill", title: "Shared Groups", value: "\(sharedGroups.count)")
                        }
                    }
                    .padding(.horizontal)

                    // Shared Groups
                    if !sharedGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Shared Groups")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(sharedGroups) { group in
                                GroupRow(conversation: group)
                            }
                        }
                    }

                    // Action Buttons
                    if !isOwnProfile {
                        Button(action: {
                            Task {
                                await startDirectChat()
                            }
                        }) {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("Send Message")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 32)
                }
            }
            .navigationTitle(isOwnProfile ? "My Profile" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isOwnProfile {
                        Button("Edit") {
                            showEditProfile = true
                        }
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .onAppear {
                loadSharedGroups()
            }
        }
    }

    private func loadSharedGroups() {
        guard let currentUserId = authService.currentUser?.id, !isOwnProfile else { return }

        sharedGroups = chatService.conversations.filter { conversation in
            conversation.type == .group &&
            conversation.participantIds.contains(currentUserId) &&
            conversation.participantIds.contains(user.id)
        }
    }

    private func startDirectChat() async {
        guard let currentUserId = authService.currentUser?.id else { return }

        // Check if conversation already exists
        if let existingConversation = chatService.conversations.first(where: { conv in
            conv.type == .direct &&
            conv.participantIds.contains(currentUserId) &&
            conv.participantIds.contains(user.id)
        }) {
            // Navigate to existing conversation
            // This would need NavigationPath or similar in parent view
            dismiss()
            return
        }

        // Create new conversation
        do {
            _ = try await chatService.createOrGetConversation(
                participantIds: [currentUserId, user.id],
                type: .direct
            )
            dismiss()
        } catch {
            print("Error creating conversation: \(error)")
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Group Row

struct GroupRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.purple.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.3.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.groupName ?? "Unnamed Group")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(conversation.participantIds.count) members")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
