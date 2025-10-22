# MessageAI Micro-Step Implementation Guide
## Ultra-Granular Implementation Plan

**Created:** 2025-10-22
**Approach:** Atomic micro-steps (1-4 hours each), build & test after EVERY step

---

## How to Use This Guide

1. Complete ONE micro-step at a time
2. Build with Xcode (⌘B) after each step - must succeed
3. Test the specific change before moving on
4. Commit after each step (optional but recommended)
5. Never skip ahead - each step depends on previous ones

---

## Phase 1.1: Message Deletion
**Total Duration:** 3-4 days (split into 12 micro-steps)

---

### Micro-Step 1.1.1: Add deletedBy Field to Message Model
**Duration:** 30 minutes
**Goal:** Update data model to support deletion tracking

**What to do:**
1. Open `MessageAI/Models/Message.swift`
2. Add optional property: `var deletedBy: [String]?`
3. Make sure it's included in Firestore encoding/decoding

**Code to add:**
```swift
struct Message: Identifiable, Codable, Equatable {
    // ... existing properties ...
    var deletedBy: [String]? // NEW: Track who deleted this message
}
```

**Build & Test:**
- ⌘B to build - should succeed with no errors
- Existing functionality should work unchanged
- Run the app - messages should still display normally

**Success criteria:**
✅ App builds successfully
✅ No breaking changes to existing message display
✅ New property exists in Message model

---

### Micro-Step 1.1.2: Add Helper to Check if Message is Deleted
**Duration:** 30 minutes
**Goal:** Create reusable logic to determine if a message is deleted for a user

**What to do:**
1. Still in `Message.swift`
2. Add computed property to check deletion status

**Code to add:**
```swift
extension Message {
    /// Check if this message is deleted for a specific user
    func isDeleted(for userId: String) -> Bool {
        return deletedBy?.contains(userId) ?? false
    }

    /// Check if message is deleted for everyone
    var isDeletedForEveryone: Bool {
        // If all participants deleted it, it's deleted for everyone
        // For now, we'll consider it deleted for everyone if deletedBy has at least 2 users
        // This will be refined when we integrate with conversation participants
        return (deletedBy?.count ?? 0) >= 2
    }
}
```

**Build & Test:**
- ⌘B to build - should succeed
- Add a test message in Xcode debugger/console:
  ```swift
  let msg = Message(id: "test", conversationId: "c1", senderId: "u1", text: "Hi", createdAt: Date(), status: "sent")
  print(msg.isDeleted(for: "u1")) // Should print false
  ```

**Success criteria:**
✅ App builds successfully
✅ Helper methods work as expected
✅ No impact on existing functionality

---

### Micro-Step 1.1.3: Create deleteMessage Method Signature in ChatService
**Duration:** 30 minutes
**Goal:** Add the method structure without implementation

**What to do:**
1. Open `MessageAI/Services/ChatService.swift`
2. Add method signature with TODO comment

**Code to add:**
```swift
// MARK: - Message Deletion

/// Delete a message for the current user or for everyone
/// - Parameters:
///   - messageId: The ID of the message to delete
///   - conversationId: The conversation containing the message
///   - deleteForEveryone: If true, delete for all users (sender only)
func deleteMessage(messageId: String, conversationId: String, deleteForEveryone: Bool) async throws {
    // TODO: Implement in next step
    print("⚠️ deleteMessage called - not yet implemented")
}
```

**Build & Test:**
- ⌘B to build - should succeed
- Method exists but doesn't do anything yet
- Existing app functionality unchanged

**Success criteria:**
✅ App builds successfully
✅ Method signature is correct and documented
✅ Can be called without crashing (just prints TODO)

---

### Micro-Step 1.1.4: Implement Delete for Me Logic
**Duration:** 1-2 hours
**Goal:** Implement Firestore update to mark message as deleted for current user

**What to do:**
1. Still in `ChatService.swift`
2. Replace the TODO in `deleteMessage` with actual implementation

