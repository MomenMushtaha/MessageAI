//
//  WelcomeView.swift
//  whatsapp-clone
//
//  Created by Momen Mush on 2025-10-21.
//

import SwiftUI

struct WelcomeView: View {
    @Binding var showWelcome: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon and Title
            VStack(spacing: 20) {
                Image(systemName: "message.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue.gradient)
                
                Text("AI Messaging")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Chat with Apple's on-device AI assistant")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "brain.fill", title: "On-Device AI", description: "Powered by Apple Intelligence")
                FeatureRow(icon: "lock.shield.fill", title: "Private & Secure", description: "Your conversations stay on your device")
                FeatureRow(icon: "bolt.fill", title: "Fast Responses", description: "Instant AI-powered replies")
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Get Started Button
            Button(action: {
                withAnimation(.spring()) {
                    showWelcome = false
                }
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.gradient)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    WelcomeView(showWelcome: .constant(true))
}