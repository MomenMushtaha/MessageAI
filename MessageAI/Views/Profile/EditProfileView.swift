//
//  EditProfileView.swift
//  MessageAI
//
//  Created by MessageAI - Phase 6: Advanced Features
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var bio: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showReadReceipts: Bool
    @State private var showOnlineStatus: Bool
    @State private var showLastSeen: Bool

    init() {
        // Initialize with current user values
        let currentUser = AuthService.shared.currentUser
        _displayName = State(initialValue: currentUser?.displayName ?? "")
        _bio = State(initialValue: currentUser?.bio ?? "")
        _showReadReceipts = State(initialValue: currentUser?.showsReadReceipts ?? true)
        _showOnlineStatus = State(initialValue: currentUser?.showsOnlineStatus ?? true)
        _showLastSeen = State(initialValue: currentUser?.showsLastSeen ?? true)
    }

    var hasChanges: Bool {
        displayName != authService.currentUser?.displayName ||
        bio != (authService.currentUser?.bio ?? "") ||
        showReadReceipts != authService.currentUser?.showsReadReceipts ||
        showOnlineStatus != authService.currentUser?.showsOnlineStatus ||
        showLastSeen != authService.currentUser?.showsLastSeen
    }

    var body: some View {
        NavigationStack {
            Form {
                // Avatar Section
                Section {
                    HStack {
                        Spacer()

                        VStack(spacing: 16) {
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 100, height: 100)
                                .overlay {
                                    Text(authService.currentUser?.initials ?? "")
                                        .font(.system(size: 40, weight: .medium))
                                        .foregroundStyle(.white)
                                }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text("Change Photo")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                            .onChange(of: selectedPhotoItem) { _, _ in
                                // Photo upload would be implemented here
                                // Currently blocked by Firebase Storage setup
                            }
                        }

                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Profile Information
                Section("Profile Information") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)

                    TextField("Email", text: .constant(authService.currentUser?.email ?? ""))
                        .disabled(true)
                        .foregroundStyle(.secondary)
                }

                // Bio Section
                Section("Bio") {
                    TextField("Tell us about yourself", text: $bio, axis: .vertical)
                        .lineLimit(4...8)
                }

                // Privacy Section
                Section {
                    Toggle(isOn: $showReadReceipts) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Read Receipts")
                            Text("Let others see when you've read their messages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $showOnlineStatus) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Online Status")
                            Text("Let others see when you're online")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $showLastSeen) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Seen")
                            Text("Let others see when you were last online")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("These settings control what information others can see about you")
                }

                // Account Section
                Section("Account") {
                    HStack {
                        Text("User ID")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(authService.currentUser?.id ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Member Since")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let createdAt = authService.currentUser?.createdAt {
                            Text(createdAt, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(!hasChanges || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveProfile() async {
        guard let userId = authService.currentUser?.id else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            // Update profile info
            try await authService.updateProfile(
                userId: userId,
                displayName: displayName.isEmpty ? nil : displayName,
                bio: bio.isEmpty ? nil : bio
            )

            // Update privacy settings if changed
            let currentUser = authService.currentUser
            if showReadReceipts != currentUser?.showsReadReceipts ||
               showOnlineStatus != currentUser?.showsOnlineStatus ||
               showLastSeen != currentUser?.showsLastSeen {
                try await authService.updatePrivacySettings(
                    userId: userId,
                    showReadReceipts: showReadReceipts,
                    showOnlineStatus: showOnlineStatus,
                    showLastSeen: showLastSeen
                )
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