**Code to replace:**
```swift
func deleteMessage(messageId: String, conversationId: String, deleteForEveryone: Bool) async throws {
    guard let currentUserId = authService.currentUser?.id else {
        throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }

    let messageRef = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)

    if deleteForEveryone {
        // TODO: Implement in next step
        print("⚠️ Delete for everyone not yet implemented")
        return
    }

    // Delete for current user only
    print("🗑️ Marking message \(messageId) as deleted for user \(currentUserId)")

    try await messageRef.updateData([
        "deletedBy": FieldValue.arrayUnion([currentUserId])
    ])

    print("✅ Message marked as deleted for current user")
}
```

**Build & Test:**
- ⌘B to build - should succeed
- Run app, login, open a conversation
- In Xcode console, manually call:
  ```swift
  Task {
      try? await chatService.deleteMessage(messageId: "some-real-message-id", conversationId: "some-conversation-id", deleteForEveryone: false)
  }
  ```
- Check Firestore Console - message document should have `deletedBy` array with your user ID

**Success criteria:**
✅ App builds and runs
✅ Firestore updates correctly with deletedBy array
✅ No crashes or errors
✅ Console logs show success message

---

### Micro-Step 1.1.5: Implement Delete for Everyone Logic
**Duration:** 1 hour
**Goal:** Add ability for sender to delete message for all users

**What to do:**
1. Still in `deleteMessage` method
2. Replace the "Delete for everyone" TODO

**Code to update:**
```swift
func deleteMessage(messageId: String, conversationId: String, deleteForEveryone: Bool) async throws {
    guard let currentUserId = authService.currentUser?.id else {
        throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }

    let messageRef = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)

    if deleteForEveryone {
        // Verify user is the sender
        let messageDoc = try await messageRef.getDocument()
        guard let message = try? messageDoc.data(as: Message.self) else {
            throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Message not found"])
        }

        guard message.senderId == currentUserId else {
            throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the sender can delete for everyone"])
        }

        print("🗑️ Deleting message \(messageId) for everyone")

        // Mark as deleted for everyone by setting text to empty and adding flag
        try await messageRef.updateData([
            "text": "[Message deleted]",
            "deletedForEveryone": true,
            "deletedBy": FieldValue.arrayUnion([currentUserId])
        ])

        print("✅ Message deleted for everyone")
        return
    }

    // Delete for current user only
    print("🗑️ Marking message \(messageId) as deleted for user \(currentUserId)")

    try await messageRef.updateData([
        "deletedBy": FieldValue.arrayUnion([currentUserId])
    ])

    print("✅ Message marked as deleted for current user")
}
```

**Build & Test:**
- ⌘B to build
- Run app and send a message from your account
- Call deleteMessage with deleteForEveryone: true
- Check Firestore - message text should be "[Message deleted]"
- Try calling it from a different user (should throw permission error)

**Success criteria:**
✅ Sender can delete for everyone
✅ Non-senders get permission error
✅ Firestore updates correctly
✅ Message text changes to "[Message deleted]"

---

### Micro-Step 1.1.6: Update observeMessages to Include deletedBy
**Duration:** 30 minutes
**Goal:** Ensure deleted messages are properly decoded from Firestore

**What to do:**
1. Find the `observeMessages` method in `ChatService.swift`
2. Verify Message decoding includes the new `deletedBy` field
3. Since Message conforms to Codable, it should automatically decode

**Test:**
- Run the app
- Open a conversation that has a deleted message
- Print the message object in console to verify `deletedBy` is populated

**Build & Test:**
- ⌘B to build
- Run app and open conversation with deleted messages
- Check console logs - messages should decode correctly with deletedBy field

**Success criteria:**
✅ Messages with deletedBy decode properly
✅ No decoding errors in console
✅ App runs smoothly

---

### Micro-Step 1.1.7: Filter Deleted Messages from UI (Basic)
**Duration:** 1 hour
**Goal:** Hide deleted messages from the conversation view

