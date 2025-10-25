//
//  AudioMessageView.swift
//  MessageAI
//
//  Created by MessageAI - Phase 8: Voice Message UI
//

import SwiftUI

struct AudioMessageView: View {
    let message: Message
    let isFromCurrentUser: Bool

    @StateObject private var audioService = AudioService.shared
    @State private var isDownloaded = false
    @State private var isLoading = false
    @State private var localURL: URL?
    @State private var playbackProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""

    private var duration: TimeInterval {
        message.audioDuration ?? 0
    }

    private var backgroundColor: Color {
        isFromCurrentUser ? Color.blue : Color(.systemGray5)
    }

    private var foregroundColor: Color {
        isFromCurrentUser ? .white : .primary
    }

    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button(action: {
                handlePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(foregroundColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(foregroundColor)
                }
            }
            .disabled(isLoading)

            // Waveform and Duration
            VStack(alignment: .leading, spacing: 4) {
                // Simple waveform visualization
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(foregroundColor.opacity(0.6))
                            .frame(width: 2, height: CGFloat.random(in: 8...20))
                    }
                }
                .frame(height: 24)

                // Duration Text
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(foregroundColor.opacity(0.7))
            }

            Spacer()

            // Loading or Downloaded Indicator
            if isLoading {
                ProgressView()
                    .tint(foregroundColor)
            } else if !isDownloaded {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(foregroundColor.opacity(0.6))
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 200, maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(16)
        .onAppear {
            // Auto-download if URL is already present; otherwise wait for update
            if localURL == nil && !isLoading {
                Task { await tryStartDownloadIfPossible() }
            }
        }
        .onChange(of: message.mediaURL ?? "") { _ in
            // When the message updates with a mediaURL, attempt download
            if localURL == nil && !isLoading {
                Task { await tryStartDownloadIfPossible() }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func handlePlayPause() {
        guard let url = localURL else {
            // Download if not available
            Task {
                await downloadAudio()
                if let url = localURL {
                    await playAudio(url: url)
                }
            }
            return
        }

        if audioService.isPlaying {
            audioService.pausePlayback()
        } else {
            Task {
                await playAudio(url: url)
            }
        }
    }

    private func tryStartDownloadIfPossible() async {
        guard message.mediaURL != nil else { return }
        await downloadAudio()
    }

    private func downloadAudio() async {
        guard let audioURLString = message.mediaURL else { return }

        guard let audioURL = URL(string: audioURLString) else {
            errorMessage = "Invalid audio URL"
            showError = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Download audio file
            let (data, _) = try await URLSession.shared.data(from: audioURL)

            // Save to temporary location
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "audio_\(message.id).m4a"
            let fileURL = tempDir.appendingPathComponent(fileName)

            try data.write(to: fileURL)

            localURL = fileURL
            isDownloaded = true

            print("✅ Audio downloaded: \(fileURL)")

        } catch {
            print("❌ Audio download failed: \(error)")
            errorMessage = "Failed to download audio"
            showError = true
        }
    }

    private func playAudio(url: URL) async {
        do {
            try await audioService.playAudio(from: url)
        } catch {
            print("❌ Audio playback failed: \(error)")
            errorMessage = "Failed to play audio"
            showError = true
        }
    }
}
