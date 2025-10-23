//
//  VoiceRecordingView.swift
//  MessageAI
//
//  Created by MessageAI - Phase 8: Voice Message UI
//

import SwiftUI

struct VoiceRecordingView: View {
    @ObservedObject var audioService: AudioService
    @Binding var isRecording: Bool

    let onSend: (URL, TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var recordingURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            // Recording Indicator
            HStack(spacing: 12) {
                // Animated red dot
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)
                    .scaleEffect(audioService.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: audioService.isRecording)

                Text("Recording")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            // Duration Display
            Text(formatDuration(audioService.recordingDuration))
                .font(.system(size: 48, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            // Waveform Visualization (simplified)
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 3, height: CGFloat.random(in: 20...60))
                        .animation(
                            .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.05),
                            value: audioService.isRecording
                        )
                }
            }
            .frame(height: 80)

            Spacer()

            // Action Buttons
            HStack(spacing: 40) {
                // Cancel Button
                Button(action: {
                    cancelRecording()
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 70, height: 70)

                            Image(systemName: "xmark")
                                .font(.system(size: 28))
                                .foregroundStyle(.red)
                        }

                        Text("Cancel")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Send Button
                Button(action: {
                    stopAndSendRecording()
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 70, height: 70)

                            Image(systemName: "arrow.up")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.blue)
                        }

                        Text("Send")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(audioService.recordingDuration < 1.0)
                .opacity(audioService.recordingDuration < 1.0 ? 0.5 : 1.0)
            }
            .padding(.bottom, 40)
        }
        .padding()
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

    private func cancelRecording() {
        audioService.cancelRecording()
        isRecording = false
        onCancel()
    }

    private func stopAndSendRecording() {
        guard let url = audioService.stopRecording() else {
            errorMessage = "Failed to save recording"
            showError = true
            return
        }

        let duration = audioService.recordingDuration
        isRecording = false
        onSend(url, duration)
    }
}