**What to do:**
1. Open `Views/Conversation/ConversationDetailView.swift`
2. Find where messages are displayed (likely in a ForEach loop)
3. Add filter to exclude deleted messages

**Code to add:**
```swift
// Find the ForEach that displays messages, add filter:
ForEach(filteredMessages) { message in
    // message bubble display
}

// Add computed property at top of view:
private var filteredMessages: [Message] {
    guard let currentUserId = authService.currentUser?.id else {
        return chatService.messages
    }

    return chatService.messages.filter { message in
        !message.isDeleted(for: currentUserId)
    }
}
```

**Build & Test:**
- ⌘B to build
- Run app, open conversation
- Deleted messages should not appear
- Mark a message as deleted in Firestore manually
- Refresh app - message should disappear

**Success criteria:**
✅ Deleted messages are hidden from view
✅ Other messages still display normally
✅ Real-time updates work (deleted messages disappear)

---

### Micro-Step 1.1.8: Create MessageActionsSheet Component (UI Only)
**Duration:** 1-2 hours
**Goal:** Build the action sheet UI without hooking it up

**What to do:**
1. Create new file: `MessageAI/Components/MessageActionsSheet.swift`
2. Create SwiftUI view with action buttons

**Code to create:**
```swift
import SwiftUI

struct MessageActionsSheet: View {
    let message: Message
    let currentUserId: String
    let onDelete: (Bool) -> Void // Parameter: deleteForEveryone
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Message Options")
                .font(.headline)
                .padding()

            Divider()

            // Delete for me
            Button {
                onDelete(false)
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete for Me")
                    Spacer()
                }
                .padding()
                .foregroundColor(.red)
            }

            Divider()

            // Delete for everyone (only if sender)
            if message.senderId == currentUserId {
                Button {
                    onDelete(true)
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete for Everyone")
                        Spacer()
                    }
                    .padding()
                    .foregroundColor(.red)
                }

                Divider()
            }

            // Cancel
            Button {
                onDismiss()
            } label: {
                HStack {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding()
    }
}

#Preview {
    MessageActionsSheet(
        message: Message(id: "1", conversationId: "c1", senderId: "u1", text: "Test", createdAt: Date(), status: "sent"),
        currentUserId: "u1",
        onDelete: { _ in },
        onDismiss: { }
    )
}
```

**Build & Test:**
- ⌘B to build
- View the preview in Xcode Canvas
- Verify buttons appear correctly
- Verify "Delete for Everyone" only shows for sender

**Success criteria:**
✅ Component builds and displays in preview
✅ Buttons are styled correctly
✅ Conditional "Delete for Everyone" works
✅ No functionality yet (just UI)

---

### Micro-Step 1.1.9: Add Long-Press Gesture to Messages
**Duration:** 1 hour
**Goal:** Add gesture recognition to message bubbles

**What to do:**
1. Open `Views/Conversation/ConversationDetailView.swift`
2. Add state for showing action sheet
3. Add long-press gesture to message display

**Code to add:**
```swift
struct ConversationDetailView: View {
    // Add state:
    @State private var selectedMessage: Message?
    @State private var showMessageActions = false

    var body: some View {
        // In your message ForEach:
        ForEach(filteredMessages) { message in
            MessageBubbleRow(message: message, currentUserId: currentUserId)
                .onLongPressGesture {
                    selectedMessage = message
                    showMessageActions = true
                    // Optional: Add haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
        }
        .sheet(isPresented: $showMessageActions) {
            if let message = selectedMessage,
               let userId = authService.currentUser?.id {
                MessageActionsSheet(
                    message: message,
                    currentUserId: userId,
                    onDelete: { deleteForEveryone in
                        // TODO: Call delete in next step
                        print("Delete tapped: deleteForEveryone=\(deleteForEveryone)")
                        showMessageActions = false
                    },
                    onDismiss: {
                        showMessageActions = false
                    }
                )
            }
        }
    }
}
```

**Build & Test:**
- ⌘B to build
- Run app and open conversation
- Long-press on a message
- Action sheet should appear
- Tap buttons - should print to console and dismiss
- Verify haptic feedback works

