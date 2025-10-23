//
//  AudioService.swift
//  MessageAI
//
//  Created by MessageAI - Phase 8: Voice Messages
//

import Foundation
import AVFoundation
import Combine

enum AudioError: LocalizedError {
    case recordingFailed
    case permissionDenied
    case invalidFormat
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .recordingFailed:
            return "Failed to record audio"
        case .permissionDenied:
            return "Microphone access denied. Please enable in Settings."
        case .invalidFormat:
            return "Invalid audio format"
        case .uploadFailed:
            return "Failed to upload audio"
        }
    }
}

@MainActor
class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var isPlaying = false

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var recordingURL: URL?

    private override init() {
        super.init()
        setupAudioSession()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Permissions

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Recording

    func startRecording() async throws -> URL {
        // Check permissions
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw AudioError.permissionDenied
        }

        // Create temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "voice_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        recordingURL = fileURL

        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            // Create recorder
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()

            // Start recording
            guard audioRecorder?.record() == true else {
                throw AudioError.recordingFailed
            }

            isRecording = true
            recordingDuration = 0

            // Start timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.recordingDuration = self.audioRecorder?.currentTime ?? 0
                }
            }

            print("✅ Started recording audio")
            return fileURL

        } catch {
            print("❌ Recording failed: \(error)")
            throw AudioError.recordingFailed
        }
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        print("✅ Stopped recording audio. Duration: \(recordingDuration)s")
        return recordingURL
    }

    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        recordingDuration = 0
        recordingURL = nil

        print("🗑️ Cancelled recording")
    }

    // MARK: - Playback

    func playAudio(from url: URL) async throws {
        do {
            // Stop any existing playback
            stopPlayback()

            // Create player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            // Start playback
            guard audioPlayer?.play() == true else {
                throw AudioError.recordingFailed
            }

            isPlaying = true
            print("▶️ Started playing audio")

        } catch {
            print("❌ Playback failed: \(error)")
            throw AudioError.recordingFailed
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        print("⏹️ Stopped playback")
    }

    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        print("⏸️ Paused playback")
    }

    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
        print("▶️ Resumed playback")
    }

    // MARK: - Duration

    func getAudioDuration(from url: URL) -> TimeInterval? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            print("❌ Failed to get audio duration: \(error)")
            return nil
        }
    }

    // MARK: - Compress Audio

    func compressAudio(from sourceURL: URL) async throws -> Data {
        // For M4A/AAC format, the file is already compressed
        // Just read and return the data
        do {
            let data = try Data(contentsOf: sourceURL)
            print("✅ Audio size: \(data.count / 1024) KB")
            return data
        } catch {
            print("❌ Failed to read audio file: \(error)")
            throw AudioError.invalidFormat
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("✅ Recording finished successfully")
        } else {
            print("❌ Recording finished with error")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("❌ Recording encode error: \(error)")
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            print("✅ Playback finished")
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("❌ Playback decode error: \(error)")
        }
        Task { @MainActor in
            self.isPlaying = false
        }
    }
}
