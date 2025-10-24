//
//  OpenAISettingsView.swift
//  MessageAI
//
//  OpenAI API Key configuration for translation services
//

import SwiftUI

struct OpenAISettingsView: View {
    @AppStorage("openai_api_key") private var apiKey: String = ""
    @State private var tempApiKey: String = ""
    @State private var showSaved = false
    @State private var isValidating = false
    @State private var validationResult: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.blue)
                            Text("OpenAI API Key")
                                .fontWeight(.medium)
                        }
                        
                        SecureField("sk-...", text: $tempApiKey)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                        
                        Text("Enter your OpenAI API key to enable translation services")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Translation Service")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your API key is stored securely on this device and is only used for translation requests.")
                        
                        if !apiKey.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("API key configured")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    HStack {
                        Button("Save") {
                            saveApiKey()
                        }
                        .disabled(tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Spacer()
                        
                        Button("Test Connection") {
                            Task {
                                await testConnection()
                            }
                        }
                        .disabled(tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
                        
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if let result = validationResult {
                        HStack {
                            Image(systemName: result.contains("✅") ? "checkmark.circle" : "xmark.circle")
                                .foregroundStyle(result.contains("✅") ? .green : .red)
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Translation Priority")
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "1.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Foundation Models")
                                Spacer()
                                Text("On-device (iOS 26.0+)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "2.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("OpenAI API")
                                Spacer()
                                Text("Cloud-based")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Text("Your app will automatically use the best available translation service.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("How Translation Works")
                }
                
                Section {
                    Link("Get OpenAI API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    Link("OpenAI Pricing", destination: URL(string: "https://openai.com/pricing")!)
                } header: {
                    Text("Resources")
                }
            }
            .navigationTitle("Translation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                tempApiKey = apiKey
            }
            .alert("API Key Saved", isPresented: $showSaved) {
                Button("OK") { }
            } message: {
                Text("Your OpenAI API key has been saved successfully.")
            }
        }
    }
    
    private func saveApiKey() {
        let cleanKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = cleanKey
        showSaved = true
        
        // Notify AIService to reload with new key
        NotificationCenter.default.post(name: .openAIKeyUpdated, object: cleanKey)
    }
    
    private func testConnection() async {
        isValidating = true
        validationResult = nil
        
        defer {
            isValidating = false
        }
        
        do {
            let testKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let isValid = try await validateOpenAIKey(testKey)
            
            await MainActor.run {
                if isValid {
                    validationResult = "✅ API key is valid"
                } else {
                    validationResult = "❌ Invalid API key"
                }
            }
        } catch {
            await MainActor.run {
                validationResult = "❌ Connection failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func validateOpenAIKey(_ key: String) async throws -> Bool {
        guard !key.isEmpty, key.hasPrefix("sk-") else {
            return false
        }
        
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        
        return false
    }
}

#Preview {
    OpenAISettingsView()
}