**Success criteria:**
✅ Long-press shows action sheet
✅ Action sheet displays correct options
✅ Buttons print to console when tapped
✅ Sheet dismisses correctly
✅ Haptic feedback works

---

### Micro-Step 1.1.10: Connect Delete Action to ChatService
**Duration:** 1 hour
**Goal:** Wire up the UI to actually delete messages

**What to do:**
1. Still in `ConversationDetailView.swift`
2. Update the onDelete closure to call ChatService

**Code to update:**
```swift
.sheet(isPresented: $showMessageActions) {
    if let message = selectedMessage,
       let userId = authService.currentUser?.id {
        MessageActionsSheet(
            message: message,
            currentUserId: userId,
            onDelete: { deleteForEveryone in
                Task {
                    do {
                        try await chatService.deleteMessage(
                            messageId: message.id,
                            conversationId: message.conversationId,
                            deleteForEveryone: deleteForEveryone
                        )
                        print("✅ Message deleted successfully")
                    } catch {
                        print("❌ Failed to delete message: \(error.localizedDescription)")
                        // TODO: Show error alert in next step
                    }
                }
                showMessageActions = false
            },
            onDismiss: {
                showMessageActions = false
            }
        )
    }
}
```

**Build & Test:**
- ⌘B to build
- Run app, send a test message
- Long-press the message
- Tap "Delete for Me"
- Message should disappear from UI
- Check Firestore - deletedBy should contain your userId
- Try "Delete for Everyone" on a message you sent
- Check Firestore - text should be "[Message deleted]"

**Success criteria:**
✅ Delete for me works - message disappears
✅ Delete for everyone works (sender only)
✅ Firestore updates correctly
✅ Real-time sync - message disappears on other devices
✅ Errors are caught and logged

---

### Micro-Step 1.1.11: Add Error Handling with User Alerts
**Duration:** 1 hour
**Goal:** Show user-friendly error messages

**What to do:**
1. Add state for error alert in `ConversationDetailView`
2. Show alert when deletion fails

**Code to add:**
```swift
struct ConversationDetailView: View {
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        // In the message actions sheet onDelete:
        onDelete: { deleteForEveryone in
            Task {
                do {
                    try await chatService.deleteMessage(
                        messageId: message.id,
                        conversationId: message.conversationId,
                        deleteForEveryone: deleteForEveryone
                    )
                    print("✅ Message deleted successfully")
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            showMessageActions = false
        }

        // Add alert modifier:
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Failed to delete message")
        }
    }
}
```

**Build & Test:**
- ⌘B to build
- Test error case: try deleting someone else's message for everyone
- Alert should appear with permission error
- Tap OK - alert dismisses
- Test success case - no alert should appear

**Success criteria:**
✅ Error alerts display for failures
✅ User-friendly error messages
✅ Alert dismisses correctly
✅ No alerts on success

---

### Micro-Step 1.1.12: Add Optimistic UI Update with Rollback
**Duration:** 1-2 hours
**Goal:** Instantly hide deleted messages, then rollback if deletion fails

**What to do:**
1. Modify `ChatService.deleteMessage` to support optimistic updates
2. Store original message state
3. Rollback on failure

