//
//  LoginView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    
    var onLogin: () -> Void
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
                
                // Login Button
                Button(action: {
                    isLoading = true
                    // Simulate login delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isLoading = false
                        onLogin()
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
}

#Preview {
    LoginView(onLogin: {}, onShowSignUp: {})
}

