//
//  ConversationDetailView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI
import FirebaseDatabase
import PhotosUI

struct ConversationDetailView: View {
    let conversation: Conversation
    let otherUser: User?

    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatService: ChatService
    @StateObject private var audioService = AudioService.shared
    @StateObject private var aiService = AIService.shared

    // Message input
    @State private var messageText = ""
    @State private var isSending = false

    // AI features (Phase B)
    @State private var aiSummary: AISummaryResponse?
    @State private var aiActions: [AIAction] = []
    @State private var isLoadingAI = false
    @State private var aiError: String?

    // UI state
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var shouldAutoScroll = true
    
    // Presence
    @State private var otherUserPresence: (isOnline: Bool, lastSeen: Date?) = (false, nil)
    @State private var presenceListener: DatabaseHandle?
    
    // Message actions
    @State private var selectedMessage: Message?
    @State private var showMessageActions = false
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var editText = ""
    
    // Reactions
    @State private var showReactionPicker = false
    @State private var reactionMessageId: String?
    
    // Media
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingMedia = false
    @State private var uploadProgress: Double = 0

    // Voice Recording
    @State private var showVoiceRecording = false
    @State private var isRecordingVoice = false
    
    // Typing
    @State private var typingListener: DatabaseHandle?
    @State private var typingUsers: [TypingStatus] = []
    @State private var typingTimer: Timer?
    
    @Environment(\.dismiss) private var dismiss

    // Computed property to get current messages
    private var currentMessages: [Message] {
        guard let currentUserId = authService.currentUser?.id else { return [] }
        return (chatService.messages[conversation.id] ?? []).filter { message in
            !message.isDeleted(for: currentUserId)
        }
    }