**Code to update in ChatService.swift:**
```swift
func deleteMessage(messageId: String, conversationId: String, deleteForEveryone: Bool) async throws {
    guard let currentUserId = authService.currentUser?.id else {
        throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }

    // Find the message in local cache
    guard let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else {
        throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Message not found"])
    }

    // Store original message for rollback
    let originalMessage = messages[messageIndex]

    // OPTIMISTIC UPDATE: Modify local state immediately
    var updatedMessage = originalMessage
    if deleteForEveryone {
        updatedMessage.text = "[Message deleted]"
    }
    updatedMessage.deletedBy = (updatedMessage.deletedBy ?? []) + [currentUserId]
    messages[messageIndex] = updatedMessage

    print("🔄 Optimistically updated message \(messageId)")

    let messageRef = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)

    do {
        if deleteForEveryone {
            // Verify user is the sender
            let messageDoc = try await messageRef.getDocument()
            guard let message = try? messageDoc.data(as: Message.self) else {
                throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Message not found"])
            }

            guard message.senderId == currentUserId else {
                throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the sender can delete for everyone"])
            }

            try await messageRef.updateData([
                "text": "[Message deleted]",
                "deletedForEveryone": true,
                "deletedBy": FieldValue.arrayUnion([currentUserId])
            ])
        } else {
            try await messageRef.updateData([
                "deletedBy": FieldValue.arrayUnion([currentUserId])
            ])
        }

        print("✅ Message deletion confirmed by server")

    } catch {
        // ROLLBACK: Restore original message
        print("❌ Deletion failed, rolling back")
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index] = originalMessage
        }
        throw error
    }
}
```

**Build & Test:**
- ⌘B to build
- Run app, send a message
- Delete it (for me)
- Message should disappear INSTANTLY
- Check Firestore - update should process in background
- Test failure case: Turn off internet, try to delete
- Message should reappear after failure

**Success criteria:**
✅ Messages disappear instantly (optimistic UI)
✅ Background sync works
✅ Rollback works on failure
✅ User experience is smooth and fast

---

## 🎉 Phase 1.1 Complete!

You now have fully functional message deletion with:
- ✅ Delete for me
- ✅ Delete for everyone (sender only)
- ✅ Long-press gesture
- ✅ Action sheet UI
- ✅ Error handling
- ✅ Optimistic UI updates
- ✅ Rollback on failure

**Final Build & Test:**
- ⌘B to build - should succeed
- Run comprehensive tests:
  - Delete your own messages (for me)
  - Delete your own messages (for everyone)
  - Try deleting others' messages (should only see "Delete for me")
  - Test offline (should queue and sync when back online)
  - Test on multiple devices simultaneously
  - Verify real-time sync works

---

## Phase 1.2: Message Editing (12 micro-steps)

### Micro-Step 1.2.1: Add Editing Fields to Message Model
**Duration:** 30 minutes

**What to do:**
1. Open `Models/Message.swift`
2. Add editing-related fields

**Code to add:**
```swift
struct Message: Identifiable, Codable, Equatable {
    // ... existing properties ...
    var editedAt: Date?
    var editHistory: [String]? // Array of previous text versions (optional)
}
```

**Build & Test:**
- ⌘B - should succeed
- No breaking changes

**Success criteria:**
✅ App builds
✅ New fields exist in model

---

### Micro-Step 1.2.2: Add Helper to Check if Message is Editable
**Duration:** 30 minutes

**What to do:**
1. Add computed property to check if message can be edited

**Code to add:**
```swift
extension Message {
    /// Check if this message can be edited
    /// Rules: Only sender, within 15 minutes, not deleted
    func canEdit(by userId: String) -> Bool {
        guard senderId == userId else { return false }
        guard !isDeleted(for: userId) else { return false }

        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        return createdAt > fifteenMinutesAgo
    }

    var wasEdited: Bool {
        return editedAt != nil
    }
}
```

**Build & Test:**
- Test helper with sample messages
- Verify 15-minute window works

**Success criteria:**
✅ Helper methods work correctly
✅ Time logic is correct

---

### Micro-Step 1.2.3: Create editMessage Method in ChatService
**Duration:** 1-2 hours

**What to do:**
1. Add method to `ChatService.swift`

