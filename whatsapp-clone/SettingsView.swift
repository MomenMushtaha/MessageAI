//
//  SettingsView.swift
//  whatsapp-clone
//
//  Created by Momen Mush on 2025-10-21.
//

import SwiftUI

struct SettingsView: View {
    @State private var aiService = AIService()
    
    var body: some View {
        NavigationStack {
            List {
                Section("AI Assistant") {
                    HStack {
                        Image(systemName: "brain.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Status")
                                .font(.headline)
                            Text(aiService.modelStatusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Circle()
                            .fill(aiService.isModelAvailable ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                    }
                    
                    if !aiService.isModelAvailable {
                        Button("Open Settings") {
                            // Settings link - this is a mock implementation
                            // In a real app, you would open system settings
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("This app uses Apple's on-device AI to provide intelligent responses while keeping your conversations private.")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}