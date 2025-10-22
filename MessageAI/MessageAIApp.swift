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
import FirebaseFirestore
import FirebaseMessaging

@main
struct MessageAIApp: App {
    
    let modelContainer: ModelContainer
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Enable Firestore offline persistence
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        Firestore.firestore().settings = settings
        
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

