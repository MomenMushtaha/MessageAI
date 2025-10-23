//
//  MediaService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import UIKit
import FirebaseStorage

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
    ///   - progressHandler: Optional progress callback (0.0 to 1.0)
    /// - Returns: Tuple of (fullImageURL, thumbnailURL)
    func uploadImage(
        _ image: UIImage,
        conversationId: String,
        messageId: String,
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
        let fullImagePath = "conversations/\(conversationId)/media/\(messageId)/full.jpg"
        let thumbnailPath = "conversations/\(conversationId)/media/\(messageId)/thumb.jpg"

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

        // Wait for upload to complete
        _ = try await uploadTask

        // Upload thumbnail
        _ = try await thumbnailRef.putData(thumbnailData, metadata: metadata)

        // Get download URLs
        let fullURL = try await fullImageRef.downloadURL().absoluteString
        let thumbnailURL = try await thumbnailRef.downloadURL().absoluteString

        print("✅ Image uploaded successfully")
        return (fullURL, thumbnailURL)
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

    // MARK: - Audio Upload

    /// Upload an audio file to Firebase Storage
    /// - Parameters:
    ///   - audioData: Audio data to upload
    ///   - conversationId: Conversation ID
    ///   - messageId: Message ID
    ///   - duration: Audio duration in seconds
    ///   - progressHandler: Optional progress callback (0.0 to 1.0)
    /// - Returns: Audio file URL
    func uploadAudio(
        _ audioData: Data,
        conversationId: String,
        messageId: String,
        duration: TimeInterval,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> String {
        print("📤 Starting audio upload for message: \(messageId)")

        let storageRef = storage.reference()
        let audioPath = "conversations/\(conversationId)/media/\(messageId)/audio.m4a"
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

            // Get download URL
            let audioURL = try await audioRef.downloadURL().absoluteString

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
        }
    }
}
