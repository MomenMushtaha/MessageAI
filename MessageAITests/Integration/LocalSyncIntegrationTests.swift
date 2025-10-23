//
//  LocalSyncIntegrationTests.swift
//  MessageAITests
//
//  Ensures SwiftData offline cache syncs back to Firestore.
//

import XCTest
import FirebaseFirestore
@testable import MessageAI

@MainActor
final class LocalSyncIntegrationTests: FirebaseIntegrationTestCase {
    
    func testPendingMessagesSyncToFirestore() async throws {
        let sender = try await createTestUser(displayName: "SyncSender")
        let receiver = try await createTestUser(displayName: "SyncReceiver")
        
        try await login(sender)
        
        let chatService = ChatService.shared
        let conversationId = try await chatService.createOrGetConversation(
            participantIds: [sender.id, receiver.id],
            type: .direct
        )
        
        let messageId = UUID().uuidString
        let pendingMessage = Message(
            id: messageId,
            conversationId: conversationId,
            senderId: sender.id,
            text: "Message captured while offline",
            createdAt: Date(),
            status: "sending"
        )
        
        try LocalStorageService.shared.saveMessage(pendingMessage, status: "sending", isSynced: false)
        
        await chatService.syncPendingMessages()
        await waitForPropagation(milliseconds: 800)
        
        let firestoreDoc = try await Firestore.firestore()
            .collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
            .getDocument()
        
        XCTAssertTrue(firestoreDoc.exists, "Synced message should exist in Firestore")
        XCTAssertEqual(firestoreDoc.data()?["status"] as? String, "sent")
        
        let localMessages = try LocalStorageService.shared.getMessages(for: conversationId)
        let syncedMessage = localMessages.first { $0.id == messageId }
        
        XCTAssertEqual(syncedMessage?.status, "sent")
        XCTAssertTrue(syncedMessage?.deliveredTo.isEmpty ?? true)
        XCTAssertTrue(syncedMessage?.readBy.isEmpty ?? true)
        
        let pending = try LocalStorageService.shared.getPendingMessages()
        XCTAssertFalse(pending.contains(where: { $0.id == messageId }), "Pending queue should be cleared after sync")
        
        try? await chatService.deleteConversation(conversationId: conversationId)
        logoutCurrentUser()
    }
}

