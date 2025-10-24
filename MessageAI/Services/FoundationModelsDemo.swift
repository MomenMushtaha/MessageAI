//
//  FoundationModelsDemo.swift
//  MessageAI
//
//  Demonstrates translation functionality using the inference system
//  Ready for Foundation Models when APIs become available
//

import SwiftUI

@available(iOS 18.1, *)
struct FoundationModelsDemo: View {
    @State private var inputText = "Hello, how are you today? I hope you're having a great day!"
    @State private var translatedText = ""
    @State private var targetLanguage = "es"
    @State private var isTranslating = false
    @State private var errorMessage = ""
    
    private let inferenceManager = InferenceManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status indicator
                statusView
                
                // Input text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text to translate:")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Language selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Translate to:")
                        .font(.headline)
                    
                    Picker("Target Language", selection: $targetLanguage) {
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                        Text("Italian").tag("it")
                        Text("Portuguese").tag("pt")
                        Text("Russian").tag("ru")
                        Text("Japanese").tag("ja")
                        Text("Korean").tag("ko")
                        Text("Chinese").tag("zh")
                        Text("Arabic").tag("ar")
                    }
                    .pickerStyle(.menu)
                }
                
                // Translate button
                Button(action: {
                    Task {
                        await translateText()
                    }
                }) {
                    HStack {
                        if isTranslating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Translate with Inference System")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isTranslating || inputText.isEmpty)
                
                // Translation result
                if !translatedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ScrollView {
                            Text(cleanedTranslation)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 300)
                    }
                }
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Translation Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var statusView: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 12, height: 12)
                
                Text("Translation System Status:")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("⚠️ Foundation Models APIs not yet available")
                        .foregroundColor(.orange)
                    Spacer()
                }
                
                HStack {
                    Text("✅ Inference system ready with fallbacks")
                        .foregroundColor(.green)
                    Spacer()
                }
                
                HStack {
                    Text("🔄 Will auto-upgrade when Apple releases APIs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    @MainActor
    private func translateText() async {
        guard !inputText.isEmpty else { return }
        
        isTranslating = true
        errorMessage = ""
        translatedText = ""
        
        do {
            let result = try await inferenceManager.translate(text: inputText, targetLang: targetLanguage)
            translatedText = result
            
            // Log success with provider info
            print("✅ Translation completed using inference system")
        } catch {
            errorMessage = "Translation failed: \(error.localizedDescription)"
            print("❌ Translation error: \(error)")
        }
        
        isTranslating = false
    }
    
    // Extract clean translation text from server response
    private var cleanedTranslation: String {
        // Remove the explanatory text and just show actual translation
        if translatedText.contains("🌐 Translation Service Ready") {
            // For placeholder responses, show a simple message
            return "Translation service is configured and ready. Add an OpenAI API key or wait for Foundation Models to get actual translations."
        } else if translatedText.contains("[Foundation Models Translation to") {
            // Extract just the target language info for Foundation Models placeholder
            let lines = translatedText.components(separatedBy: "\n")
            if let targetLine = lines.first(where: { $0.contains("[Foundation Models Translation to") }) {
                return targetLine.replacingOccurrences(of: "🌐 ", with: "")
            }
        } else if !translatedText.contains("Original text:") && !translatedText.contains("⚠️") && !translatedText.contains("🌐") {
            // If it's a clean translation result (from actual OpenAI), show it as-is
            return translatedText
        }
        
        // Fallback: try to extract any clean translation lines
        let lines = translatedText.components(separatedBy: "\n").filter { line in
            !line.contains("Original text:") &&
            !line.contains("Target language:") &&
            !line.contains("Translation requires:") &&
            !line.contains("OpenAI API") &&
            !line.contains("Foundation Models") &&
            !line.contains("⚠️") &&
            !line.contains("🌐") &&
            !line.contains("Your app is") &&
            !line.contains("The translation") &&
            !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// iOS 18.0 and below fallback
struct FoundationModelsDemoFallback: View {
    @State private var inputText = "Hello, how are you today?"
    @State private var translatedText = ""
    @State private var targetLanguage = "es"
    @State private var isTranslating = false
    @State private var errorMessage = ""
    
    private let inferenceManager = InferenceManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // iOS version notice
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Translation Demo")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Running on iOS 18.0 or earlier")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Input text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text to translate:")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Language selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Translate to:")
                        .font(.headline)
                    
                    Picker("Target Language", selection: $targetLanguage) {
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                        Text("Italian").tag("it")
                        Text("Chinese").tag("zh")
                    }
                    .pickerStyle(.menu)
                }
                
                // Translate button
                Button(action: {
                    Task {
                        await translateText()
                    }
                }) {
                    HStack {
                        if isTranslating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Translate")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isTranslating || inputText.isEmpty)
                
                // Translation result
                if !translatedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ScrollView {
                            Text(cleanedTranslation)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @MainActor
    private func translateText() async {
        guard !inputText.isEmpty else { return }
        
        isTranslating = true
        errorMessage = ""
        translatedText = ""
        
        do {
            let result = try await inferenceManager.translate(text: inputText, targetLang: targetLanguage)
            translatedText = result
            
            print("✅ Translation completed")
        } catch {
            errorMessage = "Translation failed: \(error.localizedDescription)"
            print("❌ Translation error: \(error)")
        }
        
        isTranslating = false
    }
    
    // Extract clean translation text from server response
    private var cleanedTranslation: String {
        // Remove the explanatory text and just show actual translation
        if translatedText.contains("🌐 Translation Service Ready") {
            // For placeholder responses, show a simple message
            return "Translation service is configured and ready. Add an OpenAI API key or wait for Foundation Models to get actual translations."
        } else if translatedText.contains("[Foundation Models Translation to") {
            // Extract just the target language info for Foundation Models placeholder
            let lines = translatedText.components(separatedBy: "\n")
            if let targetLine = lines.first(where: { $0.contains("[Foundation Models Translation to") }) {
                return targetLine.replacingOccurrences(of: "🌐 ", with: "")
            }
        } else if !translatedText.contains("Original text:") && !translatedText.contains("⚠️") && !translatedText.contains("🌐") {
            // If it's a clean translation result (from actual OpenAI), show it as-is
            return translatedText
        }
        
        // Fallback: try to extract any clean translation lines
        let lines = translatedText.components(separatedBy: "\n").filter { line in
            !line.contains("Original text:") &&
            !line.contains("Target language:") &&
            !line.contains("Translation requires:") &&
            !line.contains("OpenAI API") &&
            !line.contains("Foundation Models") &&
            !line.contains("⚠️") &&
            !line.contains("🌐") &&
            !line.contains("Your app is") &&
            !line.contains("The translation") &&
            !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    if #available(iOS 18.1, *) {
        FoundationModelsDemo()
    } else {
        FoundationModelsDemoFallback()
    }
}
