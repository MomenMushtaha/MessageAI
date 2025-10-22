//
//  MainAppView.swift
//  whatsapp-clone
//
//  Created by Momen Mush on 2025-10-21.
//

import SwiftUI
import SwiftData

struct MainAppView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var chatService = ChatService.shared
    @StateObject private var notificationService = NotificationService.shared
    @State private var showSignUp = false
    @State private var hasShownInitialSync = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if authService.isAuthenticated {
                    // Show Chat List when authenticated
                    ChatListView()
                        .environmentObject(authService)
                        .environmentObject(chatService)
                        .environmentObject(networkMonitor)
                } else {
                    // Show Login/SignUp flow
                    if showSignUp {
                        SignUpView(
                            onShowLogin: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSignUp = false
                                }
                            }
                        )
                        .transition(.opacity)
                    } else {
                        LoginView(
                            onShowSignUp: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSignUp = true
                                }
                            }
                        )
                        .transition(.opacity)
                    }
                }
            }
            
            // Offline Banner
            OfflineBanner(isConnected: networkMonitor.isConnected)
                .animation(.easeInOut, value: networkMonitor.isConnected)
            
            // In-App Notification Banner
            if authService.isAuthenticated {
                InAppNotificationBannerContainer(
                    onNotificationTapped: { conversationId in
                        // Handle navigation to conversation
                        print("📱 Navigate to conversation: \(conversationId)")
                    }
                )
            }
        }
        .onChange(of: networkMonitor.isConnected) { oldValue, newValue in
            if !oldValue && newValue && authService.isAuthenticated {
                // Just came back online and user is authenticated
                print("🌐 Back online! Syncing pending messages...")
                Task {
                    await chatService.syncPendingMessages()
                }
            }
        }
        .onAppear {
            if authService.isAuthenticated && networkMonitor.isConnected && !hasShownInitialSync {
                // Sync pending messages on app launch
                hasShownInitialSync = true
                Task {
                    await chatService.syncPendingMessages()
                }
            }
        }
    }
}

#Preview {
    MainAppView()
}