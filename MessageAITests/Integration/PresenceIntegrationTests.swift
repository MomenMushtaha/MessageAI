//
//  PresenceIntegrationTests.swift
//  MessageAITests
//
//  Validates presence and typing integrations against Firebase emulator.
//

import XCTest
import FirebaseFirestore
@testable import MessageAI

@MainActor
final class PresenceIntegrationTests: FirebaseIntegrationTestCase {
    
    func testPresenceTrackingUpdatesUserDocument() async throws {
        let user = try await createTestUser(displayName: "PresenceUser")
        try await login(user)
        
        await PresenceService.shared.startPresenceTracking(userId: user.id)
        await waitForPropagation()
        
        let userDoc = try await Firestore.firestore()
            .collection("users")
            .document(user.id)
            .getDocument()
        
        guard let data = userDoc.data() else {
            XCTFail("Expected user document to exist for presence tracking")
            return
        }
        
        XCTAssertEqual(data["isOnline"] as? Bool, true)
        XCTAssertNotNil(data["lastSeen"], "Presence tracking should update lastSeen timestamp")
        
        await PresenceService.shared.stopPresenceTracking(userId: user.id)
        await waitForPropagation()
        
        let offlineDoc = try await Firestore.firestore()
            .collection("users")
            .document(user.id)
            .getDocument()
        
        XCTAssertEqual(offlineDoc.data()?["isOnline"] as? Bool, false)
        
        logoutCurrentUser()
    }
    
    func testTypingIndicatorLifecycle() async throws {
        let sender = try await createTestUser(displayName: "TypingSender")
        let receiver = try await createTestUser(displayName: "TypingReceiver")
        
        try await login(sender)
        
        let chatService = ChatService.shared
        let conversationId = try await chatService.createOrGetConversation(
            participantIds: [sender.id, receiver.id],
            type: .direct
        )
        
        await PresenceService.shared.startTyping(userId: sender.id, conversationId: conversationId)
        await waitForPropagation()
        
        let typingDoc = try await Firestore.firestore()
            .collection("conversations")
            .document(conversationId)
            .collection("typing")
            .document(sender.id)
            .getDocument()
        
        XCTAssertEqual(typingDoc.data()?["isTyping"] as? Bool, true)
        
        await PresenceService.shared.stopTyping(userId: sender.id, conversationId: conversationId)
        await waitForPropagation()
        
        let stoppedDoc = try await Firestore.firestore()
            .collection("conversations")
            .document(conversationId)
            .collection("typing")
            .document(sender.id)
            .getDocument()
        
        XCTAssertEqual(stoppedDoc.data()?["isTyping"] as? Bool, false)
        
        try? await chatService.deleteConversation(conversationId: conversationId)
        logoutCurrentUser()
    }
}

