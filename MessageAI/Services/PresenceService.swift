//
//  PresenceService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import FirebaseFirestore
import Combine
import UIKit

@MainActor
class PresenceService: ObservableObject {
    private let db = Firestore.firestore()
    private var heartbeatTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    static let shared = PresenceService()
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Lifecycle Management
    
    private func setupNotifications() {
        // Observe app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppForeground()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppBackground()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppTerminate()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func startPresenceTracking(userId: String) async {
        print("👋 Starting presence tracking for user: \(userId)")
        await setOnlineStatus(userId: userId, isOnline: true)
        startHeartbeat(userId: userId)
    }
    
    func stopPresenceTracking(userId: String) async {
        print("👋 Stopping presence tracking for user: \(userId)")
        stopHeartbeat()
        await setOnlineStatus(userId: userId, isOnline: false)
    }
    
    // MARK: - Private Methods
    
    private func handleAppForeground() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        print("🟢 App entered foreground - setting online")
        await startPresenceTracking(userId: userId)
    }
    
    private func handleAppBackground() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        print("⚫ App entered background - setting offline")
        await stopPresenceTracking(userId: userId)
    }
    
    private func handleAppTerminate() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        print("🛑 App terminating - setting offline")
        await setOnlineStatus(userId: userId, isOnline: false)
    }
    
    private func setOnlineStatus(userId: String, isOnline: Bool) async {
        do {
            let presenceData: [String: Any] = [
                "isOnline": isOnline,
                "lastSeen": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("users").document(userId).updateData(presenceData)
            print("✅ Updated presence: \(isOnline ? "online" : "offline")")
        } catch {
            print("❌ Error updating presence: \(error.localizedDescription)")
        }
    }
    
    private func startHeartbeat(userId: String) {
        // Stop any existing timer
        stopHeartbeat()
        
        // Send heartbeat every 60 seconds (reduced from 30 for better performance)
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sendHeartbeat(userId: userId)
            }
        }
        
        // Ensure timer runs in common run loop modes (works during scrolling, etc.)
        if let timer = heartbeatTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("💓 Started heartbeat timer (60s interval)")
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        print("💔 Stopped heartbeat timer")
    }
    
    private func sendHeartbeat(userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "lastSeen": FieldValue.serverTimestamp()
            ])
            print("💓 Heartbeat sent")
        } catch {
            print("❌ Error sending heartbeat: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Observe User Presence

    func observeUserPresence(userId: String, completion: @escaping (Bool, Date?) -> Void) -> ListenerRegistration {
        print("👀 Observing presence for user: \(userId)")

        return db.collection("users").document(userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error observing presence: \(error.localizedDescription)")
                    return
                }

                guard let data = snapshot?.data() else {
                    completion(false, nil)
                    return
                }

                let isOnline = data["isOnline"] as? Bool ?? false
                let lastSeen = (data["lastSeen"] as? Timestamp)?.dateValue()

                completion(isOnline, lastSeen)
            }
    }

    // MARK: - Typing Indicators

    func startTyping(userId: String, conversationId: String) async {
        // Check rate limit
        let canSend = await RateLimiter.shared.canSendTypingIndicator()
        guard canSend else {
            print("⚠️ Typing indicator rate limited")
            return
        }

        do {
            let typingData: [String: Any] = [
                "userId": userId,
                "conversationId": conversationId,
                "isTyping": true,
                "lastTypingAt": FieldValue.serverTimestamp()
            ]

            try await db.collection("conversations")
                .document(conversationId)
                .collection("typing")
                .document(userId)
                .setData(typingData, merge: true)

            // Record typing indicator sent
            await RateLimiter.shared.recordTypingIndicatorSent()

            print("⌨️ Started typing in conversation: \(conversationId)")
        } catch {
            print("❌ Error starting typing: \(error.localizedDescription)")
        }
    }

    func stopTyping(userId: String, conversationId: String) async {
        do {
            let typingData: [String: Any] = [
                "isTyping": false,
                "lastTypingAt": FieldValue.serverTimestamp()
            ]

            try await db.collection("conversations")
                .document(conversationId)
                .collection("typing")
                .document(userId)
                .setData(typingData, merge: true)

            print("⌨️ Stopped typing in conversation: \(conversationId)")
        } catch {
            print("❌ Error stopping typing: \(error.localizedDescription)")
        }
    }

    func observeTypingStatus(conversationId: String, currentUserId: String, completion: @escaping ([TypingStatus]) -> Void) -> ListenerRegistration {
        print("👀 Observing typing status for conversation: \(conversationId)")

        return db.collection("conversations")
            .document(conversationId)
            .collection("typing")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error observing typing status: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let typingStatuses = documents.compactMap { doc -> TypingStatus? in
                    do {
                        let status = try doc.data(as: TypingStatus.self)
                        // Filter out current user and expired statuses
                        if status.id != currentUserId && status.isActivelyTyping {
                            return status
                        }
                        return nil
                    } catch {
                        print("❌ Error decoding typing status: \(error.localizedDescription)")
                        return nil
                    }
                }

                completion(typingStatuses)
            }
    }

    deinit {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}

