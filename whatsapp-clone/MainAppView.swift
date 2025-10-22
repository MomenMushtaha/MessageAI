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
    @State private var showSignUp = false
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Show Chat List when authenticated
                ChatListView()
            } else {
                // Show Login/SignUp flow
                if showSignUp {
                    SignUpView(
                        onShowLogin: {
                            withAnimation {
                                showSignUp = false
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                } else {
                    LoginView(
                        onShowSignUp: {
                            withAnimation {
                                showSignUp = true
                            }
                        }
                    )
                    .transition(.move(edge: .leading))
                }
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .animation(.easeInOut, value: showSignUp)
    }
}

#Preview {
    MainAppView()
}