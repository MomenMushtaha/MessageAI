//
//  ConversationDetailView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI
import FirebaseFirestore
import PhotosUI

struct ConversationDetailView: View {
    let conversation: Conversation
    let otherUser: User?

    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatService: ChatService
    @State private var messageText = ""
    @State private var isSending = false
    @State private var selectedPhotoItem: PhotosPickerItem? // Selected photo from picker
    @State private var isUploadingImage = false // Image upload in progress
    @State private var uploadProgress: Double = 0.0 // Upload progress (0.0 to 1.0)
    @State private var participantUsers: [String: User] = [:] // userId -> User cache
    @State private var showParticipantList = false
    @State private var otherUserPresence: (isOnline: Bool, lastSeen: Date?) = (false, nil)
    @State private var presenceListener: ListenerRegistration?
    @State private var showScrollToBottom = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showClearHistoryAlert = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var shouldAutoScroll = true
    @State private var messageStatusCache: [String: String] = [:] // messageId -> status for performance
    @State private var selectedMessage: Message? // For message actions
    @State private var showMessageActions = false // Show action sheet
    @State private var isEditMode = false // Edit mode active
    @State private var editingMessageId: String? // ID of message being edited
    @State private var editingText = "" // Text being edited
    @State private var isSearching = false // Search mode active
    @State private var searchText = "" // Search query
    @State private var searchResults: [Message] = [] // Filtered search results
    @State private var currentSearchIndex = 0 // Current result index for navigation
    @State private var searchDebounceTask: Task<Void, Never>? // Debounce task for search
    @State private var typingUsers: [TypingStatus] = [] // Users currently typing
    @State private var typingListener: ListenerRegistration? // Typing status listener
    @State private var typingTimer: Timer? // Auto-stop typing timer
    @State private var isCurrentUserTyping = false // Track if current user is typing
    @State private var showReactionPicker = false // Show reaction picker
    @State private var reactionPickerMessageId: String? // Message to react to
    @State private var reactionPickerPosition: CGPoint = .zero // Position for reaction picker
    @State private var showForwardSheet = false // Show forward message sheet
    @State private var messageToForward: Message? // Message to forward
    @State private var showFullScreenImage = false // Show full-screen image viewer
    @State private var fullScreenImageMessage: Message? // Message for full-screen image
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar (appears when searching)
            if isSearching {
                searchBar
            }

