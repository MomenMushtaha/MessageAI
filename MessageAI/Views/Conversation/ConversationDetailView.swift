//
//  ConversationDetailView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI
import FirebaseDatabase
import PhotosUI

// Foundation Models for on-device AI translation (if available)
#if canImport(FoundationModels)
@preconcurrency import FoundationModels
#endif

struct ConversationDetailView: View {
    let conversation: Conversation
    let otherUser: User?

    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatService: ChatService
    @StateObject private var audioService = AudioService.shared
    @StateObject private var inferenceManager = InferenceManager.shared

    // Message input
    @State private var messageText = ""
    @State private var isSending = false

    // AI features (Hybrid: Server + CoreML)
    @State private var aiSummary: InferenceSummaryResult?
    @State private var aiActions: [AIAction] = []
    @State private var isLoadingAI = false
    @State private var aiError: String?

    // Translation
    @State private var showTranslateSheet = false
    @State private var selectedMessageForTranslation: Message?
    @State private var translatedText: String?
    @State private var targetLanguage = "en"
    @State private var showTranslationSettings = false

    // Message Summarization
    @State private var showSummarizeSheet = false
    @State private var selectedMessageForSummarization: Message?
    @State private var summarizedText: String?

    // Text Selection Summarization
    @State private var showTextSummarySheet = false
    @State private var selectedTextToSummarize: String?
    @State private var textSummaryResult: String?

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
                                        currentUserId: authService.currentUser?.id ?? "",
                                        onSummarizeText: { selectedText in
                                            selectedTextToSummarize = selectedText
                                            textSummaryResult = nil
                                            showTextSummarySheet = true
                                        }
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