    // Check if user can send messages
    private var canSendMessage: Bool {
        guard let currentUserId = authService.currentUser?.id else { return false }
        return conversation.canSendMessage(currentUserId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if currentMessages.isEmpty {
                                emptyMessagesView
                            } else {
                            // Load more button
                                if chatService.hasMoreMessages[conversation.id] == true {
                                loadMoreButton
                                }

                                ForEach(currentMessages) { message in
                                    MessageBubbleRow(
                                        message: message,
                                        isFromCurrentUser: message.senderId == authService.currentUser?.id,
                                        conversation: conversation,
                                                currentUserId: authService.currentUser?.id ?? ""
                                            )
                                .id(message.id)
                                .contextMenu {
                                    messageContextMenu(for: message)
                                    }
                                }
                            }
                        }
                        .padding()
                }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: currentMessages.count) { oldValue, newValue in
                        if shouldAutoScroll, newValue > oldValue {
                        scrollToBottom(proxy: proxy)
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
                
            // Typing indicator
            if !typingUsers.isEmpty {
                typingIndicatorView
            }

            // AI Result Card (Phase B)
            if let summary = aiSummary {
                AIResultCard(
                    title: "AI Summary",
                    content: summary.summary,
                    sources: summary.sources
                )
            }

            // AI Actions List (Phase B)
            if !aiActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(aiActions) { action in
                            actionItemCard(action)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 100)
            }

            // AI Bottom Bar (Phase B)
            AIBottomBar(
                onSummarize: { Task { await summarizeTap() } },
                onActions: { Task { await actionsTap() } },
                onDecisions: { showTemporaryMessage("Decisions coming soon") },
                onSearch: { showTemporaryMessage("Search coming soon") },
                onTranslate: { showTemporaryMessage("Translate coming soon") }
            )

            // Message Input
            messageInputView
        }
        .overlay {
            if isLoadingAI {
                ZStack {
                    Color.black.opacity(0.2)
                    ProgressView()
                        .controlSize(.large)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                    Text(navigationTitle)
                            .font(.headline)
                    if conversation.type == .direct, let otherUser = otherUser {
                        Text(presenceText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
        .sheet(isPresented: $showEditSheet) {
            editMessageSheet
        }
        .sheet(isPresented: $showReactionPicker) {
            reactionPickerSheet
        }
        .sheet(isPresented: $showVoiceRecording) {
            voiceRecordingSheet
        }
        .confirmationDialog("Delete Message", isPresented: $showDeleteConfirmation, presenting: selectedMessage) { message in
            Button("Delete for Me", role: .destructive) {
                        Task {
                    await deleteMessage(message, deleteForEveryone: false)
                }
            }
            if message.senderId == authService.currentUser?.id {
                Button("Delete for Everyone", role: .destructive) {
                        Task {
                        await deleteMessage(message, deleteForEveryone: true)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            setupView()
        }
        .onDisappear {
            cleanupView()
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: messageText) { oldValue, newValue in
            handleTyping(newValue: newValue)
        }
    }

    // MARK: - Subviews

    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No messages yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Send a message to start the conversation")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var loadMoreButton: some View {
        Group {
            if chatService.isLoadingMoreMessages[conversation.id] == true {
                ProgressView()
                    .padding()
            } else {
                Button {
                    Task {
                        await chatService.loadOlderMessages(conversationId: conversation.id)
                    }
                } label: {
                    Text("Load Earlier Messages")
                    .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .padding()
            }
        }
    }
    
    private var typingIndicatorView: some View {
                HStack {
            Text(typingText)
                .font(.caption)
                .foregroundStyle(.secondary)
                    Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
    }
    
    private var typingText: String {
        if typingUsers.count == 1, let user = typingUsers.first {
            return "\(user.id) is typing..."
        } else if typingUsers.count > 1 {
            return "\(typingUsers.count) people are typing..."
        }
        return ""
    }

    private var messageInputView: some View {
            HStack(spacing: 12) {
            // Photo picker
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo")
                    .font(.title3)
                        .foregroundStyle(.blue)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await handlePhotoSelection(newItem)
                }
            }
            .disabled(isUploadingMedia)

            // Microphone button (for voice recording)
                    Button(action: {
                        startVoiceRecording()
                    }) {
                            Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .disabled(isUploadingMedia || !messageText.isEmpty)

            // Text Field
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...6)
                .disabled(!canSendMessage)

                    // Send Button
                    Button(action: {
                        Task {
                            await sendMessage()
                        }
                    }) {
                Image(systemName: isUploadingMedia ? "arrow.up.circle" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || !canSendMessage || isUploadingMedia)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            if isUploadingMedia {
                ProgressView(value: uploadProgress)
                    .padding(.horizontal)
            }
        }
    }
    
    private var editMessageSheet: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $editText)
                    .padding()
                    .frame(minHeight: 100)
            }
            .navigationTitle("Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveEditedMessage()
                        }
                    }
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var reactionPickerSheet: some View {
        VStack(spacing: 16) {
            Text("React to message")
                .font(.headline)
                .padding(.top)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                ForEach(["❤️", "👍", "👎", "😂", "😮", "😢", "🎉", "🔥"], id: \.self) { emoji in
                    Button {
                Task {
                            await addReaction(emoji)
                        }
                    } label: {
                        Text(emoji)
                            .font(.system(size: 40))
                    }
                }
            }
            .padding()
        }
        .presentationDetents([.height(200)])
    }

    private var voiceRecordingSheet: some View {
        VoiceRecordingView(
            audioService: audioService,
            isRecording: $isRecordingVoice,
            onSend: { url, duration in
        Task {
                    await sendVoiceMessage(url: url, duration: duration)
                }
            },
            onCancel: {
                showVoiceRecording = false
            }
        )
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.hidden)
    }

    private var navigationTitle: String {
        if conversation.type == .group {
            return conversation.groupName ?? "Group Chat"
        } else if let otherUser = otherUser {
            return otherUser.displayName
        } else {
            return "Chat"
        }
    }

    private var presenceText: String {
        if otherUserPresence.isOnline {
                return "Online"
        } else if let lastSeen = otherUserPresence.lastSeen {
            return formatLastSeen(lastSeen)
            } else {
            return ""
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func messageContextMenu(for message: Message) -> some View {
        if message.senderId == authService.currentUser?.id {
            // Own message
            if message.canEdit(by: authService.currentUser?.id ?? "") {
                Button {
                    selectedMessage = message
                    editText = message.text
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            Button(role: .destructive) {
                selectedMessage = message
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } else {
            // Others' messages
            Button(role: .destructive) {
                selectedMessage = message
        Task {
                    await deleteMessage(message, deleteForEveryone: false)
                }
            } label: {
                Label("Delete for Me", systemImage: "trash")
            }
        }
        
        Button {
            reactionMessageId = message.id
            showReactionPicker = true
        } label: {
            Label("React", systemImage: "face.smiling")
        }
    }

    // MARK: - Actions

    private func sendMessage() async {
        guard let userId = authService.currentUser?.id else { return }
        
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Stop typing indicator
        stopTypingIndicator()
        
        // Clear input immediately
        let textToSend = trimmedText
        messageText = ""
        isSending = true

        do {
            try await chatService.sendMessage(
                conversationId: conversation.id,
                senderId: userId,
                text: textToSend
            )
        } catch {
            print("❌ Error sending message: \(error.localizedDescription)")
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            showErrorAlert = true
            messageText = textToSend
        }
        
        isSending = false
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item,
              let userId = authService.currentUser?.id else { return }

        isUploadingMedia = true
        uploadProgress = 0

            do {
                    guard let imageData = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: imageData) else {
                throw NSError(domain: "ConversationDetailView", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
            }

            try await chatService.sendImageMessage(
                conversationId: conversation.id,
                senderId: userId,
                image: image,
                progressHandler: { progress in
                    Task { @MainActor in
                        uploadProgress = progress
                    }
                }
            )

            await MainActor.run {
                selectedPhotoItem = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to send image: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }

        isUploadingMedia = false
        uploadProgress = 0
    }

    private func startVoiceRecording() {
        Task {
            do {
                _ = try await audioService.startRecording()
                showVoiceRecording = true
                isRecordingVoice = true
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    private func sendVoiceMessage(url: URL, duration: TimeInterval) async {
        guard let userId = authService.currentUser?.id else { return }

        showVoiceRecording = false
        isUploadingMedia = true
        uploadProgress = 0

        do {
            // Read audio data
            let audioData = try await audioService.compressAudio(from: url)

            // Send voice message
            try await chatService.sendVoiceMessage(
                conversationId: conversation.id,
                senderId: userId,
                audioData: audioData,
                duration: duration,
                progressHandler: { progress in
                    Task { @MainActor in
                        uploadProgress = progress
                    }
                }
            )

            print("✅ Voice message sent successfully")
        } catch {
            errorMessage = "Failed to send voice message: \(error.localizedDescription)"
            showErrorAlert = true
        }

        isUploadingMedia = false
        uploadProgress = 0
    }
    
    private func saveEditedMessage() async {
        guard let message = selectedMessage,
              let userId = authService.currentUser?.id else { return }
        
        do {
            try await chatService.editMessage(
                messageId: message.id,
                conversationId: conversation.id,
                newText: editText
            )
            showEditSheet = false
            selectedMessage = nil
        } catch {
            errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }

    private func deleteMessage(_ message: Message, deleteForEveryone: Bool) async {
        do {
            try await chatService.deleteMessage(
                messageId: message.id,
                conversationId: conversation.id,
                deleteForEveryone: deleteForEveryone
            )
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func addReaction(_ emoji: String) async {
        guard let messageId = reactionMessageId,
              let userId = authService.currentUser?.id else { return }
        
        showReactionPicker = false
        
        do {
            try await chatService.addReaction(
                emoji: emoji,
                messageId: messageId,
                conversationId: conversation.id,
                userId: userId
            )
            } catch {
            errorMessage = error.localizedDescription
                    showErrorAlert = true
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessage = currentMessages.last else { return }
        
        if animated {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func markMessagesAsDeliveredAndRead() {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            await chatService.markMessagesAsDelivered(conversationId: conversation.id, userId: userId)
            await chatService.markMessagesAsRead(conversationId: conversation.id, userId: userId)
        }
    }

    // MARK: - Presence

    private func startObservingPresence() {
        guard let userId = otherUser?.id else { return }
        
        presenceListener = PresenceService.shared.observeUserPresence(userId: userId) { isOnline, lastSeen in
                    Task { @MainActor in
                self.otherUserPresence = (isOnline, lastSeen)
            }
        }
    }

    private func stopObservingPresence() {
        if let handle = presenceListener, let userId = otherUser?.id {
            Database.database().reference().child("users").child(userId).removeObserver(withHandle: handle)
        }
        presenceListener = nil
    }
    
    // MARK: - Typing Indicators
    
    private func startObservingTyping() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        typingListener = PresenceService.shared.observeTypingStatus(
            conversationId: conversation.id,
            currentUserId: currentUserId
        ) { statuses in
            Task { @MainActor in
                typingUsers = statuses
            }
        }
    }
    
    private func stopObservingTyping() {
        if let handle = typingListener {
            Database.database().reference()
                .child("conversations")
                .child(conversation.id)
                .child("typing")
                .removeObserver(withHandle: handle)
        }
        typingListener = nil
        stopTypingIndicator()
    }
    
    private func handleTyping(newValue: String) {
        guard let userId = authService.currentUser?.id else { return }
        
        if !newValue.isEmpty {
            // Start typing indicator
            typingTimer?.invalidate()
            
            Task {
                await PresenceService.shared.startTyping(userId: userId, conversationId: conversation.id)
            }
            
            // Auto-stop after 3 seconds
            typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                Task { @MainActor in
                    stopTypingIndicator()
                }
            }
        } else {
            stopTypingIndicator()
        }
    }
    
    private func stopTypingIndicator() {
        guard let userId = authService.currentUser?.id else { return }
        
        typingTimer?.invalidate()
        typingTimer = nil
        
        Task {
            await PresenceService.shared.stopTyping(userId: userId, conversationId: conversation.id)
        }
    }
    
    // MARK: - Lifecycle

    private func setupView() {
        chatService.observeMessages(conversationId: conversation.id)
        markMessagesAsDeliveredAndRead()
        
        if conversation.type == .direct {
            startObservingPresence()
        }
        
        startObservingTyping()
    }
    
    private func cleanupView() {
        chatService.stopObservingMessages(conversationId: conversation.id)
        stopObservingPresence()
        stopObservingTyping()
    }

    private func formatLastSeen(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Message Bubble Row

struct MessageBubbleRow: View {
    let message: Message
    let isFromCurrentUser: Bool
    let conversation: Conversation
    let currentUserId: String
    
    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            HStack {
            if isFromCurrentUser {
                    Spacer()
                    messageBubble
                        .background(Color.blue)
                        .foregroundStyle(.white)
                } else {
                    messageBubble
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }
            
            // Reactions
            if let reactions = message.reactions, !reactions.isEmpty {
                reactionsView(reactions)
            }
        }
    }
    
    private var messageBubble: some View {
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Media content
            if let mediaType = message.mediaType {
                mediaContentView(mediaType)
            }
            
            // Text content
            if !message.text.isEmpty {
                        Text(message.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
            }
            
            // Metadata
            HStack(spacing: 4) {
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                
                                if message.wasEdited {
                                    Text("edited")
                        .font(.caption2)
                        .foregroundStyle(isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                }
                
                if isFromCurrentUser {
                                statusIcon
                            }
                        }
            .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                    }
        .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func mediaContentView(_ mediaType: String) -> some View {
        switch mediaType {
        case "image":
            if let imageURLString = message.thumbnailURL ?? message.mediaURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 250, maxHeight: 250)
                        .clipped()
                        .cornerRadius(12)
                } placeholder: {
                    ProgressView()
                        .frame(width: 200, height: 200)
                }
                .padding(8)
            }
        case "video":
            if let thumbnailURLString = message.thumbnailURL ?? message.mediaURL,
               let thumbnailURL = URL(string: thumbnailURLString) {
                ZStack {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 250, maxHeight: 250)
                            .clipped()
                    } placeholder: {
                        ProgressView()
                    }

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .shadow(radius: 5)
                }
                .frame(width: 200, height: 200)
                .cornerRadius(12)
                .padding(8)
            }
        case "audio":
            AudioMessageView(message: message, isFromCurrentUser: isFromCurrentUser)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        let status = message.displayStatus(for: conversation, currentUserId: currentUserId)
        
        switch status {
        case "sending":
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        case "sent":
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        case "delivered":
            HStack(spacing: 1) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.7))
        case "read":
            HStack(spacing: 1) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundStyle(.blue)
        case "error":
            Image(systemName: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.red)
        default:
            EmptyView()
        }
    }
    
    private func reactionsView(_ reactions: [String: [String]]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(reactions.keys.sorted()), id: \.self) { emoji in
                if let userIds = reactions[emoji], !userIds.isEmpty {
                    HStack(spacing: 2) {
                        Text(emoji)
                            .font(.caption)
                        Text("\(userIds.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - AI Actions (Phase B)

    private func summarizeTap() async {
        isLoadingAI = true
        defer { isLoadingAI = false }

        do {
            print("🤖 Calling AI summarize for conversation: \(conversation.id)")
            let summary = try await aiService.summarize(convId: conversation.id, window: "week", style: "bullets")
            await MainActor.run {
                aiSummary = summary
                aiError = nil
            }
        } catch {
            print("❌ AI summarize error: \(error.localizedDescription)")
            await MainActor.run {
                aiError = error.localizedDescription
                showError(error.localizedDescription)
            }
        }
    }

    private func actionsTap() async {
        isLoadingAI = true
        defer { isLoadingAI = false }

        do {
            print("🤖 Extracting action items for conversation: \(conversation.id)")
            let response = try await aiService.actionItems(convId: conversation.id)
            await MainActor.run {
                aiActions = response.actions
                aiError = nil
            }
        } catch {
            print("❌ AI action items error: \(error.localizedDescription)")
            await MainActor.run {
                aiError = error.localizedDescription
                showError(error.localizedDescription)
            }
        }
    }

    private func actionItemCard(_ action: AIAction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(action.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
            Text("Owner: \(action.ownerId)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Due: \(action.due)")
                .font(.caption2)
                .foregroundStyle(.blue)
        }
        .padding(8)
        .frame(width: 150)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func showTemporaryMessage(_ message: String) {
        showError(message)
    }
}

#Preview {
    NavigationStack {
        ConversationDetailView(
            conversation: Conversation(
                id: "preview",
                type: .direct,
                participantIds: ["user1", "user2"],
                createdAt: Date()
            ),
            otherUser: User(
                id: "user2",
                displayName: "John Doe",
                email: "john@example.com"
            )
        )
        .environmentObject(AuthService.shared)
        .environmentObject(ChatService.shared)
    }
}
