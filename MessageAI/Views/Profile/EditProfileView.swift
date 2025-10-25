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
    @State private var selectedAvatarImage: UIImage?
    @State private var isSaving = false
    @State private var isUploadingAvatar = false
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
                            // Avatar display
                            ZStack {
                                if let selectedImage = selectedAvatarImage {
                                    // Show newly selected image
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else if let avatarURL = authService.currentUser?.avatarURL,
                                          !avatarURL.isEmpty {
                                    // Show existing avatar from URL
                                    AsyncImage(url: URL(string: avatarURL)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        case .failure(_), .empty:
                                            // Fallback to initials
                                            Circle()
                                                .fill(Color.blue.gradient)
                                                .frame(width: 100, height: 100)
                                                .overlay {
                                                    Text(authService.currentUser?.initials ?? "")
                                                        .font(.system(size: 40, weight: .medium))
                                                        .foregroundStyle(.white)
                                                }
                                        @unknown default:
                                            Circle()
                                                .fill(Color.blue.gradient)
                                                .frame(width: 100, height: 100)
                                        }
                                    }
                                } else {
                                    // Show initials
                                    Circle()
                                        .fill(Color.blue.gradient)
                                        .frame(width: 100, height: 100)
                                        .overlay {
                                            Text(authService.currentUser?.initials ?? "")
                                                .font(.system(size: 40, weight: .medium))
                                                .foregroundStyle(.white)
                                        }
                                }

                                // Loading overlay
                                if isUploadingAvatar {
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 100, height: 100)
                                        .overlay {
                                            ProgressView()
                                                .tint(.white)
                                        }
                                }
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text(isUploadingAvatar ? "Uploading..." : "Change Photo")
                                    .font(.subheadline)
                                    .foregroundStyle(isUploadingAvatar ? .gray : .blue)
                            }
                            .disabled(isUploadingAvatar)
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                Task {
                                    await handleAvatarSelection(newItem)
                                }
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

    private func handleAvatarSelection(_ item: PhotosPickerItem?) async {
        guard let item = item, let userId = authService.currentUser?.id else { return }

        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        do {
            // Load the image data from the photo picker
            guard let imageData = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: imageData) else {
                await MainActor.run {
                    errorMessage = "Failed to load image"
                    showErrorAlert = true
                }
                return
            }

            // Show the selected image immediately for preview
            await MainActor.run {
                selectedAvatarImage = image
            }

            // Upload the avatar to S3 and update user profile
            try await authService.updateUserAvatar(userId: userId, image: image)

            print("✅ Profile photo updated successfully")
        } catch {
            await MainActor.run {
                errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                showErrorAlert = true
                selectedAvatarImage = nil // Clear the preview on error
            }
        }
    }
}
