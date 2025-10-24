//
//  ServerInferenceProvider.swift
//  MessageAI
//
//  Server-side inference using OpenAI + RAG (Pinecone)
//

import Foundation

class ServerInferenceProvider: InferenceProvider {
    let name = "Server"
    var isAvailable: Bool {
        // Check network connectivity
        return NetworkMonitor.shared.isConnected
    }

    private let aiService = AIService.shared

    func supports(_ feature: InferenceFeature) -> Bool {
        // Server supports all features when online
        switch feature {
        case .summarize, .actionItems, .decisions, .priority, .search, .translate:
            return true
        case .voiceTranscription, .languageDetection, .toxicityCheck, .localSearch, .microSummary, .embeddings:
            return false // Server can do these but we prefer CoreML
        }
    }

    // MARK: - Core Features

    func summarize(convId: String, messages: [Message], window: String, style: String) async throws -> InferenceSummaryResult {
        let response = try await aiService.summarize(convId: convId, window: window, style: style)

        return InferenceSummaryResult(
            summary: response.summary,
            sources: response.sources,
            onDevice: false,
            model: "gpt-4o-mini + RAG"
        )
    }

    func extractActions(convId: String, messages: [Message]) async throws -> [AIAction] {
        let response = try await aiService.actionItems(convId: convId)
        return response.actions
    }

    func detectPriority(message: Message) async throws -> InferencePriorityResult {
        let response = try await aiService.priority(convId: message.conversationId, msgId: message.id)

        return InferencePriorityResult(
            priority: response.priority,
            isUrgent: response.priority == "high",
            confidence: 0.85,
            onDevice: false
        )
    }

    func search(query: String, messages: [Message]) async throws -> [Message] {
        // Use legacy semantic search for now
        // TODO: Integrate with /search Cloud Function endpoint
        return try await aiService.semanticSearch(query: query, messages: messages)
    }

    func translate(text: String, targetLang: String) async throws -> String {
        // TODO: Call /translate endpoint when implemented
        throw InferenceError.featureNotSupported
    }

    // MARK: - On-Device (Not Supported)

    func transcribeAudio(data: Data) async throws -> String {
        throw InferenceError.featureNotSupported
    }

    func detectLanguage(text: String) async throws -> String {
        throw InferenceError.featureNotSupported
    }

    func checkToxicity(text: String) async throws -> ToxicityResult {
        throw InferenceError.featureNotSupported
    }

    func generateEmbedding(text: String) async throws -> [Float] {
        throw InferenceError.featureNotSupported
    }
}
