//
//  whatsapp_cloneApp.swift
//  whatsapp-clone
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
struct whatsapp_cloneApp: App {
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Enable Firestore offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Message.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
        .modelContainer(sharedModelContainer)
    }
}
