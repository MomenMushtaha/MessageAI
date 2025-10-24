//
//  PushNotificationService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import Combine
import FirebaseMessaging
import FirebaseDatabase
import UserNotifications
import UIKit

@MainActor
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    private let db = Database.database().reference()
    @Published var fcmToken: String?
    @Published var notificationPermissionGranted = false

    private override init() {
        super.init()
    }

    // MARK: - Permission Request

    /// Request notification permissions from user
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            notificationPermissionGranted = granted

            if granted {
                print("✅ Notification permission granted")
                await registerForRemoteNotifications()
            } else {
                print("❌ Notification permission denied")
            }

            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - FCM Token Registration

    /// Register for remote notifications and get FCM token
    func registerForRemoteNotifications() async {
        // Register for remote notifications on main thread
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }

        // Get FCM token
        do {
            let token = try await Messaging.messaging().token()
            fcmToken = token
            print("✅ FCM Token received: \(token)")

            // Store token in Firestore
            if let userId = AuthService.shared.currentUser?.id {
                await storeToken(token, for: userId)
            }
        } catch {
            print("❌ Error getting FCM token: \(error.localizedDescription)")
        }
    }

    /// Store FCM token in Realtime Database for this user
    private func storeToken(_ token: String, for userId: String) async {
        do {
            let tokenData: [String: Any] = [
                "token": token,
                "createdAt": ServerValue.timestamp(),
                "platform": "iOS",
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            ]

            // Store in user's tokens subcollection
            try await db.child("users")
                .child(userId)
                .child("fcmTokens")
                .child(token)
                .setValue(tokenData)

            print("✅ FCM token stored in Realtime Database")
        } catch {
            print("❌ Error storing FCM token: \(error.localizedDescription)")
        }
    }

    /// Delete FCM token (e.g., on logout)
    func deleteToken(for userId: String) async {
        guard let token = fcmToken else { return }

        do {
            try await db.child("users")
                .child(userId)
                .child("fcmTokens")
                .child(token)
                .removeValue()

            // Delete from FCM
            try await Messaging.messaging().deleteToken()

            fcmToken = nil
            print("✅ FCM token deleted")
        } catch {
            print("❌ Error deleting FCM token: \(error.localizedDescription)")
        }
    }

    // MARK: - Token Refresh

    /// Handle FCM token refresh
    func handleTokenRefresh(_ newToken: String) {
        fcmToken = newToken
        print("🔄 FCM token refreshed: \(newToken)")

        // Update in Firestore
        if let userId = AuthService.shared.currentUser?.id {
            Task {
                await storeToken(newToken, for: userId)
            }
        }
    }

    // MARK: - Badge Management

    /// Update app badge count
    func updateBadgeCount(_ count: Int) async {
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }

    /// Clear badge count
    func clearBadge() async {
        await updateBadgeCount(0)
    }
}

// MARK: - MessagingDelegate

extension PushNotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 Firebase registration token refreshed")

        if let token = fcmToken {
            Task { @MainActor in
                handleTokenRefresh(token)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📬 Received notification in foreground")

        // Show banner, badge, and play sound
        completionHandler([.banner, .badge, .sound])
    }

    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("👆 User tapped notification")

        let userInfo = response.notification.request.content.userInfo

        // Extract conversation ID from notification
        if let conversationId = userInfo["conversationId"] as? String {
            print("🔗 Opening conversation: \(conversationId)")

            Task { @MainActor in
                // Post notification to navigate to conversation
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenConversation"),
                    object: nil,
                    userInfo: ["conversationId": conversationId]
                )
            }
        }

        completionHandler()
    }
}
