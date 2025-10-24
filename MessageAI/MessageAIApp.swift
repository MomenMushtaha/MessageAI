//
//  MessageAIApp.swift
//  MessageAI
//
//  Created by Momen Mush on 2025-10-21.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase
import FirebaseMessaging
import FirebaseAnalytics

@main
struct MessageAIApp: App {
    
    // Connect AppDelegate to satisfy Firebase requirements
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let modelContainer: ModelContainer
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Enable Realtime Database offline persistence
        Database.database().isPersistenceEnabled = true
        
        // Configure SwiftData
        do {
            modelContainer = try ModelContainer(for: LocalMessage.self, LocalConversation.self)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .onAppear {
                    // Initialize LocalStorageService with the model context
                    let context = ModelContext(modelContainer)
                    LocalStorageService.initialize(with: context)
                }
        }
        .modelContainer(modelContainer)
    }
}

