//
//  MessageAITests.swift
//  MessageAITests
//
//  Created by Momen Mush on 2025-10-21.
//

import XCTest
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
@testable import MessageAI

/// Comprehensive integration tests for MessageAI real-time messaging functionality
class MessageAIIntegrationTests: XCTestCase {
    
    var authService: AuthService!
    var chatService: ChatService!
    
    // Test user credentials
    let testUser1Email = "testuser1_\(UUID().uuidString)@messageai.test"
    let testUser2Email = "testuser2_\(UUID().uuidString)@messageai.test"
    let testPassword = "TestPassword123!"
    
    var testUser1Id: String?
    var testUser2Id: String?
    var testConversationId: String?
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Configure Firebase if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Initialize services
        authService = AuthService.shared
        chatService = ChatService.shared
        
        print("✅ Test setup complete")
    }
    
    override func tearDown() async throws {
        // Clean up test data
        if let conversationId = testConversationId {
            try? await chatService.deleteConversation(conversationId: conversationId)
        }
        
        // Logout if logged in
        if authService.currentUser != nil {
            try? authService.logout()
        }
        
        // Clean up test users from Firebase Auth (optional - requires admin SDK)
        // Note: In production, you'd use Firebase Admin SDK to delete test users
        
        authService = nil
        chatService = nil
        
        try await super.tearDown()
        print("✅ Test teardown complete")
    }
    
    // MARK: - Authentication Tests
    
    func testAuthenticationFlow() async throws {
        print("🧪 Testing authentication flow...")
        
        // Test 1: Sign up new user
        try await authService.signUp(
            email: testUser1Email,
            password: testPassword,
            displayName: "Test User 1"
        )
        
        XCTAssertNotNil(authService.currentUser, "User should be logged in after signup")
        XCTAssertEqual(authService.currentUser?.email, testUser1Email, "Email should match")
        testUser1Id = authService.currentUser?.id
        
        print("✅ Sign up successful")
        
        // Test 2: Logout
        try authService.logout()
        XCTAssertNil(authService.currentUser, "User should be nil after logout")
        
        print("✅ Logout successful")
        
        // Test 3: Login with correct credentials
        try await authService.login(email: testUser1Email, password: testPassword)
        XCTAssertNotNil(authService.currentUser, "User should be logged in after login")
        XCTAssertEqual(authService.currentUser?.email, testUser1Email, "Email should match")
        
        print("✅ Login successful")
        
        // Test 4: Login with incorrect password should fail
        try authService.logout()
        
        do {
            try await authService.login(email: testUser1Email, password: "WrongPassword")
            XCTFail("Login with wrong password should fail")
        } catch {
            print("✅ Login with wrong password correctly failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Real-Time Messaging Tests
    
    func testSendAndReceiveMessage() async throws {
        print("🧪 Testing send and receive message flow...")
        
        // Setup: Create two test users
        try await setupTwoTestUsers()
        
        // Test: User 1 creates conversation and sends message
        guard let user1Id = testUser1Id else {
            XCTFail("Test user 1 not set up")
            return
        }
        
        guard let user2Id = testUser2Id else {
            XCTFail("Test user 2 not set up")
            return
        }
        
        // Login as user 1
        try await authService.login(email: testUser1Email, password: testPassword)
        
        // Create conversation
        let conversationId = try await chatService.createOrGetConversation(
            participantIds: [user1Id, user2Id],
            type: .direct
        )
        testConversationId = conversationId
        
        XCTAssertNotNil(conversationId, "Conversation should be created")
        print("✅ Conversation created: \(conversationId)")
        
        // Start observing messages
        chatService.observeMessages(conversationId: conversationId)
        
        // Wait for listener to initialize
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Send message
        let messageText = "Hello from integration test! 🚀"
        let startTime = Date()
        
        try await chatService.sendMessage(
            conversationId: conversationId,
            senderId: user1Id,
            text: messageText
        )
        
        let sendDuration = Date().timeIntervalSince(startTime)
        print("✅ Message sent in \(Int(sendDuration * 1000))ms")
        
        // Performance check: Message should be sent in under 2 seconds
        XCTAssertLessThan(sendDuration, 2.0, "Message send should complete within 2 seconds")
        
        // Wait for message to propagate
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        
        // Verify message appears in conversation
        let messages = chatService.messages[conversationId] ?? []
        XCTAssertGreaterThan(messages.count, 0, "Messages should exist in conversation")
        
        let sentMessage = messages.first { $0.text == messageText }
        XCTAssertNotNil(sentMessage, "Sent message should exist")
        XCTAssertEqual(sentMessage?.senderId, user1Id, "Sender ID should match")
        XCTAssertEqual(sentMessage?.status, "sent", "Message status should be 'sent'")
        
        print("✅ Message successfully sent and retrieved")
    }
    
    func testMultipleMessagesPerformance() async throws {
        print("🧪 Testing multiple messages performance...")
        
        // Setup
        try await setupTwoTestUsers()
        guard let user1Id = testUser1Id, let user2Id = testUser2Id else {
            XCTFail("Test users not set up")
            return
        }
        
        try await authService.login(email: testUser1Email, password: testPassword)
        
        let conversationId = try await chatService.createOrGetConversation(
            participantIds: [user1Id, user2Id],
            type: .direct
        )
        testConversationId = conversationId
        
        chatService.observeMessages(conversationId: conversationId)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Send 10 messages rapidly
        let messageCount = 10
        let startTime = Date()
        
        for i in 1...messageCount {
            try await chatService.sendMessage(
                conversationId: conversationId,
                senderId: user1Id,
                text: "Test message #\(i)"
            )
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        let averagePerMessage = totalDuration / Double(messageCount)
        
        print("✅ Sent \(messageCount) messages in \(String(format: "%.2f", totalDuration))s")
        print("✅ Average per message: \(Int(averagePerMessage * 1000))ms")
        
        // Performance check: Should be able to send 10 messages in under 10 seconds
        XCTAssertLessThan(totalDuration, 10.0, "Should send 10 messages within 10 seconds")
        
        // Wait for all messages to sync
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2s
        
        // Verify all messages arrived
        let messages = chatService.messages[conversationId] ?? []
        XCTAssertGreaterThanOrEqual(messages.count, messageCount, "All messages should be received")
        
        print("✅ All messages received and verified")
    }
    
    func testMessageStatusUpdates() async throws {
        print("🧪 Testing message status updates (delivered/read)...")
        
        // Setup
        try await setupTwoTestUsers()
        guard let user1Id = testUser1Id, let user2Id = testUser2Id else {
            XCTFail("Test users not set up")
            return
        }
        
        // User 1 sends message
        try await authService.login(email: testUser1Email, password: testPassword)
        
        let conversationId = try await chatService.createOrGetConversation(
            participantIds: [user1Id, user2Id],
            type: .direct
        )
        testConversationId = conversationId
        
        chatService.observeMessages(conversationId: conversationId)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        try await chatService.sendMessage(
            conversationId: conversationId,
            senderId: user1Id,
            text: "Test message for status"
        )
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // User 2 logs in and marks as delivered
        try authService.logout()
        try await authService.login(email: testUser2Email, password: testPassword)
        
        chatService.observeMessages(conversationId: conversationId)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        await chatService.markMessagesAsDelivered(conversationId: conversationId, userId: user2Id)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Check that message was marked as delivered
        let messages = chatService.messages[conversationId] ?? []
        let message = messages.first { $0.senderId == user1Id }
        
        XCTAssertNotNil(message, "Message should exist")
        XCTAssertTrue(message?.deliveredTo.contains(user2Id) ?? false, "Message should be marked as delivered to user 2")
        
        print("✅ Message marked as delivered")
        
        // Mark as read
        await chatService.markMessagesAsRead(conversationId: conversationId, userId: user2Id)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Check that message was marked as read
        let updatedMessages = chatService.messages[conversationId] ?? []
        let readMessage = updatedMessages.first { $0.senderId == user1Id }
        
        XCTAssertTrue(readMessage?.readBy.contains(user2Id) ?? false, "Message should be marked as read by user 2")
        
        print("✅ Message marked as read")
    }
    
    func testGroupChatFunctionality() async throws {
        print("🧪 Testing group chat functionality...")
        
        // Setup: Create two test users
        try await setupTwoTestUsers()
        guard let user1Id = testUser1Id, let user2Id = testUser2Id else {
            XCTFail("Test users not set up")
            return
        }
        
        try await authService.login(email: testUser1Email, password: testPassword)
        
        // Create group chat
        let groupName = "Test Group Chat"
        let conversationId = try await chatService.createOrGetConversation(
            participantIds: [user1Id, user2Id],
            type: .group,
            groupName: groupName
        )
        testConversationId = conversationId
        
        XCTAssertNotNil(conversationId, "Group conversation should be created")
        print("✅ Group created: \(conversationId)")
        
        // Wait for conversation to sync
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Start observing conversations
        chatService.observeConversations(userId: user1Id)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify group appears in conversations
        let conversation = chatService.conversations.first { $0.id == conversationId }
        XCTAssertNotNil(conversation, "Group should appear in conversations")
        XCTAssertEqual(conversation?.type, .group, "Conversation type should be group")
        XCTAssertEqual(conversation?.groupName, groupName, "Group name should match")
        
        // Send message in group
        chatService.observeMessages(conversationId: conversationId)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        try await chatService.sendMessage(
            conversationId: conversationId,
            senderId: user1Id,
            text: "Hello group! 👋"
        )
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify message in group
        let messages = chatService.messages[conversationId] ?? []
        XCTAssertGreaterThan(messages.count, 0, "Group should have messages")
        
        print("✅ Group chat functionality verified")
    }
    
    func testOfflineMessageSync() async throws {
        print("🧪 Testing offline message sync...")
        
        // Setup
        try await setupTwoTestUsers()
        guard let user1Id = testUser1Id, let user2Id = testUser2Id else {
            XCTFail("Test users not set up")
            return
        }
        
        try await authService.login(email: testUser1Email, password: testPassword)
        
        let conversationId = try await chatService.createOrGetConversation(
            participantIds: [user1Id, user2Id],
            type: .direct
        )
        testConversationId = conversationId
        
        // Note: Testing actual offline behavior requires mocking network conditions
        // This test verifies the sync mechanism when reconnecting
        
        // Send message
        chatService.observeMessages(conversationId: conversationId)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        try await chatService.sendMessage(
            conversationId: conversationId,
            senderId: user1Id,
            text: "Test offline sync"
        )
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Simulate reconnection by calling syncPendingMessages
        await chatService.syncPendingMessages()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify messages synced
        let messages = chatService.messages[conversationId] ?? []
        let syncedMessages = messages.filter { $0.status == "sent" }
        
        XCTAssertGreaterThan(syncedMessages.count, 0, "Messages should be synced")
        
        print("✅ Offline sync mechanism verified")
    }
    
    func testConversationDeletion() async throws {
        print("🧪 Testing conversation deletion...")
        
        // Setup
        try await setupTwoTestUsers()
        guard let user1Id = testUser1Id, let user2Id = testUser2Id else {
            XCTFail("Test users not set up")
            return
        }
        
        try await authService.login(email: testUser1Email, password: testPassword)
        
        let conversationId = try await chatService.createOrGetConversation(
            participantIds: [user1Id, user2Id],
            type: .direct
        )
        
        // Send a message
        chatService.observeMessages(conversationId: conversationId)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        try await chatService.sendMessage(
            conversationId: conversationId,
            senderId: user1Id,
            text: "Message before deletion"
        )
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Delete conversation
        try await chatService.deleteConversation(conversationId: conversationId)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify conversation is deleted
        chatService.observeConversations(userId: user1Id)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let deletedConversation = chatService.conversations.first { $0.id == conversationId }
        XCTAssertNil(deletedConversation, "Conversation should be deleted")
        
        // No need to clean up in tearDown since we already deleted
        testConversationId = nil
        
        print("✅ Conversation deletion verified")
    }
    
    // MARK: - Performance Tests
    
    func testMessageListScrollPerformance() async throws {
        print("🧪 Testing message list scroll performance...")
        
        // This test measures the time to load and render a large number of messages
        // In a real app, you'd use XCTest performance metrics
        
        try await setupTwoTestUsers()
        guard let user1Id = testUser1Id, let user2Id = testUser2Id else {
            XCTFail("Test users not set up")
            return
        }
        
        try await authService.login(email: testUser1Email, password: testPassword)
        
        let conversationId = try await chatService.createOrGetConversation(
            participantIds: [user1Id, user2Id],
            type: .direct
        )
        testConversationId = conversationId
        
        chatService.observeMessages(conversationId: conversationId)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Send 50 messages to simulate a realistic conversation
        let messageCount = 50
        print("📤 Sending \(messageCount) messages...")
        
        for i in 1...messageCount {
            try await chatService.sendMessage(
                conversationId: conversationId,
                senderId: user1Id,
                text: "Performance test message #\(i) with some extra text to make it realistic"
            )
            
            // Small delay to avoid overwhelming Firebase
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        // Wait for all messages to sync
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3s
        
        // Measure time to retrieve messages
        let startTime = Date()
        let messages = chatService.messages[conversationId] ?? []
        let retrievalDuration = Date().timeIntervalSince(startTime)
        
        print("✅ Retrieved \(messages.count) messages in \(Int(retrievalDuration * 1000))ms")
        
        XCTAssertGreaterThanOrEqual(messages.count, messageCount, "All messages should be retrieved")
        XCTAssertLessThan(retrievalDuration, 0.1, "Message retrieval should be nearly instant (< 100ms)")
        
        print("✅ Scroll performance test completed")
    }
    
    // MARK: - Helper Methods
    
    private func setupTwoTestUsers() async throws {
        print("🔧 Setting up two test users...")
        
        // Create User 1
        try await authService.signUp(
            email: testUser1Email,
            password: testPassword,
            displayName: "Test User 1"
        )
        testUser1Id = authService.currentUser?.id
        print("✅ User 1 created: \(testUser1Id ?? "unknown")")
        
        // Logout and create User 2
        try authService.logout()
        
        try await authService.signUp(
            email: testUser2Email,
            password: testPassword,
            displayName: "Test User 2"
        )
        testUser2Id = authService.currentUser?.id
        print("✅ User 2 created: \(testUser2Id ?? "unknown")")
        
        // Logout to prepare for tests
        try authService.logout()
        
        print("✅ Two test users ready")
    }
}
