//
//  PresenceService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import FirebaseDatabase
import Combine
import UIKit

@MainActor
class PresenceService: ObservableObject {
    private let db = Database.database().reference()
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
                "lastSeen": ServerValue.timestamp()
            ]
            
            try await db.child("users").child(userId).updateChildValues(presenceData)
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
            try await db.child("users").child(userId).updateChildValues([
                "lastSeen": ServerValue.timestamp()
            ])
            print("💓 Heartbeat sent")
        } catch {
            print("❌ Error sending heartbeat: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Observe User Presence

    func observeUserPresence(userId: String, completion: @escaping (Bool, Date?) -> Void) -> DatabaseHandle {
        print("👀 Observing presence for user: \(userId)")

        return db.child("users").child(userId).observe(.value, with: { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                completion(false, nil)
                return
            }

            let isOnline = data["isOnline"] as? Bool ?? false
            let lastSeen: Date? = {
                if let timestamp = data["lastSeen"] as? TimeInterval {
                    return Date(timeIntervalSince1970: timestamp / 1000)
                }
                return nil
            }()

            completion(isOnline, lastSeen)
        })
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
                "lastTypingAt": ServerValue.timestamp()
            ]

            try await db.child("conversations")
                .child(conversationId)
                .child("typing")
                .child(userId)
                .setValue(typingData)

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
                "lastTypingAt": ServerValue.timestamp()
            ]

            try await db.child("conversations")
                .child(conversationId)
                .child("typing")
                .child(userId)
                .updateChildValues(typingData)

            print("⌨️ Stopped typing in conversation: \(conversationId)")
        } catch {
            print("❌ Error stopping typing: \(error.localizedDescription)")
        }
    }

    func observeTypingStatus(conversationId: String, currentUserId: String, completion: @escaping ([TypingStatus]) -> Void) -> DatabaseHandle {
        print("👀 Observing typing status for conversation: \(conversationId)")

        return db.child("conversations")
            .child(conversationId)
            .child("typing")
            .observe(.value, with: { snapshot in
                guard let typingDict = snapshot.value as? [String: [String: Any]] else {
                    completion([])
                    return
                }

                let typingStatuses = typingDict.compactMap { (userId, data) -> TypingStatus? in
                    guard userId != currentUserId,
                          let isTyping = data["isTyping"] as? Bool,
                          isTyping,
                          let lastTypingTimestamp = data["lastTypingAt"] as? TimeInterval else {
                        return nil
                    }
                    
                    let lastTypingAt = Date(timeIntervalSince1970: lastTypingTimestamp / 1000)
                    
                    // Check if typing is still active (within last 5 seconds)
                    let isActive = Date().timeIntervalSince(lastTypingAt) < 5
                    
                    if isActive {
                        return TypingStatus(
                            id: userId,
                            conversationId: conversationId,
                            isTyping: isTyping,
                            lastTypingAt: lastTypingAt
                        )
                    }
                    return nil
                }

                completion(typingStatuses)
            })
    }

    deinit {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}

