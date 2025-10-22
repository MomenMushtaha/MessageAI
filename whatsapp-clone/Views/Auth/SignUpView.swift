//
//  SignUpView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct SignUpView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    
    var onShowLogin: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo/Title
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                    
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Join MessageAI today!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
                
                // Input Fields
                VStack(spacing: 16) {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords don't match")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Error Message
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Sign Up Button
                Button(action: {
                    Task {
                        await handleSignUp()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!isFormValid || isLoading)
                
                // Login Link
                HStack {
                    Text("Already have an account?")
                        .foregroundStyle(.secondary)
                    
                    Button("Log In") {
                        onShowLogin()
                    }
                    .fontWeight(.semibold)
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 40)
            .navigationBarHidden(true)
        }
    }
    
    private var isFormValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }
    
    private func handleSignUp() async {
        isLoading = true
        authService.errorMessage = nil
        
        do {
            try await authService.signUp(email: email, password: password, displayName: displayName)
        } catch {
            showError = true
        }
        
        isLoading = false
    }
}

#Preview {
    SignUpView(onShowLogin: {})
}

