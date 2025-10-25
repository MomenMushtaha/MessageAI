//
//  GroupSettingsView.swift
//  MessageAI
//
//  Created by MessageAI - Phase 4: Group Management
//

import SwiftUI
import PhotosUI

struct GroupSettingsView: View {
    let conversation: Conversation
    let participantUsers: [String: User]

    @EnvironmentObject var chatService: ChatService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var editedGroupName: String
    @State private var editedGroupDescription: String
    @State private var showAddParticipants = false
    @State private var showLeaveConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var groupAvatarImage: UIImage?

    init(conversation: Conversation, participantUsers: [String: User]) {
        self.conversation = conversation
        self.participantUsers = participantUsers
        _editedGroupName = State(initialValue: conversation.groupName ?? "")
        _editedGroupDescription = State(initialValue: conversation.groupDescription ?? "")
    }

    private var isCurrentUserAdmin: Bool {
        guard let currentUserId = authService.currentUser?.id else { return false }
        return conversation.isAdmin(currentUserId)
    }
    
    private var isCurrentUserOwner: Bool {
        guard let currentUserId = authService.currentUser?.id else { return false }
        return conversation.isOwner(currentUserId)
    }

    var body: some View {
        NavigationStack {
            List {
                // Group Info Section
                Section {
                    // Group Avatar
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                            if let groupAvatarImage {
                                Image(uiImage: groupAvatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay {
                                        if isEditing && isCurrentUserAdmin {
                                            Circle()
                                                .fill(Color.black.opacity(0.5))
                                                .overlay {
                                                    Image(systemName: "camera.fill")
                                                        .foregroundStyle(.white)
                                                        .font(.title2)
                                                }
                                        }
                                    }
                            } else if let avatarURL = conversation.groupAvatarURL {
                                AsyncImage(url: URL(string: avatarURL)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    default:
                                        Circle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 100, height: 100)
                                            .overlay {
                                                Image(systemName: "person.3.fill")
                                                    .font(.system(size: 40))
                                                    .foregroundStyle(Color.blue)
                                            }
                                    }
                                }
                                .overlay {
                                    if isEditing && isCurrentUserAdmin {
                                        Circle()
                                            .fill(Color.black.opacity(0.5))
                                            .overlay {
                                                Image(systemName: "camera.fill")
                                                    .foregroundStyle(.white)
                                                    .font(.title2)
                                            }
                                    }
                                }
                            } else {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay {
                                        Image(systemName: "person.3.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(Color.blue)
                                    }
                                    .overlay {
                                        if isEditing && isCurrentUserAdmin {
                                            Circle()
                                                .fill(Color.black.opacity(0.5))
                                                .overlay {
                                                    Image(systemName: "camera.fill")
                                                        .foregroundStyle(.white)
                                                        .font(.title2)
                                                }
                                        }
                                    }
                            }
                        }
                        .disabled(!isEditing || !isCurrentUserAdmin)
                        .onChange(of: selectedAvatarItem) { _, newItem in
                            Task {
                                await handleAvatarSelection(newItem)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    // Group Name
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Group Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Group name", text: $editedGroupName)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Group Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(conversation.groupName ?? "Unnamed Group")
                                .font(.headline)
                        }
                    }

                    // Group Description
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Add a description", text: $editedGroupDescription, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                    } else if let description = conversation.groupDescription, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(description)
                                .font(.body)
                        }
                    }

                    // Created Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(conversation.createdAt, style: .date)
                            .font(.body)
                    }
                }

                // Participants Section
                Section {
                    ForEach(conversation.participantIds, id: \.self) { participantId in
                        ParticipantRow(
                            participantId: participantId,
                            user: participantUsers[participantId],
                            isOwner: conversation.isOwner(participantId),
                            isAdmin: conversation.isAdmin(participantId),
                            isCurrentUserAdmin: isCurrentUserAdmin,
                            isCurrentUser: participantId == authService.currentUser?.id,
                            joinDate: conversation.joinDate(for: participantId),
                            onMakeAdmin: {
                                Task {
                                    await makeAdmin(userId: participantId)
                                }
                            },
                            onRemoveAdmin: {
                                Task {
                                    await removeAdmin(userId: participantId)
                                }
                            },
                            onRemoveParticipant: {
                                Task {
                                    await removeParticipant(userId: participantId)
                                }
                            }
                        )
                    }

                    if isCurrentUserAdmin {
                        Button(action: {
                            showAddParticipants = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Add Participants")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                } header: {
                    Text("\(conversation.participantIds.count) Participants")
                }

                // Settings Section
                Section {
                    Toggle(isOn: Binding(
                        get: {
                            guard let userId = authService.currentUser?.id else { return false }
                            return conversation.participantSettings?[userId]?.isMuted ?? false
                        },
                        set: { newValue in
                            Task {
                                await toggleMute(isMuted: newValue)
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: "bell.slash.fill")
                            Text("Mute Notifications")
                        }
                    }
                } header: {
                    Text("Settings")
                }

                // Group Permissions Section (Admins Only)
                if isCurrentUserAdmin {
                    Section {
                        Toggle(isOn: Binding(
                            get: {
                                conversation.groupPermissions?.onlyAdminsCanMessage ?? false
                            },
                            set: { newValue in
                                Task {
                                    await updatePermission(onlyAdminsCanMessage: newValue)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "lock.fill")
                                    Text("Only Admins Can Send Messages")
                                }
                                Text("When enabled, only admins can send messages to this group")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Toggle(isOn: Binding(
                            get: {
                                conversation.groupPermissions?.onlyAdminsCanAddMembers ?? false
                            },
                            set: { newValue in
                                Task {
                                    await updatePermission(onlyAdminsCanAddMembers: newValue)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("Only Admins Can Add Members")
                                }
                                Text("When enabled, only admins can add new members")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Group Permissions")
                    } footer: {
                        Text("These settings control what non-admin members can do in this group")
                    }
                }

                // Actions Section
                Section {
                    if isCurrentUserAdmin {
                        Button(action: {
                            if isEditing {
                                Task {
                                    await saveGroupInfo()
                                }
                            } else {
                                isEditing = true
                            }
                        }) {
                            HStack {
                                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                                Text(isEditing ? "Save Changes" : "Edit Group Info")
                            }
                        }
                        .disabled(isSaving)

                        if isEditing {
                            Button("Cancel") {
                                isEditing = false
                                editedGroupName = conversation.groupName ?? ""
                                editedGroupDescription = conversation.groupDescription ?? ""
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Show different options based on ownership
                    if isCurrentUserOwner {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete Group")
                            }
                        }
                    } else {
                        Button(role: .destructive) {
                            showLeaveConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Leave Group")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Group Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Leave Group", isPresented: $showLeaveConfirmation) {
                Button("Leave Group", role: .destructive) {
                    Task {
                        await leaveGroup()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to leave this group?")
            }
            .confirmationDialog("Delete Group", isPresented: $showDeleteConfirmation) {
                Button("Delete Group for Everyone", role: .destructive) {
                    Task {
                        await deleteGroup()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete the group and all its messages for everyone. This action cannot be undone.")
            }
            .sheet(isPresented: $showAddParticipants) {
                AddParticipantsView(conversation: conversation)
            }
        }
    }

    // MARK: - Actions

    private func handleAvatarSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData) else {
                await MainActor.run {
                    errorMessage = "Failed to load image"
                    showErrorAlert = true
                }
                return
            }

            await MainActor.run {
                groupAvatarImage = image
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to load image: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    private func saveGroupInfo() async {
        guard let currentUserId = authService.currentUser?.id else { return }

        isSaving = true
        defer {
            isSaving = false
            groupAvatarImage = nil // Clear the edited avatar after save
        }

        do {
            // Update group name and description
            try await chatService.updateGroupInfo(
                conversationId: conversation.id,
                groupName: editedGroupName.isEmpty ? nil : editedGroupName,
                groupDescription: editedGroupDescription.isEmpty ? nil : editedGroupDescription,
                adminId: currentUserId
            )

            // Upload avatar if changed
            if let avatarImage = groupAvatarImage {
                try await chatService.updateGroupAvatar(
                    conversationId: conversation.id,
                    image: avatarImage,
                    adminId: currentUserId
                )
            }

            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func toggleMute(isMuted: Bool) async {
        guard let currentUserId = authService.currentUser?.id else { return }

        do {
            try await chatService.toggleMuteNotifications(
                conversationId: conversation.id,
                userId: currentUserId,
                isMuted: isMuted
            )
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func updatePermission(onlyAdminsCanMessage: Bool? = nil, onlyAdminsCanAddMembers: Bool? = nil) async {
        guard let currentUserId = authService.currentUser?.id else { return }

        do {
            try await chatService.updateGroupPermissions(
                conversationId: conversation.id,
                onlyAdminsCanMessage: onlyAdminsCanMessage,
                onlyAdminsCanAddMembers: onlyAdminsCanAddMembers,
                adminId: currentUserId
            )
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func leaveGroup() async {
        guard let currentUserId = authService.currentUser?.id else { return }

        do {
            try await chatService.leaveGroup(conversationId: conversation.id, userId: currentUserId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func deleteGroup() async {
        guard let currentUserId = authService.currentUser?.id else { return }

        do {
            try await chatService.deleteGroup(conversationId: conversation.id, userId: currentUserId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func makeAdmin(userId: String) async {
        guard let currentUserId = authService.currentUser?.id else { return }

        do {
            try await chatService.makeAdmin(
                conversationId: conversation.id,
                userId: userId,
                currentAdminId: currentUserId
            )
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func removeAdmin(userId: String) async {
        guard let currentUserId = authService.currentUser?.id else { return }

        do {
            try await chatService.removeAdmin(
                conversationId: conversation.id,
                userId: userId,
                currentAdminId: currentUserId
            )
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func removeParticipant(userId: String) async {
        guard let currentUserId = authService.currentUser?.id else { return }

        do {
            try await chatService.removeParticipant(
                conversationId: conversation.id,
                userId: userId,
                adminId: currentUserId
            )
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - Participant Row

struct ParticipantRow: View {
    let participantId: String
    let user: User?
    let isOwner: Bool
    let isAdmin: Bool
    let isCurrentUserAdmin: Bool
    let isCurrentUser: Bool
    let joinDate: Date?
    let onMakeAdmin: () -> Void
    let onRemoveAdmin: () -> Void
    let onRemoveParticipant: () -> Void

    @State private var showActions = false

    var body: some View {
        Button(action: {
            // Only show actions if current user is admin and this is not the current user or the owner
            if isCurrentUserAdmin && !isCurrentUser && !isOwner {
                showActions = true
            }
        }) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay {
                        if let user = user {
                            Text(user.initials)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        } else {
                            ProgressView()
                                .tint(.white)
                        }
                    }

                // User Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(user?.displayName ?? "Loading...")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if isCurrentUser {
                            Text("(You)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(user?.email ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if isOwner {
                            Text("• Owner")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        } else if isAdmin {
                            Text("• Admin")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }

                    if let joinDate = joinDate {
                        Text("Joined \(joinDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isCurrentUserAdmin && !isCurrentUser && !isOwner {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog("Manage Participant", isPresented: $showActions) {
            // Owners cannot be made/removed as admin or removed from group
            if !isOwner {
                if !isAdmin {
                    Button("Make Admin") {
                        onMakeAdmin()
                    }
                } else {
                    Button("Remove Admin Status") {
                        onRemoveAdmin()
                    }
                }

                Button("Remove from Group", role: .destructive) {
                    onRemoveParticipant()
                }
            }

            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Add Participants View

struct AddParticipantsView: View {
    let conversation: Conversation

    @EnvironmentObject var chatService: ChatService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedUserIds: Set<String> = []
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private var availableUsers: [User] {
        chatService.allUsers.filter { user in
            !conversation.participantIds.contains(user.id) &&
            user.id != authService.currentUser?.id
        }
    }

    private var filteredUsers: [User] {
        if searchText.isEmpty {
            return availableUsers
        }
        return availableUsers.filter { user in
            user.displayName.localizedCaseInsensitiveContains(searchText) ||
            user.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading users...")
                        .padding()
                } else if availableUsers.isEmpty {
                    ContentUnavailableView(
                        "No Users Available",
                        systemImage: "person.slash",
                        description: Text("All users are already in this group")
                    )
                } else {
                    List(filteredUsers) { user in
                        Button(action: {
                            if selectedUserIds.contains(user.id) {
                                selectedUserIds.remove(user.id)
                            } else {
                                selectedUserIds.insert(user.id)
                            }
                        }) {
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

                                Spacer()

                                if selectedUserIds.contains(user.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .searchable(text: $searchText, prompt: "Search users")
                }
            }
            .navigationTitle("Add Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            await addSelectedUsers()
                        }
                    }
                    .disabled(selectedUserIds.isEmpty)
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                Task {
                    await loadUsers()
                }
            }
        }
    }

    private func loadUsers() async {
        guard let currentUserId = authService.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        await chatService.fetchAllUsers(excludingUserId: currentUserId)
    }

    private func addSelectedUsers() async {
        guard let currentUserId = authService.currentUser?.id else { return }

        do {
            try await chatService.addParticipants(
                conversationId: conversation.id,
                userIds: Array(selectedUserIds),
                adminId: currentUserId
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
