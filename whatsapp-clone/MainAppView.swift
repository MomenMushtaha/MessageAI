//
//  MainAppView.swift
//  whatsapp-clone
//
//  Created by Momen Mush on 2025-10-21.
//

import SwiftUI
import SwiftData

struct MainAppView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome = true
    @State private var showSettings = false
    
    var body: some View {
        Group {
            if showWelcome && !hasSeenWelcome {
                WelcomeView(showWelcome: $showWelcome)
                    .onDisappear {
                        hasSeenWelcome = true
                    }
            } else {
                ContentView()
                    .sheet(isPresented: $showSettings) {
                        SettingsView()
                    }
            }
        }
        .onAppear {
            if hasSeenWelcome {
                showWelcome = false
            }
        }
    }
}

#Preview {
    MainAppView()
        .modelContainer(for: Message.self, inMemory: true)
}