            // Messages List
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if currentMessages.isEmpty {
                                emptyMessagesView
                            } else {
                                ForEach(currentMessages) { message in
                                    MessageBubbleRow(
                                        message: message,
                                        isFromCurrentUser: message.senderId == authService.currentUser?.id,
                                        senderName: participantUsers[message.senderId]?.displayName,
                                        conversation: conversation,
                                        currentUserId: authService.currentUser?.id ?? "",
                                        statusCache: $messageStatusCache,
                                        searchQuery: isSearching ? searchText : nil,
                                        isSearchResult: isSearching && searchResults.contains(where: { $0.id == message.id }),
                                        onReactionTap: {
                                            reactionPickerMessageId = message.id
                                            showReactionPicker = true
                                        },
                                        onImageTap: {
                                            fullScreenImageMessage = message
                                            showFullScreenImage = true
                                        }
                                    )
                                    .id(message.id)
                                    .onAppear {
                                        // Precompute and cache status for smooth scrolling
                                        if messageStatusCache[message.id] == nil {
                                            messageStatusCache[message.id] = message.displayStatus(
                                                for: conversation,
                                                currentUserId: authService.currentUser?.id ?? ""
                                            )
                                        }
                                    }
                                    .onLongPressGesture {
                                        // Show message actions sheet
                                        selectedMessage = message
                                        showMessageActions = true

                                        // Haptic feedback
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                        })
                    }
                    .coordinateSpace(name: "scroll")
                    .scrollDismissesKeyboard(.interactively)
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        // Show scroll-to-bottom button when scrolled up
                        let threshold: CGFloat = -100
                        showScrollToBottom = offset < threshold
                    }
                    .onChange(of: currentMessages.count) { oldValue, newValue in
                        // Only auto-scroll if user is at bottom or it's their own message
                        if shouldAutoScroll, newValue > oldValue {
                            scrollToBottomAnimated(proxy: proxy)
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
                
                // Scroll to Bottom Button
                if showScrollToBottom {
                    Button(action: {
                        if let proxy = scrollProxy {
                            scrollToBottomAnimated(proxy: proxy)
                            shouldAutoScroll = true
                        }
                    }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white, .blue)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            // Edit Mode Bar (appears when editing)
            if isEditMode {
                editMessageBar
            }

            // Message Input
            messageInputView
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    if conversation.type == .group {
                        showParticipantList = true
                    }
                }) {
                    VStack(spacing: 2) {
                        Text(displayTitle)
                            .font(.headline)
                        
                        if conversation.type == .direct {
                            HStack(spacing: 4) {
                                if otherUserPresence.isOnline {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                }
                                Text(presenceStatusText)
                                    .font(.caption)
                                    .foregroundStyle(otherUserPresence.isOnline ? .green : .secondary)
                            }
                        } else {
                            Text("\(conversation.participantIds.count) participants")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Search button
                    Button(action: {
                        isSearching.toggle()
                        if !isSearching {
                            // Clear search when closing
                            searchText = ""
                            searchResults = []
                            currentSearchIndex = 0
                        }
                    }) {
                        Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                            .foregroundStyle(.blue)
                    }

                    // Menu
                    Menu {
                        Button(role: .destructive, action: {
                            showClearHistoryAlert = true
                        }) {
                            Label("Clear Chat History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showParticipantList) {
            ParticipantListView(
                participantIds: conversation.participantIds,
                participantUsers: participantUsers
            )
        }
        .sheet(isPresented: $showForwardSheet) {
            if let message = messageToForward {
                ForwardMessageView(
                    message: message,
                    onForward: { conversationIds in
                        Task {
                            await handleForwardMessage(message: message, to: conversationIds)
                        }
                    },
                    onDismiss: {
                        showForwardSheet = false
                        messageToForward = nil
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let message = fullScreenImageMessage {
                FullScreenImageView(
                    message: message,
                    onDismiss: {
                        showFullScreenImage = false
                        fullScreenImageMessage = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showMessageActions) {
            if let message = selectedMessage,
               let userId = authService.currentUser?.id {
                MessageActionsSheet(
                    message: message,
                    currentUserId: userId,
                    onEdit: {
                        // Enter edit mode
                        editingMessageId = message.id
                        editingText = message.text
                        isEditMode = true
                        showMessageActions = false
                    },
                    onDelete: { deleteForEveryone in
                        Task {
                            do {
                                try await chatService.deleteMessage(
                                    messageId: message.id,
                                    conversationId: conversation.id,
                                    deleteForEveryone: deleteForEveryone
                                )
                                print("✅ Message deleted successfully")
                            } catch {
                                print("❌ Failed to delete message: \(error.localizedDescription)")
                                errorMessage = error.localizedDescription
                                showErrorAlert = true
                            }
                        }
                        showMessageActions = false
                    },
                    onForward: {
                        // Show forward sheet
                        messageToForward = message
                        showMessageActions = false
                        showForwardSheet = true
                    },
                    onDismiss: {
                        showMessageActions = false
                    }
                )
            }
        }
        .onAppear {
            // Load participant users first (especially important for new groups)
            loadParticipantUsers()

            // Then start observing messages
            chatService.observeMessages(conversationId: conversation.id)
            markMessagesAsDeliveredAndRead()
            startObservingPresence()
            startObservingTyping()

            // Track current conversation for notifications
            NotificationService.shared.setCurrentConversation(conversation.id)
        }
        .onDisappear {
            chatService.stopObservingMessages(conversationId: conversation.id)
            stopObservingPresence()
            stopObservingTyping()

            // Clear current conversation
            NotificationService.shared.setCurrentConversation(nil)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Clear Chat History?", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task {
                    await clearChatHistory()
                }
            }
        } message: {
            Text("This will delete all messages from this chat on your device only. Other participants will still see the messages.")
        }
        .overlay(reactionPickerOverlay)
    }
    
    @ViewBuilder
    private var reactionPickerOverlay: some View {
        if showReactionPicker {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    showReactionPicker = false
                }

            VStack {
                Spacer()
                ReactionPickerView(
                    onReactionSelected: { emoji in
                        handleReactionSelected(emoji)
                    },
                    onDismiss: {
                        showReactionPicker = false
                    }
                )
                .padding(.bottom, 100)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            if participantUsers.isEmpty && conversation.type == .group {
                // Loading state for new groups
                ProgressView()
                    .padding()
                Text("Loading group...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: conversation.type == .group ? "person.3.fill" : "message.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text(conversation.type == .group ? "Group created!" : "No messages yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Start a conversation!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private var messageInputView: some View {
        VStack(spacing: 4) {
            // Typing indicator
            TypingIndicatorView(typingUsers: typingUsers, participantUsers: participantUsers)

            // Character count warning (only show when approaching limit)
            if messageText.count > 3500 {
                HStack {
                    Spacer()
                    Text("\(messageText.count) / 4096")
                        .font(.caption2)
                        .foregroundStyle(messageText.count > 4096 ? .red : .secondary)
                        .padding(.trailing, 16)
                }
            }
            
            HStack(spacing: 12) {
                // Photo Picker Button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                }
                .disabled(isUploadingImage || isSending)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    handlePhotoSelection(newItem)
                }

                // Text Field
                HStack {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .font(.body)
                        .onChange(of: messageText) { oldValue, newValue in
                            handleTypingChange(oldValue: oldValue, newValue: newValue)
                        }
                }
                .background(Color(.systemGray6))
                .cornerRadius(24)
            
            // Send Button
            Button(action: {
                Task {
                    await sendMessage()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(messageText.isEmpty ? Color(.systemGray4) : Color.blue)
                        .frame(width: 38, height: 38)
                    
                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
                .disabled(messageText.isEmpty || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
        )
    }

    private var editMessageBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Cancel button
                Button(action: {
                    isEditMode = false
                    editingMessageId = nil
                    editingText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }

                // Text field
                TextField("Edit message", text: $editingText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // Save button
                Button(action: {
                    saveEditedMessage()
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            // Search text field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                TextField("Search messages", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { oldValue, newValue in
                        performSearchDebounced()
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        currentSearchIndex = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            // Navigation buttons and result count
            if !searchResults.isEmpty {
                HStack(spacing: 8) {
                    // Result count
                    Text("\(currentSearchIndex + 1) of \(searchResults.count)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    // Previous result
                    Button(action: navigateToPreviousResult) {
                        Image(systemName: "chevron.up")
                            .foregroundColor(currentSearchIndex > 0 ? .blue : .secondary)
                            .font(.system(size: 14))
                    }
                    .disabled(currentSearchIndex == 0)

                    // Next result
                    Button(action: navigateToNextResult) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(currentSearchIndex < searchResults.count - 1 ? .blue : .secondary)
                            .font(.system(size: 14))
                    }
                    .disabled(currentSearchIndex >= searchResults.count - 1)
                }
            }

            // Done button to exit search
            Button(action: clearSearch) {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func performSearchDebounced() {
        // Cancel any existing search task
        searchDebounceTask?.cancel()

        // Create new debounced search task
        searchDebounceTask = Task {
            // Wait for 300ms debounce
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Perform the actual search
            await MainActor.run {
                performSearch()
            }
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            currentSearchIndex = 0
            return
        }

        // Search messages using ChatService
        searchResults = chatService.searchMessages(
            conversationId: conversation.id,
            query: searchText
        )

        // Reset to first result
        currentSearchIndex = 0

        // Scroll to first result if results exist
        if !searchResults.isEmpty {
            scrollToCurrentSearchResult()
        }

        print("🔍 Search updated: \(searchResults.count) results for '\(searchText)'")
    }

    private func navigateToNextResult() {
        guard !searchResults.isEmpty, currentSearchIndex < searchResults.count - 1 else {
            return
        }
        currentSearchIndex += 1
        scrollToCurrentSearchResult()
        print("🔍 Navigate to result \(currentSearchIndex + 1) of \(searchResults.count)")
    }

    private func navigateToPreviousResult() {
        guard !searchResults.isEmpty, currentSearchIndex > 0 else {
            return
        }
        currentSearchIndex -= 1
        scrollToCurrentSearchResult()
        print("🔍 Navigate to result \(currentSearchIndex + 1) of \(searchResults.count)")
    }

    private func scrollToCurrentSearchResult() {
        guard !searchResults.isEmpty, currentSearchIndex < searchResults.count,
              let proxy = scrollProxy else {
            return
        }

        let targetMessage = searchResults[currentSearchIndex]
        withAnimation {
            proxy.scrollTo(targetMessage.id, anchor: .center)
        }
        print("🔍 Scrolling to message: \(targetMessage.id)")
    }

    private func clearSearch() {
        searchDebounceTask?.cancel()
        searchText = ""
        searchResults = []
        currentSearchIndex = 0
        isSearching = false
        print("🔍 Search cleared")
    }

    // MARK: - Typing Indicators

    private func handleTypingChange(oldValue: String, newValue: String) {
        guard let userId = authService.currentUser?.id else { return }

        // User started typing (went from empty to non-empty, or changed text)
        if !newValue.isEmpty && oldValue != newValue {
            if !isCurrentUserTyping {
                isCurrentUserTyping = true
                Task {
                    await PresenceService.shared.startTyping(userId: userId, conversationId: conversation.id)
                }
            }

            // Reset the auto-stop timer
            resetTypingTimer(userId: userId)
        }
        // User cleared text
        else if newValue.isEmpty && isCurrentUserTyping {
            stopTypingIndicator(userId: userId)
        }
    }

    private func resetTypingTimer(userId: String) {
        // Cancel existing timer
        typingTimer?.invalidate()

        // Start new 3-second timer
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            Task { @MainActor in
                await PresenceService.shared.stopTyping(userId: userId, conversationId: self.conversation.id)
            }
        }
    }

    private func stopTypingIndicator(userId: String) {
        isCurrentUserTyping = false
        typingTimer?.invalidate()
        typingTimer = nil

        Task {
            await PresenceService.shared.stopTyping(userId: userId, conversationId: conversation.id)
        }
    }

    // MARK: - Reactions

    private func handleReactionSelected(_ emoji: String) {
        guard let messageId = reactionPickerMessageId,
              let userId = authService.currentUser?.id else {
            return
        }

        showReactionPicker = false
        reactionPickerMessageId = nil

        Task {
            do {
                try await chatService.addReaction(
                    emoji: emoji,
                    messageId: messageId,
                    conversationId: conversation.id,
                    userId: userId
                )
                print("✅ Reaction \(emoji) added to message")
            } catch {
                print("❌ Error adding reaction: \(error.localizedDescription)")
                errorMessage = "Failed to add reaction"
                showErrorAlert = true
            }
        }
    }

    // MARK: - Message Forwarding

    private func handleForwardMessage(message: Message, to conversationIds: [String]) async {
        guard let userId = authService.currentUser?.id else { return }

        do {
            try await chatService.forwardMessage(
                message: message,
                to: conversationIds,
                from: userId
            )
            print("✅ Message forwarded to \(conversationIds.count) conversation(s)")
        } catch {
            print("❌ Error forwarding message: \(error.localizedDescription)")
            errorMessage = "Failed to forward message"
            showErrorAlert = true
        }
    }

    private func saveEditedMessage() {
        guard let messageId = editingMessageId else {
            print("❌ No message ID to edit")
            return
        }

        Task {
            do {
                try await chatService.editMessage(
                    messageId: messageId,
                    conversationId: conversation.id,
                    newText: editingText
                )

                // Exit edit mode
                isEditMode = false
                editingMessageId = nil
                editingText = ""

                print("✅ Message edited successfully")
            } catch {
                print("❌ Failed to edit message: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private var currentMessages: [Message] {
        guard let currentUserId = authService.currentUser?.id else {
            return chatService.messages[conversation.id] ?? []
        }

        // Filter out messages deleted by current user
        return (chatService.messages[conversation.id] ?? []).filter { message in
            !message.isDeleted(for: currentUserId)
        }
    }
    
    private var displayTitle: String {
        if conversation.type == .group {
            return conversation.groupName ?? "Group Chat"
        } else {
            return otherUser?.displayName ?? "Chat"
        }
    }
    
    private var presenceStatusText: String {
        if conversation.type != .direct {
            return ""
        }
        
        if otherUserPresence.isOnline {
            return "Online"
        }
        
        guard let lastSeen = otherUserPresence.lastSeen else {
            return "Last seen recently"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastSeen)
        
        if timeInterval < 60 {
            return "Last seen just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "Last seen \(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "Last seen \(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "Last seen \(days)d ago"
        }
    }
    
    private func loadParticipantUsers() {
        Task {
            // Load all participant users upfront (important for group chats)
            await MainActor.run {
                print("📥 Loading \(conversation.participantIds.count) participant users...")
            }
            
            for participantId in conversation.participantIds {
                if participantUsers[participantId] == nil {
                    if let user = try? await chatService.getUser(userId: participantId) {
                        await MainActor.run {
                            participantUsers[participantId] = user
                            print("✅ Loaded user: \(user.displayName)")
                        }
                    }
                }
            }
            
            await MainActor.run {
                print("✅ All \(participantUsers.count) participant users loaded")
            }
        }
    }
    
    private func markMessagesAsDeliveredAndRead() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            // First mark as delivered
            await chatService.markMessagesAsDelivered(conversationId: conversation.id, userId: currentUserId)
            
            // Then mark as read (since user is viewing the conversation)
            await chatService.markMessagesAsRead(conversationId: conversation.id, userId: currentUserId)
        }
    }
    
    private func startObservingPresence() {
        // Only observe presence for direct conversations
        guard conversation.type == .direct,
              let otherUserId = conversation.participantIds.first(where: { $0 != authService.currentUser?.id }) else {
            return
        }
        
        presenceListener = PresenceService.shared.observeUserPresence(userId: otherUserId) { isOnline, lastSeen in
            Task { @MainActor in
                self.otherUserPresence = (isOnline, lastSeen)
            }
        }
    }
    
    private func stopObservingPresence() {
        presenceListener?.remove()
        presenceListener = nil
    }

    private func startObservingTyping() {
        guard let currentUserId = authService.currentUser?.id else { return }

        typingListener = PresenceService.shared.observeTypingStatus(
            conversationId: conversation.id,
            currentUserId: currentUserId
        ) { statuses in
            Task { @MainActor in
                self.typingUsers = statuses
            }
        }
        print("⌨️ Started observing typing for conversation: \(conversation.id)")
    }

    private func stopObservingTyping() {
        typingListener?.remove()
        typingListener = nil

        // Also stop our own typing indicator if active
        if isCurrentUserTyping, let userId = authService.currentUser?.id {
            stopTypingIndicator(userId: userId)
        }
        print("⌨️ Stopped observing typing")
    }

    private func sendMessage() async {
        guard let currentUserId = authService.currentUser?.id else {
            return
        }
        
        let textToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate before sending
        guard !textToSend.isEmpty else {
            errorMessage = "Please enter a message"
            showErrorAlert = true
            return
        }
        
        guard textToSend.count <= 4096 else {
            errorMessage = "Message is too long (max 4096 characters)"
            showErrorAlert = true
            return
        }
        
        messageText = ""
        isSending = true

        // Stop typing indicator when sending
        if isCurrentUserTyping {
            stopTypingIndicator(userId: currentUserId)
        }

        // Ensure auto-scroll for user's own messages
        shouldAutoScroll = true

        do {
            try await chatService.sendMessage(
                conversationId: conversation.id,
                senderId: currentUserId,
                text: textToSend
            )
            
            // Scroll to bottom after sending
            if let proxy = scrollProxy {
                scrollToBottomAnimated(proxy: proxy)
            }
        } catch {
            print("❌ Error sending message: \(error.localizedDescription)")
            // Show error to user
            errorMessage = error.localizedDescription
            showErrorAlert = true
            // Restore message text on error
            messageText = textToSend
        }
        
        isSending = false
    }

    // MARK: - Photo Handling

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            do {
                // Load the image data
                guard let imageData = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: imageData) else {
                    await MainActor.run {
                        errorMessage = "Failed to load image"
                        showErrorAlert = true
                    }
                    return
                }

                await sendImageMessage(image: image)

            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load image: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }

            // Clear selection after processing
            await MainActor.run {
                selectedPhotoItem = nil
            }
        }
    }

    private func sendImageMessage(image: UIImage) async {
        guard let currentUserId = authService.currentUser?.id else {
            return
        }

        isUploadingImage = true
        uploadProgress = 0.0

        // Stop typing indicator when sending image
        if isCurrentUserTyping {
            stopTypingIndicator(userId: currentUserId)
        }

        // Ensure auto-scroll for user's own messages
        shouldAutoScroll = true

        do {
            try await chatService.sendImageMessage(
                conversationId: conversation.id,
                senderId: currentUserId,
                image: image,
                progressHandler: { progress in
                    Task { @MainActor in
                        self.uploadProgress = progress
                    }
                }
            )

            // Scroll to bottom after sending
            if let proxy = scrollProxy {
                scrollToBottomAnimated(proxy: proxy)
            }

            print("✅ Image message sent successfully")

        } catch {
            print("❌ Error sending image message: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to send image: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }

        isUploadingImage = false
        uploadProgress = 0.0
    }

    // MARK: - Scroll Helpers
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessage = currentMessages.last else { return }
        
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    private func scrollToBottomAnimated(proxy: ScrollViewProxy) {
        scrollToBottom(proxy: proxy, animated: true)
    }
    
    private func clearChatHistory() async {
        do {
            try await chatService.clearChatHistory(conversationId: conversation.id)
            print("✅ Chat history cleared successfully")
        } catch {
            print("❌ Error clearing chat history: \(error.localizedDescription)")
            errorMessage = "Failed to clear chat history: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

struct MessageBubbleRow: View, Equatable {
    let message: Message
    let isFromCurrentUser: Bool
    let senderName: String?
    let conversation: Conversation
    let currentUserId: String
    @Binding var statusCache: [String: String]
    let searchQuery: String?
    let isSearchResult: Bool
    let onReactionTap: () -> Void
    let onImageTap: () -> Void

    // Equatable conformance for performance optimization
    static func == (lhs: MessageBubbleRow, rhs: MessageBubbleRow) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.status == rhs.message.status &&
        lhs.message.text == rhs.message.text &&
        lhs.senderName == rhs.senderName &&
        lhs.statusCache[lhs.message.id] == rhs.statusCache[rhs.message.id] &&
        lhs.searchQuery == rhs.searchQuery &&
        lhs.isSearchResult == rhs.isSearchResult
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Show sender name for group chats (incoming messages only)
                if !isFromCurrentUser, let senderName = senderName {
                    Text(senderName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.blue)
                        .padding(.leading, 12)
                        .padding(.top, 2)
                }
                
                // Message bubble
                HStack(alignment: .bottom, spacing: 4) {
                    // Check if this is an image message
                    if message.mediaType == "image" {
                        ImageMessageView(
                            message: message,
                            isFromCurrentUser: isFromCurrentUser,
                            onTap: onImageTap
                        )
                        .onTapGesture(count: 2) {
                            onReactionTap()
                        }
                    } else {
                        Text(message.text)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                bubbleBackground
                            )
                            .foregroundStyle(isSearchResult && isFromCurrentUser ? .black : (isFromCurrentUser ? .white : .primary))
                            .clipShape(BubbleShape(isFromCurrentUser: isFromCurrentUser))
                            .onTapGesture(count: 2) {
                                onReactionTap()
                            }
                    }
                    
                    // Timestamp and status in the corner
                    if isFromCurrentUser {
                        VStack(alignment: .trailing, spacing: 2) {
                            Spacer()
                            HStack(spacing: 2) {
                                if message.wasEdited {
                                    Text("edited")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text("•")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Text(message.createdAt, style: .time)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                statusIcon
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
                
                // Timestamp for incoming messages
                if !isFromCurrentUser {
                    HStack(spacing: 4) {
                        if message.wasEdited {
                            Text("edited")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Text(message.createdAt, style: .time)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 12)
                }

                // Reactions display
                if let reactions = message.reactions, !reactions.isEmpty {
                    reactionsView(reactions: reactions)
                        .padding(isFromCurrentUser ? .trailing : .leading, 12)
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if isSearchResult {
                // Highlight search results with yellow tint
                if isFromCurrentUser {
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.7), Color.orange.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.yellow.opacity(0.3)
                }
            } else if isFromCurrentUser {
                // Use cached status for performance
                let displayStatus = statusCache[message.id] ?? message.displayStatus(for: conversation, currentUserId: currentUserId)
                if displayStatus == "error" {
                    LinearGradient(
                        colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                Color(.systemGray5)
            }
        }
    }
    
    @ViewBuilder
    private func reactionsView(reactions: [String: [String]]) -> some View {
        HStack(spacing: 4) {
            ForEach(reactions.keys.sorted(), id: \.self) { emoji in
                if let userIds = reactions[emoji], !userIds.isEmpty {
                    HStack(spacing: 2) {
                        Text(emoji)
                            .font(.system(size: 14))
                        Text("\(userIds.count)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        // Use cached status for performance, fallback to computation if not cached
        let displayStatus = statusCache[message.id] ?? message.displayStatus(for: conversation, currentUserId: currentUserId)

        switch displayStatus {
        case "sending":
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 10, height: 10)
                .tint(.white.opacity(0.8))
        case "sent":
            Image(systemName: "checkmark")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))
        case "delivered":
            Image(systemName: "checkmark.checkmark")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))
        case "read":
            Image(systemName: "checkmark.checkmark")
                .font(.system(size: 10))
                .foregroundStyle(.cyan)
        case "error":
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white)
        default:
            EmptyView()
        }
    }
}

// MARK: - Custom Bubble Shape

struct BubbleShape: Shape {
    let isFromCurrentUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isFromCurrentUser ?
                [.topLeft, .topRight, .bottomLeft] :
                [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}

struct ParticipantListView: View {
    let participantIds: [String]
    let participantUsers: [String: User]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(participantIds, id: \.self) { participantId in
                        if let user = participantUsers[participantId] {
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
                            }
                        } else {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                
                                Text("Loading...")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("\(participantIds.count) Participants")
                }
            }
            .navigationTitle("Group Info")
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

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationStack {
        ConversationDetailView(
            conversation: Conversation(
                id: "1",
                type: .direct,
                participantIds: ["user1", "user2"]
            ),
            otherUser: User(
                id: "user2",
                displayName: "John Doe",
                email: "john@example.com",
                createdAt: Date()
            )
        )
    }
}

