//
//  MediaService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import UIKit
import FirebaseStorage
import AVFoundation

@MainActor
class MediaService {
    static let shared = MediaService()

    private let storage = Storage.storage()
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {
        // Configure cache limits (50MB)
        imageCache.totalCostLimit = 50 * 1024 * 1024
    }

    // MARK: - Image Upload

    /// Upload an image to Firebase Storage
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - conversationId: Conversation ID
    ///   - messageId: Message ID
    ///   - userId: User ID of the sender
    ///   - progressHandler: Optional progress callback (0.0 to 1.0)
    /// - Returns: Tuple of (fullImageURL, thumbnailURL)
    func uploadImage(
        _ image: UIImage,
        conversationId: String,
        messageId: String,
        userId: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> (fullURL: String, thumbnailURL: String) {
        print("📤 Starting image upload for message: \(messageId)")

        // Compress full image (max 2048x2048)
        guard let fullImageData = compressImage(image, maxDimension: 2048, quality: 0.8) else {
            throw MediaError.compressionFailed
        }

        // Generate thumbnail (200x200)
        guard let thumbnailData = compressImage(image, maxDimension: 200, quality: 0.7) else {
            throw MediaError.compressionFailed
        }

        let storageRef = storage.reference()
        let fullImagePath = "conversations/\(conversationId)/media/\(messageId)_full.jpg"
        let thumbnailPath = "conversations/\(conversationId)/media/\(messageId)_thumb.jpg"

        let fullImageRef = storageRef.child(fullImagePath)
        let thumbnailRef = storageRef.child(thumbnailPath)

        // Upload full image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let uploadTask = fullImageRef.putData(fullImageData, metadata: metadata)

        // Observe upload progress
        uploadTask.observe(.progress) { snapshot in
            if let progress = snapshot.progress {
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                Task { @MainActor in
                    progressHandler?(percentComplete)
                }
            }
        }

        do {
            // Wait for upload to complete
            print("⏳ Waiting for full image upload...")
            let fullUploadResult = try await uploadTask
            print("✅ Full image uploaded")
            
            // Upload thumbnail
            print("⏳ Uploading thumbnail...")
            let thumbnailUploadResult = try await thumbnailRef.putData(thumbnailData, metadata: metadata)
            print("✅ Thumbnail uploaded")
            
            // Get download URLs (with retry to avoid eventual-consistency 404)
            print("📥 Getting full image download URL (with retry)...")
            let fullURL = try await getDownloadURLWithRetry(ref: fullImageRef)
            print("✅ Got full image URL: \(fullURL)")
            
            print("📥 Getting thumbnail download URL (with retry)...")
            let thumbnailURL = try await getDownloadURLWithRetry(ref: thumbnailRef)
            print("✅ Got thumbnail URL: \(thumbnailURL)")

            print("✅ Image upload complete - returning URLs")
            return (fullURL, thumbnailURL)
            
        } catch {
            print("❌ Error in image upload: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Helpers

    /// Fetch a download URL with retries to handle Storage eventual consistency (objectNotFound 404 right after upload)
    private func getDownloadURLWithRetry(ref: StorageReference, maxAttempts: Int = 5) async throws -> String {
        var attempt = 0
        var lastError: Error?
        var delayMs: UInt64 = 200 // start with 200ms

        while attempt < maxAttempts {
            do {
                let url = try await ref.downloadURL().absoluteString
                return url
            } catch {
                lastError = error
                attempt += 1
                print("⚠️ downloadURL attempt #\(attempt) failed: \(error.localizedDescription)")
                // Exponential backoff with max ~3.2s
                let ns = delayMs * 1_000_000
                try? await Task.sleep(nanoseconds: ns)
                delayMs = min(delayMs * 2, 3200)
            }
        }
        throw lastError ?? NSError(domain: "MediaService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL after retries"])
    }

    // MARK: - Image Compression

    private func compressImage(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        var scaledSize = size

        if size.width > maxDimension || size.height > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        }

        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: scaledSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return scaledImage?.jpegData(compressionQuality: quality)
    }

    // MARK: - Image Download & Caching

    /// Download image with caching
    func downloadImage(from url: String) async throws -> UIImage {
        let cacheKey = NSString(string: url)

        // Check cache first
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            print("📥 Image loaded from cache: \(url)")
            return cachedImage
        }

        // Download from URL
        guard let imageURL = URL(string: url) else {
            throw MediaError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: imageURL)

        guard let image = UIImage(data: data) else {
            throw MediaError.invalidImageData
        }

        // Cache the image
        imageCache.setObject(image, forKey: cacheKey)
        print("✅ Image downloaded and cached: \(url)")

        return image
    }

    // MARK: - Cache Management

    func clearCache() {
        imageCache.removeAllObjects()
        print("🗑️ Image cache cleared")
    }

    // MARK: - Video Upload

    /// Upload a video to Firebase Storage with thumbnail generation
    /// - Parameters:
    ///   - videoURL: URL to the video file
    ///   - conversationId: Conversation ID
    ///   - messageId: Message ID
    ///   - userId: User ID of the sender
    ///   - progressHandler: Optional progress callback (0.0 to 1.0)
    /// - Returns: Tuple of (videoURL, thumbnailURL, duration)
    func uploadVideo(
        _ videoURL: URL,
        conversationId: String,
        messageId: String,
        userId: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> (videoURL: String, thumbnailURL: String, duration: TimeInterval) {
        print("📤 Starting video upload for message: \(messageId)")

        // Get video duration
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds

        // Generate thumbnail from first frame
        guard let thumbnail = try await generateVideoThumbnail(from: videoURL) else {
            throw MediaError.compressionFailed
        }

        // Compress thumbnail
        guard let thumbnailData = compressImage(thumbnail, maxDimension: 200, quality: 0.7) else {
            throw MediaError.compressionFailed
        }

        // Read video data
        let videoData = try Data(contentsOf: videoURL)

        // Check video size (max 50MB)
        let maxSize = 50 * 1024 * 1024
        guard videoData.count <= maxSize else {
            throw MediaError.videoTooLarge
        }

        let storageRef = storage.reference()
        let videoPath = "conversations/\(conversationId)/media/\(messageId)_video.mp4"
        let thumbnailPath = "conversations/\(conversationId)/media/\(messageId)_video_thumb.jpg"

        let videoRef = storageRef.child(videoPath)
        let thumbnailRef = storageRef.child(thumbnailPath)

        // Set video metadata
        let videoMetadata = StorageMetadata()
        videoMetadata.contentType = "video/mp4"
        videoMetadata.customMetadata = [
            "duration": String(duration),
            "messageId": messageId
        ]

        // Upload video with progress tracking
        let uploadTask = videoRef.putData(videoData, metadata: videoMetadata)

        uploadTask.observe(.progress) { snapshot in
            if let progress = snapshot.progress {
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                Task { @MainActor in
                    progressHandler?(percentComplete)
                }
            }
        }

        _ = try await uploadTask

        // Upload thumbnail
        let thumbnailMetadata = StorageMetadata()
        thumbnailMetadata.contentType = "image/jpeg"
        _ = try await thumbnailRef.putData(thumbnailData, metadata: thumbnailMetadata)

        // Get download URLs with retry (avoid eventual 404)
        print("📥 Getting video download URL (with retry)...")
        let videoDownloadURL = try await getDownloadURLWithRetry(ref: videoRef)
        print("✅ Got video URL: \(videoDownloadURL)")

        print("📥 Getting video thumbnail URL (with retry)...")
        let thumbnailDownloadURL = try await getDownloadURLWithRetry(ref: thumbnailRef)
        print("✅ Got video thumbnail URL: \(thumbnailDownloadURL)")

        print("✅ Video uploaded successfully: \(videoDownloadURL)")
        return (videoDownloadURL, thumbnailDownloadURL, duration)
    }

    /// Generate a thumbnail image from the first frame of a video
    private func generateVideoThumbnail(from url: URL) async throws -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 400, height: 400)

        let time = CMTime(seconds: 0, preferredTimescale: 600)

        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let cgImage = cgImage else {
                    continuation.resume(returning: nil)
                    return
                }

                let uiImage = UIImage(cgImage: cgImage)
                continuation.resume(returning: uiImage)
            }
        }
    }

    // MARK: - Audio Upload

    /// Upload an audio file to Firebase Storage
    /// - Parameters:
    ///   - audioData: Audio data to upload
    ///   - conversationId: Conversation ID
    ///   - messageId: Message ID
    ///   - userId: User ID of the sender
    ///   - duration: Audio duration in seconds
    ///   - progressHandler: Optional progress callback (0.0 to 1.0)
    /// - Returns: Audio file URL
    func uploadAudio(
        _ audioData: Data,
        conversationId: String,
        messageId: String,
        userId: String,
        duration: TimeInterval,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> String {
        print("📤 Starting audio upload for message: \(messageId)")

        let storageRef = storage.reference()
        let audioPath = "conversations/\(conversationId)/media/\(messageId)_audio.m4a"
        let audioRef = storageRef.child(audioPath)

        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        metadata.customMetadata = [
            "duration": String(duration),
            "messageId": messageId
        ]

        do {
            // Upload with progress tracking
            let uploadTask = audioRef.putData(audioData, metadata: metadata)

            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    Task { @MainActor in
                        progressHandler?(percentComplete)
                    }
                }
            }

            _ = try await uploadTask

            // Get download URL with retry (avoid 404 immediately after upload)
            print("📥 Getting audio download URL (with retry)...")
            let audioURL = try await getDownloadURLWithRetry(ref: audioRef)

            print("✅ Audio uploaded successfully: \(audioURL)")
            return audioURL

        } catch {
            print("❌ Audio upload failed: \(error.localizedDescription)")
            throw MediaError.uploadFailed
        }
    }
}

// MARK: - Media Errors

enum MediaError: LocalizedError {
    case compressionFailed
    case invalidURL
    case invalidImageData
    case uploadFailed
    case videoTooLarge

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .invalidURL:
            return "Invalid media URL"
        case .invalidImageData:
            return "Invalid image data"
        case .uploadFailed:
            return "Failed to upload media"
        case .videoTooLarge:
            return "Video file is too large (max 50MB)"
        }
    }
}
