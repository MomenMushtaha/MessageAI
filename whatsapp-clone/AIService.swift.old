//
//  AIService.swift
//  whatsapp-clone
//
//  Created by Momen Mush on 2025-10-21.
//

import Foundation
// Note: FoundationModels is only available on iOS 18.1+ with Apple Intelligence
// For now, we'll create a mock implementation

@Observable
class AIService {
    private var isSimulating = true
    
    var isModelAvailable: Bool {
        // Mock implementation - in real app this would check SystemLanguageModel.default.availability
        return true
    }
    
    var modelStatusMessage: String {
        if isModelAvailable {
            return "AI Assistant Ready (Mock)"
        } else {
            return "Please enable Apple Intelligence in Settings"
        }
    }
    
    init() {
        setupSession()
    }
    
    private func setupSession() {
        // Mock setup - in real app this would initialize LanguageModelSession
    }
    
    func generateResponse(to userMessage: String) async throws -> String {
        // Mock AI response - simulate processing time
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        return generateMockResponse(to: userMessage)
    }
    
    func generateStreamingResponse(to userMessage: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = generateMockResponse(to: userMessage)
                    let words = response.components(separatedBy: " ")
                    var currentResponse = ""
                    
                    for word in words {
                        currentResponse += (currentResponse.isEmpty ? "" : " ") + word
                        continuation.yield(currentResponse)
                        try await Task.sleep(nanoseconds: 200_000_000) // 200ms delay between words
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func generateMockResponse(to userMessage: String) -> String {
        let lowerMessage = userMessage.lowercased()
        
        if lowerMessage.contains("hello") || lowerMessage.contains("hi") {
            return "Hello! How can I help you today?"
        } else if lowerMessage.contains("how are you") {
            return "I'm doing great! Thanks for asking. I'm here to help with any questions you might have."
        } else if lowerMessage.contains("what") && lowerMessage.contains("name") {
            return "I'm your AI assistant! I'm here to help answer questions and have conversations with you."
        } else if lowerMessage.contains("weather") {
            return "I don't have access to real-time weather data, but I'd be happy to help you with other topics!"
        } else if lowerMessage.contains("time") {
            return "I can see it's currently \(Date().formatted(date: .omitted, time: .shortened)). How can I help you?"
        } else if lowerMessage.contains("help") {
            return "I'm here to help! You can ask me questions, have a conversation, or just chat about whatever interests you."
        } else {
            let responses = [
                "That's interesting! Could you tell me more about that?",
                "I understand what you're saying. How can I help you with that?",
                "Thanks for sharing that with me. What would you like to know?",
                "That's a great point! I'm here if you have any questions about it.",
                "I appreciate you sharing that. Is there anything specific I can help you with?"
            ]
            return responses.randomElement() ?? "I'm here to help! What would you like to talk about?"
        }
    }
}

enum AIServiceError: LocalizedError {
    case modelNotAvailable
    case modelBusy
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "AI model is not available"
        case .modelBusy:
            return "AI is currently processing another request"
        }
    }
}