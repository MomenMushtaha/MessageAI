//
//  FullScreenImageView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI
import Photos

struct FullScreenImageView: View {
    let message: Message
    let onDismiss: () -> Void

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingSaveSuccess = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            // Image content
            if let image = image {
                imageView(image: image)
            } else if isLoading {
                loadingView
            } else if loadError {
                errorView
            }

            // Top bar with close and save buttons
            VStack {
                topBar
                Spacer()
            }

            // Success/Error alerts
            if showingSaveSuccess {
                saveSuccessAlert
            }

            if showingSaveError {
                saveErrorAlert
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            loadFullImage()
        }
    }

    // MARK: - Image View with Zoom

    private func imageView(image: UIImage) -> some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale *= delta

                            // Limit zoom between 1x and 5x
                            scale = min(max(scale, 1.0), 5.0)
                        }
                        .onEnded { _ in
                            lastScale = 1.0

                            // Reset to 1x if zoomed out too far
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                // Allow panning when zoomed in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    // Double-tap to zoom in/out
                    withAnimation(.spring()) {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                        }
                    }
                }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }

            Spacer()

            // Save to Photos button
            Button(action: saveToPhotos) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Loading full image...")
                .foregroundStyle(.white)
                .font(.headline)
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Failed to load image")
                .foregroundStyle(.white)
                .font(.headline)

            Button("Retry") {
                loadFullImage()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(10)
        }
    }

    // MARK: - Save Alerts

    private var saveSuccessAlert: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)

                Text("Saved to Photos")
                    .foregroundStyle(.white)
                    .font(.headline)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showingSaveSuccess = false
                }
            }
        }
    }

    private var saveErrorAlert: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)

                    Text("Failed to Save")
                        .foregroundStyle(.white)
                        .font(.headline)
                }

                Text(saveErrorMessage)
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showingSaveError = false
                }
            }
        }
    }

    // MARK: - Image Loading

    private func loadFullImage() {
        // Load the full resolution image
        guard let url = message.mediaURL else {
            loadError = true
            isLoading = false
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
                print("❌ Failed to load full image: \(error.localizedDescription)")
                await MainActor.run {
                    self.loadError = true
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Save to Photos

    private func saveToPhotos() {
        guard let image = image else { return }

        // Request photo library permission
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    // Permission granted, save the image
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

                    withAnimation {
                        showingSaveSuccess = true
                    }

                case .denied, .restricted:
                    // Permission denied
                    saveErrorMessage = "Photo library access denied. Enable in Settings."
                    withAnimation {
                        showingSaveError = true
                    }

                case .notDetermined:
                    // This shouldn't happen as we just requested permission
                    saveErrorMessage = "Permission not determined"
                    withAnimation {
                        showingSaveError = true
                    }

                @unknown default:
                    saveErrorMessage = "Unknown permission status"
                    withAnimation {
                        showingSaveError = true
                    }
                }
            }
        }
    }
}

#Preview {
    FullScreenImageView(
        message: Message(
            id: "1",
            conversationId: "c1",
            senderId: "u1",
            text: "",
            createdAt: Date(),
            status: "sent",
            mediaType: "image",
            mediaURL: "https://picsum.photos/800/600",
            thumbnailURL: "https://picsum.photos/200/150"
        ),
        onDismiss: {
            print("Dismiss")
        }
    )
}
