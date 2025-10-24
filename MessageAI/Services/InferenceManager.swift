//
//  InferenceManager.swift
//  MessageAI
//
//  Hybrid inference coordinator: Server LLM+RAG + CoreML on-device processing
//

import Foundation
import Combine

// MARK: - Inference Mode

enum InferenceMode: String, Codable, CaseIterable {
    case auto       // Smart selection based on task, network, privacy
    case server     // Always use server (OpenAI + RAG)
    case local      // Prefer on-device CoreML when available

    var displayName: String {
        switch self {
        case .auto: return "Auto (Recommended)"
        case .server: return "Server Only"
        case .local: return "On-Device Preferred"
        }
    }
}

// MARK: - Inference Features

enum InferenceFeature {
    // Server-optimized (complex, long-context)
    case summarize
    case actionItems
    case decisions
    case priority
    case search
    case translate

    // Can run on-device
    case voiceTranscription
    case languageDetection
    case toxicityCheck
    case localSearch
    case microSummary
    case embeddings
}

// MARK: - Inference Provider Protocol

protocol InferenceProvider {
    var name: String { get }
    var isAvailable: Bool { get }

    func supports(_ feature: InferenceFeature) -> Bool

    // Core features
    func summarize(convId: String, messages: [Message], window: String, style: String) async throws -> InferenceSummaryResult
    func extractActions(convId: String, messages: [Message]) async throws -> [AIAction]
    func detectPriority(message: Message) async throws -> InferencePriorityResult
    func search(query: String, messages: [Message]) async throws -> [Message]
    func translate(text: String, targetLang: String) async throws -> String

    // On-device specific
    func transcribeAudio(data: Data) async throws -> String
    func detectLanguage(text: String) async throws -> String
    func checkToxicity(text: String) async throws -> ToxicityResult
    func generateEmbedding(text: String) async throws -> [Float]
}

// MARK: - Results

struct InferenceSummaryResult {
    let summary: String
    let sources: [String]
    let onDevice: Bool
    let model: String
}

struct InferencePriorityResult {
    let priority: String
    let isUrgent: Bool
    let confidence: Float
    let onDevice: Bool
}

struct ToxicityResult {
    let isToxic: Bool
    let confidence: Float
    let categories: [String]
}

// MARK: - Inference Manager

@MainActor
class InferenceManager: ObservableObject {
    static let shared = InferenceManager()