**Code to add:**
```swift
// MARK: - Message Editing

/// Edit a message's text
/// - Parameters:
///   - messageId: The ID of the message to edit
///   - conversationId: The conversation containing the message
///   - newText: The new text content
func editMessage(messageId: String, conversationId: String, newText: String) async throws {
    guard let currentUserId = authService.currentUser?.id else {
        throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }

    guard !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Message cannot be empty"])
    }

    let messageRef = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)

    // Fetch message to verify permissions
    let messageDoc = try await messageRef.getDocument()
    guard let message = try? messageDoc.data(as: Message.self) else {
        throw NSError(domain: "ChatService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Message not found"])
    }

    guard message.canEdit(by: currentUserId) else {
        throw NSError(domain: "ChatService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only edit your own messages within 15 minutes"])
    }

    print("✏️ Editing message \(messageId)")

    try await messageRef.updateData([
        "text": newText,
        "editedAt": FieldValue.serverTimestamp(),
        // Optionally save edit history
        "editHistory": FieldValue.arrayUnion([message.text])
    ])

    print("✅ Message edited successfully")
}
```

**Build & Test:**
- Build and run
- Call method from console with a test message
- Check Firestore - should see updated text and editedAt

**Success criteria:**
✅ Method works correctly
✅ Firestore updates properly
✅ Permissions are enforced

---

### Micro-Step 1.2.4: Add "Edit" to MessageActionsSheet
**Duration:** 30 minutes

**What to do:**
1. Update `MessageActionsSheet.swift`
2. Add Edit button (conditional on canEdit)

**Code to add:**
```swift
struct MessageActionsSheet: View {
    let message: Message
    let currentUserId: String
    let onEdit: () -> Void // NEW
    let onDelete: (Bool) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ... existing header ...

            // Edit (only if editable)
            if message.canEdit(by: currentUserId) {
                Button {
                    onEdit()
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                        Spacer()
                    }
                    .padding()
                }

                Divider()
            }

            // ... existing delete buttons ...
        }
    }
}
```

**Build & Test:**
- Update preview to include onEdit
- View in Canvas
- Edit button should appear for recent own messages

**Success criteria:**
✅ Edit button appears conditionally
✅ Tapping edit triggers callback
✅ UI looks correct

---

### Micro-Step 1.2.5: Create Message Edit TextField UI
**Duration:** 1 hour

**What to do:**
1. In `ConversationDetailView.swift`
2. Add state for editing mode

**Code to add:**
```swift
struct ConversationDetailView: View {
    @State private var editingMessageId: String?
    @State private var editingText: String = ""
    @State private var isEditMode: Bool = false

    var body: some View {
        // In message actions sheet, update onEdit:
        onEdit: {
            editingMessageId = message.id
            editingText = message.text
            isEditMode = true
            showMessageActions = false
        }

        // At bottom of view, above message input, add:
        if isEditMode {
            editMessageBar
        }
    }

    private var editMessageBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Cancel button
                Button {
                    isEditMode = false
                    editingMessageId = nil
                    editingText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }

                // Text field
                TextField("Edit message", text: $editingText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // Save button
                Button {
                    saveEditedMessage()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
                .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }

    private func saveEditedMessage() {
        guard let messageId = editingMessageId,
              let conversation = chatService.currentConversation else {
            return
        }

        Task {
            do {
                try await chatService.editMessage(
                    messageId: messageId,
                    conversationId: conversation.id,
                    newText: editingText
                )

                isEditMode = false
                editingMessageId = nil
                editingText = ""

                print("✅ Message edited successfully")
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
```

**Build & Test:**
- Build and run
- Long-press recent message
- Tap "Edit"
- Edit bar should appear at bottom
- Type new text
- Tap checkmark
- Message should update in Firestore and UI

**Success criteria:**
✅ Edit bar appears correctly
✅ Can type new text
✅ Save button works
✅ Cancel button works
✅ Message updates in real-time

---

### Micro-Step 1.2.6: Add "edited" Indicator to Message Bubbles
**Duration:** 1 hour

**What to do:**
1. Update `MessageBubbleRow.swift` (or wherever message bubbles are displayed)
2. Show "(edited)" label for edited messages

**Code to add:**
```swift
// In message bubble content:
VStack(alignment: .leading, spacing: 4) {
    Text(message.text)

    HStack(spacing: 4) {
        Text(timeString)
            .font(.caption2)

        // Edited indicator
        if message.wasEdited {
            Text("• edited")
                .font(.caption2)
                .foregroundColor(.secondary)
        }

        // ... existing status indicators ...
    }
}
```

