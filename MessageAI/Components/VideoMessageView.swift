//
//  VideoMessageView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI
import AVKit

struct VideoMessageView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let onTap: () -> Void

    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // Thumbnail background
            if let thumbnail = thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 250, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 250, height: 180)
            }

            // Loading indicator
            if isLoading {
                ProgressView()
                    .tint(.white)
            }

            // Play button overlay
            if !isLoading {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .offset(x: 2) // Slight visual adjustment
                    }
            }

            // Duration badge
            if let duration = message.videoDuration, !isLoading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            }
                            .padding(8)
                    }
                }
            }
        }
        .frame(width: 250, height: 180)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let thumbnailURLString = message.thumbnailURL,
              let thumbnailURL = URL(string: thumbnailURLString) else {
            isLoading = false
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: thumbnailURL)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.thumbnailImage = image
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ Failed to load video thumbnail: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Video Player View for full-screen playback
struct VideoPlayerView: View {
    let videoURL: String
    let onDismiss: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func loadVideo() {
        guard let url = URL(string: videoURL) else { return }

        Task {
            do {
                // Download video to temp file
                let (tempURL, _) = try await URLSession.shared.download(from: url)

                // Move to permanent temp location
                let fileManager = FileManager.default
                let tempDirectory = fileManager.temporaryDirectory
                let localURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp4")

                try? fileManager.removeItem(at: localURL) // Clean up if exists
                try fileManager.moveItem(at: tempURL, to: localURL)

                await MainActor.run {
                    let newPlayer = AVPlayer(url: localURL)
                    self.player = newPlayer
                    newPlayer.play()
                }
            } catch {
                print("❌ Failed to load video: \(error.localizedDescription)")
            }
        }
    }
}
