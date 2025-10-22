//
//  MainAppView.swift
//  whatsapp-clone
//
//  Created by Momen Mush on 2025-10-21.
//

import SwiftUI
import SwiftData

struct MainAppView: View {
    // Mock authentication state (will be replaced with real AuthService in Step 2)
    @State private var isAuthenticated = false
    @State private var showSignUp = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                // Show Chat List when authenticated
                ChatListView(onLogout: {
                    withAnimation {
                        isAuthenticated = false
                    }
                })
            } else {
                // Show Login/SignUp flow
                if showSignUp {
                    SignUpView(
                        onSignUp: {
                            withAnimation {
                                isAuthenticated = true
                                showSignUp = false
                            }
                        },
                        onShowLogin: {
                            withAnimation {
                                showSignUp = false
                            }
                        }
                    )
                } else {
                    LoginView(
                        onLogin: {
                            withAnimation {
                                isAuthenticated = true
                            }
                        },
                        onShowSignUp: {
                            withAnimation {
                                showSignUp = true
                            }
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    MainAppView()
        .modelContainer(for: Message.self, inMemory: true)
}