**Build & Test:**
- Build and run
- Edit a message
- "(edited)" label should appear
- Should update in real-time when someone else edits

**Success criteria:**
✅ "edited" indicator appears
✅ Only appears for edited messages
✅ Styling is subtle and appropriate
✅ Real-time sync works

---

### Micro-Step 1.2.7-12: Similar micro-steps for offline support, optimistic updates, etc.
[Continue with similar granularity for remaining features...]

---

## Template for Breaking Down Any Feature

For any sub-phase (like 1.3, 2.1, etc.), follow this pattern:

### 1. Model Changes (30 min - 1 hour)
- Add new fields to data models
- Add helper computed properties
- Build & test

### 2. Service Method Signature (30 min)
- Add method signature with TODO
- Document parameters
- Build & test

### 3. Service Implementation (1-3 hours)
- Implement core logic
- Add error handling
- Build & test with manual calls

### 4. UI Component Creation (1-2 hours)
- Create new UI component (if needed)
- Style and layout
- Preview in Canvas
- Build & test

### 5. Connect UI to State (1 hour)
- Add @State variables
- Add gestures/buttons
- Wire up callbacks
- Build & test

### 6. Connect to Service (1 hour)
- Call service methods from UI
- Handle async/await
- Basic error handling
- Build & test end-to-end

### 7. Error Handling (1 hour)
- Add user-facing error alerts
- Test error cases
- Build & test

### 8. Optimistic Updates (1-2 hours)
- Immediate UI updates
- Background sync
- Rollback on failure
- Build & test

### 9. Polish & Edge Cases (1-2 hours)
- Handle edge cases
- Add loading states
- Improve UX details
- Final build & test

---

## Key Principles

1. **Build after EVERY step** - If it doesn't build, don't continue
2. **Test after EVERY step** - Verify the specific change works
3. **One thing at a time** - Don't combine steps
4. **Commit often** - Each step is a logical commit point
5. **No skipping** - Each step builds on previous ones

---

## Tracking Progress

### Suggested Git Workflow

```bash
# After each micro-step:
git add .
git commit -m "feat: [Micro-Step X.X.X] Description"

# Example:
git commit -m "feat: [1.1.1] Add deletedBy field to Message model"
git commit -m "feat: [1.1.2] Add deletion check helpers to Message"
git commit -m "feat: [1.1.3] Create deleteMessage method signature"
# etc...
```

### Suggested Todo Tracking

Create checkboxes in this file or use a task manager:

#### Phase 1.1: Message Deletion
- [x] 1.1.1: Add deletedBy field
- [x] 1.1.2: Add helper methods
- [ ] 1.1.3: Create method signature
- [ ] 1.1.4: Implement delete for me
- [ ] 1.1.5: Implement delete for everyone
- [ ] 1.1.6: Update observeMessages
- [ ] 1.1.7: Filter deleted messages
- [ ] 1.1.8: Create action sheet UI
- [ ] 1.1.9: Add long-press gesture
- [ ] 1.1.10: Connect delete action
- [ ] 1.1.11: Add error handling
- [ ] 1.1.12: Add optimistic updates

---

## Benefits of This Approach

✅ **Always buildable** - Every step compiles successfully
✅ **Always testable** - Can verify each change immediately
✅ **Low risk** - Easy to rollback or debug single step
✅ **Clear progress** - Know exactly where you are
✅ **Learning friendly** - Understand each piece before moving on
✅ **Pair programming ready** - Easy handoff points
✅ **Interview ready** - Can explain each decision
✅ **CI/CD friendly** - Every commit is deployable

---

## Next Steps

1. **Start with Micro-Step 1.1.1**
2. Complete each step before moving to the next
3. Build and test after EVERY step
4. Check off each completed step
5. Celebrate small wins! 🎉

---

**Ready? Let's start with Micro-Step 1.1.1!**
