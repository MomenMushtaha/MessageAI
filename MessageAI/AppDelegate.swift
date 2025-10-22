//
//  AppDelegate.swift
//  MessageAI
//
//  Created by Momen Mush on 2025-10-22.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Firebase is already configured in MessageAIApp.init()
        // This AppDelegate is here to satisfy Firebase's expectations

        // Set up notification delegates
        Task { @MainActor in
            let pushService = PushNotificationService.shared

            // Set MessagingDelegate for FCM token updates
            Messaging.messaging().delegate = pushService

            // Set UNUserNotificationCenterDelegate for notification handling
            UNUserNotificationCenter.current().delegate = pushService

            // Request notification permissions
            let granted = await pushService.requestPermission()
            if granted {
                print("✅ Push notifications enabled")
            } else {
                print("⚠️ Push notifications disabled by user")
            }
        }

        return true
    }
    
    // MARK: - Remote Notifications (for future push notification support)
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Will be used when implementing push notifications
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

