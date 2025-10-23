//
//  MessageActionsSheet.swift
//  MessageAI
//
//  Action sheet for message long-press options
//

import SwiftUI

struct MessageActionsSheet: View {
    let message: Message
    let currentUserId: String
    let onEdit: () -> Void
    let onDelete: (Bool) -> Void // Bool = deleteForEveryone
    let onForward: () -> Void
    let onDismiss: () -> Void
    
    @State private var showDeleteConfirmation = false
    @State private var showDeleteForEveryoneConfirmation = false
    
    private var canEdit: Bool {
        message.canEdit(by: currentUserId)
    }
    
    private var canDeleteForEveryone: Bool {
        message.senderId == currentUserId
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Message Preview Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message Actions")
                            .font(.headline)
                        
                        Text(message.text)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .padding(.vertical, 4)
                    }
                    .padding(.vertical, 8)
                }
                
                // Actions Section
                Section {
                    // Copy
                    Button(action: {
                        UIPasteboard.general.string = message.text
                        onDismiss()
                        
                        // Show haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    
                    // Forward
                    Button(action: {
                        onForward()
                    }) {
                        Label("Forward", systemImage: "arrowshape.turn.up.right")
                    }
                    
                    // Reply (future feature)
                    Button(action: {
                        // TODO: Implement reply feature
                        onDismiss()
                    }) {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }
                    .disabled(true)
                    .foregroundStyle(.secondary)
                }
                
                // Edit Section (only if sender and within time limit)
                if canEdit {
                    Section {
                        Button(action: {
                            onEdit()
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                    } header: {
                        Text("Edit Message")
                    } footer: {
                        Text("You can edit this message within 15 minutes of sending")
                            .font(.caption)
                    }
                }
                
                // Delete Section
                Section {
                    // Delete for Me
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete for Me", systemImage: "trash")
                    }
                    
                    // Delete for Everyone (only if sender)
                    if canDeleteForEveryone {
                        Button(role: .destructive, action: {
                            showDeleteForEveryoneConfirmation = true
                        }) {
                            Label("Delete for Everyone", systemImage: "trash.fill")
                        }
                    }
                } header: {
                    Text("Delete Message")
                } footer: {
                    if canDeleteForEveryone {
                        Text("Deleting for everyone will remove the message from all participants' devices")
                            .font(.caption)
                    } else {
                        Text("This will only delete the message for you")
                            .font(.caption)
                    }
                }
                
                // Info Section
                Section {
                    HStack {
                        Text("Sent")
                        Spacer()
                        Text(message.createdAt, style: .date)
                            .foregroundStyle(.secondary)
                        Text(message.createdAt, style: .time)
                            .foregroundStyle(.secondary)
                    }
                    
                    if message.wasEdited, let editedAt = message.editedAt {
                        HStack {
                            Text("Edited")
                            Spacer()
                            Text(editedAt, style: .date)
                                .foregroundStyle(.secondary)
                            Text(editedAt, style: .time)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(message.status.capitalized)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Message Info")
                }
            }
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .confirmationDialog("Delete Message?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete for Me", role: .destructive) {
                    onDelete(false)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete the message from your device only. Other participants will still see it.")
            }
            .confirmationDialog("Delete for Everyone?", isPresented: $showDeleteForEveryoneConfirmation, titleVisibility: .visible) {
                Button("Delete for Everyone", role: .destructive) {
                    onDelete(true)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete the message for all participants. This action cannot be undone.")
            }
        }
    }
}

#Preview {
    MessageActionsSheet(
        message: Message(
            id: "1",
            conversationId: "conv1",
            senderId: "user1",
            text: "This is a test message that can be edited or deleted",
            createdAt: Date()
        ),
        currentUserId: "user1",
        onEdit: {
            print("Edit tapped")
        },
        onDelete: { deleteForEveryone in
            print("Delete tapped: \(deleteForEveryone)")
        },
        onForward: {
            print("Forward tapped")
        },
        onDismiss: {
            print("Dismiss tapped")
        }
    )
}

