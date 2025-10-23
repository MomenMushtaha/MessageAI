//
//  ImageMessageView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI

struct ImageMessageView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let onTap: () -> Void

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError = false

    var body: some View {
        Group {
            if let image = image {
                // Successfully loaded image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 250, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        onTap()
                    }
            } else if isLoading {
                // Loading state
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 250, height: 200)

                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading image...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if loadError {
                // Error state
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: 250, height: 200)

                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.red)
                        Text("Failed to load image")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            loadImage()
                        }
                        .font(.caption)
                    }
                }
            } else {
                // Initial placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 250, height: 200)

                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        // Determine which URL to use (prefer thumbnail for preview)
        guard let url = message.thumbnailURL ?? message.mediaURL else {
            loadError = true
            return
        }

        isLoading = true
        loadError = false

        Task {
            do {
                let loadedImage = try await MediaService.shared.downloadImage(from: url)
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } catch {
                print("❌ Failed to load image: \(error.localizedDescription)")
                await MainActor.run {
                    self.loadError = true
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    VStack {
        ImageMessageView(
            message: Message(
                id: "1",
                conversationId: "c1",
                senderId: "u1",
                text: "",
                createdAt: Date(),
                status: "sent",
                mediaType: "image",
                mediaURL: "https://picsum.photos/400/300",
                thumbnailURL: "https://picsum.photos/200/150"
            ),
            isFromCurrentUser: true,
            onTap: {
                print("Image tapped")
            }
        )
        .padding()
    }
}
