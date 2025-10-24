//
//  CoreMLInferenceProvider.swift
//  MessageAI
//
//  On-device inference using CoreML models
//  - Voice transcription (Whisper)
//  - Language detection
//  - Toxicity classification
//  - Local embeddings
//  - Micro-summary (offline fallback)
//

import Foundation
import CoreML
import NaturalLanguage

class CoreMLInferenceProvider: InferenceProvider {
    let name = "CoreML"
    var isAvailable: Bool {
        // Check device capabilities
        return true // Available on all iOS devices
    }

    // Model references (lazy loaded)
    private var whisperModel: MLModel?
    private var embeddingModel: MLModel?
    private var toxicityModel: MLModel?
    private var summaryModel: MLModel?

    // Natural Language framework (built-in)
    private let languageRecognizer = NLLanguageRecognizer()
    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])

    // Local vector store for cached messages
    private var localVectorStore: LocalVectorStore?

    init() {
        print("🧠 Initializing CoreML provider...")
        // Models will be loaded on-demand to save memory
    }

    func supports(_ feature: InferenceFeature) -> Bool {
        switch feature {
        case .voiceTranscription:
            return true // Whisper CoreML
        case .languageDetection:
            return true // NaturalLanguage framework
        case .toxicityCheck:
            return true // Classification model
        case .localSearch:
            return true // Local vector store
        case .microSummary:
            return true // Small summary model
        case .embeddings:
            return true // Embedding model
        case .summarize, .actionItems, .decisions, .priority, .search, .translate:
            return false // Prefer server for these
        }
    }

    // MARK: - Core Features (Limited On-Device Support)

    func summarize(convId: String, messages: [Message], window: String, style: String) async throws -> InferenceSummaryResult {
        // Micro-summary: last 10-20 messages only
        print("📱 Generating micro-summary (on-device, limited context)")

        let recentMessages = Array(messages.suffix(20))
        let text = recentMessages.map { $0.text }.joined(separator: " ")

        // Use simple extractive summary (no model needed for MVP)
        let summary = generateExtractiveSummary(text: text, maxSentences: 3)

        return InferenceSummaryResult(
            summary: "⚠️ Quick device summary (limited context):\n\n\(summary)",
            sources: recentMessages.map { $0.id },
            onDevice: true,
            model: "extractive-summary-local"
        )
    }

    func extractActions(convId: String, messages: [Message]) async throws -> [AIAction] {
        // Not implemented on-device (too complex)
        throw InferenceError.featureNotSupported
    }

    func detectPriority(message: Message) async throws -> InferencePriorityResult {
        // Simple keyword-based priority detection
        let text = message.text.lowercased()
        let urgentKeywords = ["urgent", "asap", "critical", "emergency", "immediately", "now", "deadline"]
        let isUrgent = urgentKeywords.contains { text.contains($0) }

        return InferencePriorityResult(
            priority: isUrgent ? "high" : "medium",
            isUrgent: isUrgent,
            confidence: 0.6, // Lower confidence for keyword-based
            onDevice: true
        )
    }

    func search(query: String, messages: [Message]) async throws -> [Message] {
        // Local semantic search using embeddings
        print("🔍 Local semantic search")

        // Initialize vector store if needed
        if localVectorStore == nil {
            localVectorStore = LocalVectorStore()
            // Index messages
            for message in messages {
                let embedding = try await generateEmbedding(text: message.text)
                await localVectorStore?.index(messageId: message.id, embedding: embedding)
            }
        }

        // Generate query embedding
        let queryEmbedding = try await generateEmbedding(text: query)

        // Find similar messages
        let results = await localVectorStore?.search(queryEmbedding: queryEmbedding, topK: 10) ?? []

        return messages.filter { msg in results.contains(msg.id) }
    }

    func translate(text: String, targetLang: String) async throws -> String {
        // Could use on-device translation models, but not implemented yet
        throw InferenceError.featureNotSupported
    }

    // MARK: - On-Device Features

    func transcribeAudio(data: Data) async throws -> String {
        print("🎤 Transcribing audio on-device with Whisper")

        // Load Whisper model if needed
        if whisperModel == nil {
            whisperModel = try await loadWhisperModel()
        }

        guard let model = whisperModel else {
            throw InferenceError.modelNotLoaded
        }

        // Process audio with Whisper
        let transcript = try await processAudioWithWhisper(audioData: data, model: model)
        return transcript
    }

    func detectLanguage(text: String) async throws -> String {
        // Use NaturalLanguage framework (built-in, very fast)
        languageRecognizer.processString(text)

        guard let language = languageRecognizer.dominantLanguage else {
            return "unknown"
        }

        return language.rawValue
    }

    func checkToxicity(text: String) async throws -> ToxicityResult {
        print("🛡️ Checking toxicity on-device")

        // Use sentiment analysis as a simple toxicity proxy
        sentimentAnalyzer.string = text
        let (sentiment, _) = sentimentAnalyzer.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)

        let score = Double(sentiment?.rawValue ?? "0") ?? 0.0
        let isToxic = score < -0.5 // Negative sentiment

        // TODO: Load actual toxicity classification model
        return ToxicityResult(
            isToxic: isToxic,
            confidence: Float(abs(score)),
            categories: isToxic ? ["negative"] : []
        )
    }

    func generateEmbedding(text: String) async throws -> [Float] {
        // Use NaturalLanguage embedding (built-in)
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            throw InferenceError.modelNotLoaded
        }

        guard let vector = embedding.vector(for: text) else {
            throw InferenceError.processingFailed("Failed to generate embedding")
        }

        return vector
    }

    // MARK: - Private Helpers

    private func loadWhisperModel() async throws -> MLModel {
        // TODO: Load Whisper CoreML model from bundle or on-demand resource
        // For now, return stub
        print("⚠️ Whisper model not bundled yet - transcription unavailable")
        throw InferenceError.modelNotLoaded
    }

    private func processAudioWithWhisper(audioData: Data, model: MLModel) async throws -> String {
        // TODO: Implement actual Whisper inference
        // 1. Convert audio to mel spectrogram
        // 2. Run through Whisper encoder/decoder
        // 3. Return transcript
        throw InferenceError.featureNotSupported
    }

    private func generateExtractiveSummary(text: String, maxSentences: Int) -> String {
        // Simple extractive summary: return first N sentences
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let selected = Array(sentences.prefix(maxSentences))
        return selected.joined(separator: ". ") + "."
    }
}

// MARK: - Local Vector Store

actor LocalVectorStore {
    private var vectors: [String: [Float]] = [:] // messageId -> embedding
    private let maxEntries = 10_000 // Limit cache size

    func index(messageId: String, embedding: [Float]) {
        vectors[messageId] = embedding

        // Evict oldest if needed
        if vectors.count > maxEntries {
            let toRemove = vectors.keys.prefix(vectors.count - maxEntries)
            toRemove.forEach { vectors.removeValue(forKey: $0) }
        }
    }

    func search(queryEmbedding: [Float], topK: Int) -> [String] {
        // Simple cosine similarity search
        var scores: [(String, Float)] = []

        for (messageId, vector) in vectors {
            let similarity = cosineSimilarity(queryEmbedding, vector)
            scores.append((messageId, similarity))
        }

        // Sort by similarity and return top-K
        scores.sort { $0.1 > $1.1 }
        return Array(scores.prefix(topK).map { $0.0 })
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }

    func clear() {
        vectors.removeAll()
    }
}