            // AI Result Card (Hybrid Inference)
            if let summary = aiSummary {
                AIResultCard(
                    title: "AI Summary",
                    content: summary.summary,
                    sources: summary.sources,
                    onDevice: summary.onDevice,
                    model: summary.model
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
                onTranslate: {
                    // Show translate for the most recent message
                    if let lastMessage = currentMessages.last {
                        selectedMessageForTranslation = lastMessage
                        showTranslateSheet = true
                    }
                }
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
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showTranslationSettings = true
                    } label: {
                        Label("Translation Settings", systemImage: "globe")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            editMessageSheet
        }
        .sheet(isPresented: $showReactionPicker) {
            reactionPickerSheet
        }
        .sheet(isPresented: $showTranslateSheet) {
            translateSheet
        }
        .sheet(isPresented: $showSummarizeSheet) {
            summarizeSheet
        }
        .sheet(isPresented: $showTranslationSettings) {
            OpenAISettingsView()
        }
        .sheet(isPresented: $showVoiceRecording) {
            voiceRecordingSheet
        }
        .sheet(isPresented: $showTextSummarySheet) {
            textSummarySheet
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

    private var translateSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let message = selectedMessageForTranslation {
                    // Original text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(message.text)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Language selector
                    Picker("Translate to", selection: $targetLanguage) {
                        Text("English").tag("en")
                        Text("Spanish").tag("es") 
                        Text("French").tag("fr")
                        Text("German").tag("de")
                        Text("Italian").tag("it")
                        Text("Portuguese").tag("pt")
                        Text("Russian").tag("ru")
                        Text("Japanese").tag("ja")
                        Text("Korean").tag("ko")
                        Text("Chinese").tag("zh")
                        Text("Arabic").tag("ar")
                        Text("Dutch").tag("nl")
                        Text("Polish").tag("pl")
                        Text("Turkish").tag("tr")
                        Text("Hebrew").tag("he")
                        Text("Thai").tag("th")
                        Text("Vietnamese").tag("vi")
                        Text("Ukrainian").tag("uk")
                        Text("Czech").tag("cs")
                        Text("Hungarian").tag("hu")
                    }
                    .pickerStyle(.menu)

                    // Translate button
                    Button {
                        Task { await translateMessage(message: message, targetLang: targetLanguage) }
                    } label: {
                        HStack {
                            if isLoadingAI {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isLoadingAI ? "Translating..." : "Translate")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoadingAI)
                    
                    #if canImport(FoundationModels)
                    if #available(iOS 26.0, *) {
                        FoundationModelsStatusView()
                    }
                    #endif

                    // Translated text
                    if let translated = translatedText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Translation")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ScrollView {
                                Text(cleanTranslationText(translated))
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 300)
                        }
                    }

                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Translate Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showTranslateSheet = false
                        translatedText = nil
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var summarizeSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let message = selectedMessageForSummarization {
                    // Original text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView {
                            Text(message.text)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 200)
                    }

                    // Summarize button
                    Button {
                        Task { await summarizeMessage(message: message) }
                    } label: {
                        HStack {
                            if isLoadingAI {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Image(systemName: "sparkles")
                            Text(isLoadingAI ? "Summarizing..." : "Summarize")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoadingAI)

                    #if canImport(FoundationModels)
                    if #available(iOS 26.0, *) {
                        FoundationModelsStatusView()
                    }
                    #endif

                    // Summarized text
                    if let summary = summarizedText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ScrollView {
                                Text(summary)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 300)
                        }
                    }

                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Summarize Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showSummarizeSheet = false
                        summarizedText = nil
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var textSummarySheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let selectedText = selectedTextToSummarize {
                    // Original selected text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ScrollView {
                            Text(selectedText)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 150)
                    }
                    
                    // Summarize button
                    Button {
                        Task { await summarizeSelectedText(selectedText) }
                    } label: {
                        HStack {
                            if isLoadingAI {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Image(systemName: "sparkles")
                            Text(isLoadingAI ? "Summarizing..." : "Summarize")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoadingAI)
                    
                    #if canImport(FoundationModels)
                    if #available(iOS 26.0, *) {
                        FoundationModelsStatusView()
                    }
                    #endif
                    
                    // Summary result
                    if let summary = textSummaryResult {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.blue)
                                Text("Summary")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            ScrollView {
                                Text(summary)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 300)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Summarize Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showTextSummarySheet = false
                        textSummaryResult = nil
                        selectedTextToSummarize = nil
                    }
                }
            }
        }
        .presentationDetents([.large])
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
        // Translate option (available for all messages)
        Button {
            selectedMessageForTranslation = message
            showTranslateSheet = true
        } label: {
            Label("Translate", systemImage: "globe")
        }

        // Summarize option (available for all messages with text)
        if !message.text.isEmpty {
            Button {
                selectedMessageForSummarization = message
                showSummarizeSheet = true
            } label: {
                Label("Summarize", systemImage: "sparkles")
            }
        }

        // React option
        Button {
            reactionMessageId = message.id
            showReactionPicker = true
        } label: {
            Label("React", systemImage: "face.smiling")
        }
        
        Divider()
        
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
    
    // MARK: - AI Actions (Phase B)

    private func summarizeTap() async {
        isLoadingAI = true
        defer { isLoadingAI = false }

        do {
            print("🤖 Calling AI summarize for conversation: \(conversation.id)")
            let summary = try await inferenceManager.summarize(
                convId: conversation.id,
                messages: currentMessages,
                window: "week",
                style: "bullets"
            )
            await MainActor.run {
                aiSummary = summary
                aiError = nil
                print("✅ Summary generated: \(summary.onDevice ? "On-Device" : "Server") (\(summary.model))")
            }
        } catch {
            print("❌ AI summarize error: \(error.localizedDescription)")
            await MainActor.run {
                aiError = error.localizedDescription
                errorMessage = "AI Summarize failed: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    private func actionsTap() async {
        isLoadingAI = true
        defer { isLoadingAI = false }

        do {
            print("🤖 Extracting action items for conversation: \(conversation.id)")
            let actions = try await inferenceManager.extractActions(
                convId: conversation.id,
                messages: currentMessages
            )
            await MainActor.run {
                aiActions = actions
                aiError = nil
                print("✅ Extracted \(actions.count) action items")
            }
        } catch {
            print("❌ AI action items error: \(error.localizedDescription)")
            await MainActor.run {
                aiError = error.localizedDescription
                errorMessage = "AI Actions failed: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    private func summarizeSelectedText(_ text: String) async {
        isLoadingAI = true
        defer { isLoadingAI = false }
        
        do {
            print("✨ Summarizing selected text (\(text.count) characters)...")
            
            // Try using Foundation Models for on-device summarization first
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                if let onDeviceSummary = try await summarizeWithFoundationModels(text: text) {
                    await MainActor.run {
                        textSummaryResult = onDeviceSummary
                        aiError = nil
                        print("✅ Summarization completed using Foundation Models")
                    }
                    return
                }
            }
            #endif
            
            // Fallback: Use the server-based summarization
            // Create a temporary message for the inference manager
            let tempMessage = Message(
                id: UUID().uuidString,
                conversationId: conversation.id,
                senderId: "temp",
                text: text,
                createdAt: Date()
            )
            
            let result = try await inferenceManager.summarize(
                convId: conversation.id,
                messages: [tempMessage],
                window: "all",
                style: "paragraph"
            )
            
            await MainActor.run {
                textSummaryResult = result.summary
                aiError = nil
                print("✅ Summarization completed using \(result.model)")
            }
        } catch {
            print("❌ Summarization error: \(error.localizedDescription)")
            await MainActor.run {
                aiError = error.localizedDescription
                errorMessage = "Summarization failed: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func translateMessage(message: Message, targetLang: String) async {
        isLoadingAI = true
        defer { isLoadingAI = false }

        do {
            print("🌐 Translating message to \(targetLang)...")
            
            // Try using Foundation Models for on-device translation first
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                if let onDeviceTranslation = try await translateWithFoundationModels(text: message.text, targetLang: targetLang) {
                    await MainActor.run {
                        translatedText = onDeviceTranslation
                        aiError = nil
                        print("✅ Translation completed using Foundation Models")
                    }
                    return
                }
            }
            #endif
            
            // Fallback to existing inference manager
            let result = try await inferenceManager.translate(text: message.text, targetLang: targetLang)
            await MainActor.run {
                translatedText = result
                aiError = nil
                print("✅ Translation completed using external service")
            }
        } catch {
            print("❌ Translation error: \(error.localizedDescription)")
            await MainActor.run {
                aiError = error.localizedDescription
                errorMessage = "Translation failed: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    private func summarizeMessage(message: Message) async {
        isLoadingAI = true
        defer { isLoadingAI = false }

        do {
            print("✨ Summarizing message (\(message.text.count) characters)...")

            // Try using Foundation Models for on-device summarization first
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                if let onDeviceSummary = try await summarizeWithFoundationModels(text: message.text) {
                    await MainActor.run {
                        summarizedText = onDeviceSummary
                        aiError = nil
                        print("✅ Summarization completed using Foundation Models")
                    }
                    return
                }
            }
            #endif

            // Fallback: Use the server-based summarization
            // Create a temporary message for the inference manager
            let tempMessage = Message(
                id: UUID().uuidString,
                conversationId: conversation.id,
                senderId: "temp",
                text: message.text,
                createdAt: Date()
            )

            let result = try await inferenceManager.summarize(
                convId: conversation.id,
                messages: [tempMessage],
                window: "all",
                style: "bullets"
            )

            await MainActor.run {
                summarizedText = result.summary
                aiError = nil
                print("✅ Summarization completed using \(result.model)")
            }
        } catch {
            print("❌ Summarization error: \(error.localizedDescription)")
            await MainActor.run {
                aiError = error.localizedDescription
                errorMessage = "Summarization failed: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    @ViewBuilder
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
        errorMessage = message
        showErrorAlert = true
    }
    
    // Clean translation text from server response
    private func cleanTranslationText(_ text: String) -> String {
        // Remove the explanatory text and just show actual translation
        if text.contains("🌐 Translation Service Ready") {
            // For placeholder responses, show a simple message
            return "Translation service is ready. Configure an OpenAI API key to get actual translations, or wait for Foundation Models support."
        } else if text.contains("[Foundation Models Translation to") {
            // Extract just the target language info for Foundation Models placeholder
            let lines = text.components(separatedBy: "\n")
            if let targetLine = lines.first(where: { $0.contains("[Foundation Models Translation to") }) {
                return targetLine.replacingOccurrences(of: "🌐 ", with: "")
            }
        } else if !text.contains("Original text:") && !text.contains("⚠️") && !text.contains("🌐") && !text.contains("Translation Service Ready") {
            // If it's a clean translation result (from actual OpenAI), show it as-is
            return text
        }
        
        // Fallback: try to extract any clean translation lines
        let lines = text.components(separatedBy: "\n").filter { line in
            !line.contains("Original text:") &&
            !line.contains("Target language:") &&
            !line.contains("Translation requires:") &&
            !line.contains("Translation Service Ready") &&
            !line.contains("OpenAI API") &&
            !line.contains("Foundation Models") &&
            !line.contains("⚠️") &&
            !line.contains("🌐") &&
            !line.contains("Your app is") &&
            !line.contains("The translation") &&
            !line.contains("configured and ready") &&
            !line.contains("when Foundation Models") &&
            !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        let cleanText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanText.isEmpty ? "Translation service is ready. Configure an OpenAI API key for actual translations." : cleanText
    }
    
    // MARK: - Foundation Models AI Functions
    
    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func summarizeWithFoundationModels(text: String) async throws -> String? {
        // Check if Foundation Models is available
        let model = SystemLanguageModel.default
        
        guard case .available = model.availability else {
            print("ℹ️ Foundation Models not available, falling back to external service")
            return nil
        }
        
        // Create a summarization session
        let instructions = """
        You are a professional text summarizer. Summarize the given text concisely while preserving key information.
        Provide only the summary without any explanations or additional context.
        Keep the summary clear, accurate, and well-structured.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        
        // Create the summarization prompt
        let prompt = "Summarize the following text: \"\(text)\""
        
        do {
            let response = try await session.respond(to: prompt)
            let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return summary.isEmpty ? nil : summary
        } catch {
            print("❌ Foundation Models summarization failed: \(error)")
            return nil
        }
    }
    
    @available(iOS 26.0, *)
    private func translateWithFoundationModels(text: String, targetLang: String) async throws -> String? {
        // Check if Foundation Models is available
        let model = SystemLanguageModel.default
        
        guard case .available = model.availability else {
            print("ℹ️ Foundation Models not available, falling back to external service")
            return nil
        }
        
        // Create a translation session
        let instructions = """
        You are a professional translator. Translate the given text to the target language.
        Provide only the translated text without any explanations or additional context.
        Maintain the original meaning and tone as closely as possible.
        """
        
        let session = LanguageModelSession(instructions: instructions)
        
        // Create the translation prompt
        let languageName = languageNameForCode(targetLang)
        let prompt = "Translate the following text to \(languageName): \"\(text)\""
        
        do {
            let response = try await session.respond(to: prompt)
            let translatedText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove any quotes that might wrap the translation
            let cleanTranslation = translatedText.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return cleanTranslation.isEmpty ? nil : cleanTranslation
        } catch {
            print("❌ Foundation Models translation failed: \(error)")
            return nil
        }
    }
    #endif
    
    // Helper function to convert language codes to readable names
    private func languageNameForCode(_ code: String) -> String {
        switch code {
        case "en": return "English"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "it": return "Italian"
        case "pt": return "Portuguese"
        case "ru": return "Russian"
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "zh": return "Chinese"
        case "ar": return "Arabic"
        case "nl": return "Dutch"
        case "pl": return "Polish"
        case "tr": return "Turkish"
        case "he": return "Hebrew"
        case "th": return "Thai"
        case "vi": return "Vietnamese"
        case "uk": return "Ukrainian"
        case "cs": return "Czech"
        case "hu": return "Hungarian"
        default: return code.uppercased()
        }
    }
}

// MARK: - Message Bubble Row

struct MessageBubbleRow: View {
    let message: Message
    let isFromCurrentUser: Bool
    let conversation: Conversation
    let currentUserId: String
    let onSummarizeText: (String) -> Void
    
    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 0) {
            if isFromCurrentUser {
                    Spacer(minLength: 60)
                    messageBubble
                        .background(Color.blue)
                        .foregroundStyle(.white)
                } else {
                    messageBubble
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 60)
                }
            }
            .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
            
            // Reactions
            if let reactions = message.reactions, !reactions.isEmpty {
                reactionsView(reactions)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var messageBubble: some View {
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Media content
            if let mediaType = message.mediaType {
                mediaContentView(mediaType)
            }
            
            // Text content
            if !message.text.isEmpty {
                SelectableMessageText(
                    text: message.text,
                    isFromCurrentUser: isFromCurrentUser,
                    onSummarize: onSummarizeText
                )
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
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isFromCurrentUser ? .trailing : .leading)
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
}

// MARK: - Foundation Models Status View

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct FoundationModelsStatusView: View {
    @State private var model = SystemLanguageModel.default
    
    var body: some View {
        switch model.availability {
        case .available:
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.green)
                Text("Using on-device AI translation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .unavailable(.appleIntelligenceNotEnabled):
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Enable Apple Intelligence for faster translations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .unavailable(.deviceNotEligible):
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Using external translation service")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        default:
            HStack {
                Image(systemName: "cloud")
                    .foregroundStyle(.blue)
                Text("Using external translation service")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif

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
