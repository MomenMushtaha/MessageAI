//
//  InferenceSettingsView.swift
//  MessageAI
//
//  Settings for AI inference mode and privacy
//

import SwiftUI

struct InferenceSettingsView: View {
    @StateObject private var inferenceManager = InferenceManager.shared

    var body: some View {
        List {
            Section {
                Picker("Inference Mode", selection: $inferenceManager.mode) {
                    ForEach(InferenceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Text(modeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("AI Processing", systemImage: "brain")
            }

            Section {
                Toggle(isOn: $inferenceManager.privateMode) {
                    Label("Private Mode", systemImage: "lock.shield")
                }

                if inferenceManager.privateMode {
                    Text("When enabled, AI features will prefer on-device processing when available. Voice notes are transcribed locally and never uploaded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Private Mode maximizes on-device processing for enhanced privacy.")
                    .font(.caption)
            }

            Section {
                InferenceFeatureRow(
                    icon: "sparkles",
                    title: "Summarization",
                    description: "Full-context thread summaries",
                    provider: getProvider(for: .summarize)
                )

                InferenceFeatureRow(
                    icon: "mic.fill",
                    title: "Voice Transcription",
                    description: "Convert voice notes to text",
                    provider: getProvider(for: .voiceTranscription)
                )

                InferenceFeatureRow(
                    icon: "magnifyingglass",
                    title: "Semantic Search",
                    description: "AI-powered message search",
                    provider: getProvider(for: .search)
                )

                InferenceFeatureRow(
                    icon: "text.bubble",
                    title: "Language Detection",
                    description: "Automatic language identification",
                    provider: getProvider(for: .languageDetection)
                )

                InferenceFeatureRow(
                    icon: "shield.checkered",
                    title: "Content Safety",
                    description: "On-device toxicity filtering",
                    provider: getProvider(for: .toxicityCheck)
                )
            } header: {
                Text("Feature Matrix")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "cloud.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("Server (High quality, full context)")
                            .font(.caption)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "iphone")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("On-Device (Private, offline-capable)")
                            .font(.caption)
                    }
                }
            }

            Section {
                NavigationLink {
                    AboutMLView()
                } label: {
                    Label("About Hybrid AI", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("AI Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var modeDescription: String {
        switch inferenceManager.mode {
        case .auto:
            return "Automatically selects the best processing method based on task complexity, network availability, and privacy settings."
        case .server:
            return "Always uses server-side AI for maximum quality and context. Requires internet connection."
        case .local:
            return "Prefers on-device processing when available. Falls back to server for complex tasks."
        }
    }

    private func getProvider(for feature: InferenceFeature) -> String {
        // Simulate provider selection
        let manager = InferenceManager.shared

        switch manager.mode {
        case .auto:
            if manager.privateMode {
                switch feature {
                case .voiceTranscription, .languageDetection, .toxicityCheck, .localSearch, .embeddings:
                    return "device"
                default:
                    return "server"
                }
            } else {
                switch feature {
                case .voiceTranscription, .languageDetection, .toxicityCheck:
                    return "device"
                default:
                    return "server"
                }
            }
        case .server:
            return "server"
        case .local:
            switch feature {
            case .voiceTranscription, .languageDetection, .toxicityCheck, .localSearch, .microSummary, .embeddings:
                return "device"
            default:
                return "server"
            }
        }
    }
}

struct InferenceFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let provider: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            providerBadge
        }
        .padding(.vertical, 4)
    }

    private var providerBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: provider == "device" ? "iphone" : "cloud.fill")
                .font(.caption2)
            Text(provider == "device" ? "Device" : "Server")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(provider == "device" ? .green : .blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(provider == "device" ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        )
    }
}

struct AboutMLView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Hybrid AI Architecture")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("MessageAI uses a hybrid approach combining server-side LLMs with on-device CoreML models.")
                        .foregroundStyle(.secondary)
                }

                Divider()

                Group {
                    Text("Server AI (OpenAI + RAG)")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        FeaturePoint(text: "Full conversation context and history")
                        FeaturePoint(text: "High-quality summarization and insights")
                        FeaturePoint(text: "Action items and decision tracking")
                        FeaturePoint(text: "Cross-conversation semantic search")
                    }

                    Text("Best for complex reasoning tasks requiring full context.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                Divider()

                Group {
                    Text("On-Device CoreML")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        FeaturePoint(text: "Private voice transcription (Whisper)")
                        FeaturePoint(text: "Instant language detection")
                        FeaturePoint(text: "Content safety filtering")
                        FeaturePoint(text: "Local semantic search cache")
                        FeaturePoint(text: "Works offline")
                    }

                    Text("Best for privacy, speed, and offline capability.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                Divider()

                Group {
                    Text("Privacy Commitment")
                        .font(.headline)

                    Text("When Private Mode is enabled, voice notes are transcribed on your device and never leave your phone. Text transcripts are stored in your Firebase account and can be optionally embedded for search.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("About Hybrid AI")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeaturePoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        InferenceSettingsView()
    }
}