    @Published var mode: InferenceMode = .auto {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "inference_mode")
            print("🔄 Inference mode changed to: \(mode.displayName)")
        }
    }

    @Published var isProcessing = false
    @Published var privateMode = false {
        didSet {
            UserDefaults.standard.set(privateMode, forKey: "private_mode")
        }
    }

    private var providers: [InferenceProvider] = []
    private let networkMonitor = NetworkMonitor.shared

    private init() {
        // Load saved preferences
        if let savedMode = UserDefaults.standard.string(forKey: "inference_mode"),
           let mode = InferenceMode(rawValue: savedMode) {
            self.mode = mode
        }
        self.privateMode = UserDefaults.standard.bool(forKey: "private_mode")

        // Register providers
        registerProviders()
    }

    private func registerProviders() {
        // Server provider (always available)
        providers.append(ServerInferenceProvider())

        // CoreML provider (device-dependent)
        let coreMLProvider = CoreMLInferenceProvider()
        if coreMLProvider.isAvailable {
            providers.insert(coreMLProvider, at: 0) // Prefer local when available
            print("✅ CoreML provider registered")
        } else {
            print("⚠️ CoreML provider unavailable on this device")
        }
    }

    // MARK: - Provider Selection

    private func selectProvider(for feature: InferenceFeature) -> InferenceProvider? {
        switch mode {
        case .server:
            return providers.first { $0.name == "Server" }

        case .local:
            // Try local first, fallback to server
            if let local = providers.first(where: { $0.name == "CoreML" && $0.supports(feature) }) {
                return local
            }
            return providers.first { $0.name == "Server" }

        case .auto:
            // Smart selection
            return selectProviderAuto(for: feature)
        }
    }

    private func selectProviderAuto(for feature: InferenceFeature) -> InferenceProvider? {
        // Privacy mode: always prefer on-device
        if privateMode {
            if let local = providers.first(where: { $0.name == "CoreML" && $0.supports(feature) }) {
                print("🔒 Private mode: using CoreML for \(feature)")
                return local
            }
        }

        // Network-dependent features
        let offlineOnlyFeatures: [InferenceFeature] = [
            .voiceTranscription,
            .languageDetection,
            .toxicityCheck,
            .localSearch,
            .microSummary,
            .embeddings
        ]

        if offlineOnlyFeatures.contains(feature) {
            // Prefer on-device for these
            if let local = providers.first(where: { $0.name == "CoreML" && $0.supports(feature) }) {
                return local
            }
        }

        // Complex features: prefer server when online
        let serverOptimalFeatures: [InferenceFeature] = [
            .summarize,
            .actionItems,
            .decisions,
            .priority,
            .search,
            .translate
        ]

        if serverOptimalFeatures.contains(feature) {
            if networkMonitor.isConnected {
                return providers.first { $0.name == "Server" }
            } else {
                // Offline: try local fallback
                if let local = providers.first(where: { $0.name == "CoreML" && $0.supports(feature) }) {
                    print("📵 Offline: using CoreML fallback for \(feature)")
                    return local
                }
            }
        }

        // Default: server
        return providers.first { $0.name == "Server" }
    }

    // MARK: - Public API

    func summarize(convId: String, messages: [Message], window: String = "week", style: String = "bullets") async throws -> InferenceSummaryResult {
        guard let provider = selectProvider(for: .summarize) else {
            throw InferenceError.noProviderAvailable
        }

        isProcessing = true
        defer { isProcessing = false }

        print("🤖 Summarizing with \(provider.name)")
        return try await provider.summarize(convId: convId, messages: messages, window: window, style: style)
    }

    func extractActions(convId: String, messages: [Message]) async throws -> [AIAction] {
        guard let provider = selectProvider(for: .actionItems) else {
            throw InferenceError.noProviderAvailable
        }

        isProcessing = true
        defer { isProcessing = false }

        print("🤖 Extracting actions with \(provider.name)")
        return try await provider.extractActions(convId: convId, messages: messages)
    }

    func detectPriority(message: Message) async throws -> InferencePriorityResult {
        guard let provider = selectProvider(for: .priority) else {
            throw InferenceError.noProviderAvailable
        }

        print("🤖 Detecting priority with \(provider.name)")
        return try await provider.detectPriority(message: message)
    }

    func search(query: String, messages: [Message]) async throws -> [Message] {
        guard let provider = selectProvider(for: .search) else {
            throw InferenceError.noProviderAvailable
        }

        isProcessing = true
        defer { isProcessing = false }

        print("🔍 Searching with \(provider.name)")
        return try await provider.search(query: query, messages: messages)
    }

    func translate(text: String, targetLang: String) async throws -> String {
        guard let provider = selectProvider(for: .translate) else {
            throw InferenceError.noProviderAvailable
        }

        isProcessing = true
        defer { isProcessing = false }

        print("🌐 Translating with \(provider.name)")
        return try await provider.translate(text: text, targetLang: targetLang)
    }

    // On-device features

    func transcribeAudio(data: Data) async throws -> String {
        guard let provider = selectProvider(for: .voiceTranscription) else {
            throw InferenceError.noProviderAvailable
        }

        print("🎤 Transcribing with \(provider.name)")
        return try await provider.transcribeAudio(data: data)
    }

    func detectLanguage(text: String) async throws -> String {
        guard let provider = selectProvider(for: .languageDetection) else {
            throw InferenceError.noProviderAvailable
        }

        return try await provider.detectLanguage(text: text)
    }

    func checkToxicity(text: String) async throws -> ToxicityResult {
        guard let provider = selectProvider(for: .toxicityCheck) else {
            throw InferenceError.noProviderAvailable
        }

        return try await provider.checkToxicity(text: text)
    }

    func generateEmbedding(text: String) async throws -> [Float] {
        guard let provider = selectProvider(for: .embeddings) else {
            throw InferenceError.noProviderAvailable
        }

        return try await provider.generateEmbedding(text: text)
    }
}

// MARK: - Errors

enum InferenceError: LocalizedError {
    case noProviderAvailable
    case featureNotSupported
    case modelNotLoaded
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noProviderAvailable:
            return "No inference provider available"
        case .featureNotSupported:
            return "Feature not supported by current provider"
        case .modelNotLoaded:
            return "ML model not loaded"
        case .processingFailed(let msg):
            return "Processing failed: \(msg)"
        }
    }
}
