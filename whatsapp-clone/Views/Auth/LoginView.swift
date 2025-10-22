//
//  LoginView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    
    var onShowSignUp: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo/Title
                VStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                    
                    Text("MessageAI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Welcome back!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
                
                // Input Fields
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                // Error Message
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Login Button
                Button(action: {
                    Task {
                        await handleLogin()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Log In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(email.isEmpty || password.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(email.isEmpty || password.isEmpty || isLoading)
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    
                    Button("Sign Up") {
                        onShowSignUp()
                    }
                    .fontWeight(.semibold)
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 60)
            .navigationBarHidden(true)
        }
    }
    
    private func handleLogin() async {
        isLoading = true
        authService.errorMessage = nil
        
        do {
            try await authService.login(email: email, password: password)
        } catch {
            showError = true
        }
        
        isLoading = false
    }
}

#Preview {
    LoginView(onShowSignUp: {})
}

