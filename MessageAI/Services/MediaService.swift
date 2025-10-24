//
//  MediaService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import UIKit
import AVFoundation

@MainActor
class MediaService {
    static let shared = MediaService()

    private let imageCache = NSCache<NSString, UIImage>()

    private init() {
        // Configure cache limits (50MB)
        imageCache.totalCostLimit = 50 * 1024 * 1024
    }

    // MARK: - Image Upload

    /// Upload an image to S3/CloudFront (full + thumbnail)
    func uploadImage(
        _ image: UIImage,
        conversationId: String,
        messageId: String,
        userId: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> (fullURL: String, thumbnailURL: String) {
        print("📤 Starting image upload for message: \(messageId)")

        guard let fullImageData = compressImage(image, maxDimension: 2048, quality: 0.8),
              let thumbnailData = compressImage(image, maxDimension: 200, quality: 0.7) else {
            throw MediaError.compressionFailed
        }

        let descriptors = [
            S3FileDescriptor(key: "\(conversationId)/media/\(messageId)_full.jpg", contentType: "image/jpeg"),
            S3FileDescriptor(key: "\(conversationId)/media/\(messageId)_thumb.jpg", contentType: "image/jpeg")
        ]

        let targets = try await requestS3UploadURLs(
            conversationId: conversationId,
              messageId: messageId,
              userId: userId,
              files: descriptors
        )

        guard targets.count == descriptors.count else {
            throw MediaError.invalidURL
        }

        try await httpPUTUpload(
            to: targets[0].uploadUrl,
            data: fullImageData,
            contentType: descriptors[0].contentType,
            progressHandler: progressHandler
        )

        try await httpPUTUpload(
            to: targets[1].uploadUrl,
            data: thumbnailData,
            contentType: descriptors[1].contentType,
            progressHandler: nil
        )

        print("✅ Image uploaded to S3")
        return (targets[0].publicUrl, targets[1].publicUrl)
    }

    /// Upload or replace a group avatar image on S3
    func uploadGroupAvatar(
        _ image: UIImage,
        conversationId: String,
        adminId: String
    ) async throws -> String {
        print("📤 Uploading group avatar for conversation: \(conversationId)")

        guard let imageData = compressImage(image, maxDimension: 1024, quality: 0.8) else {
            throw MediaError.compressionFailed
        }

        let descriptor = S3FileDescriptor(
            key: "groups/\(conversationId)/avatar/avatar.jpg",
            contentType: "image/jpeg"
        )

        let targets = try await requestS3UploadURLs(
            conversationId: conversationId,
            messageId: "group-avatar",
            userId: adminId,
            files: [descriptor]
        )

        guard let target = targets.first else {
            throw MediaError.invalidURL
        }

        try await httpPUTUpload(
            to: target.uploadUrl,
            data: imageData,
            contentType: descriptor.contentType,
            progressHandler: nil
        )

        print("✅ Group avatar uploaded to S3")
        return target.publicUrl
    }

    // MARK: - Image Download & Caching

    /// Download image with caching support
    func downloadImage(from url: String) async throws -> UIImage {
        let cacheKey = NSString(string: url)

        if let cachedImage = imageCache.object(forKey: cacheKey) {
            print("📥 Image loaded from cache: \(url)")
            return cachedImage
        }

        guard let imageURL = URL(string: url) else {
            throw MediaError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: imageURL)

        guard let image = UIImage(data: data) else {
            throw MediaError.invalidImageData
        }

        imageCache.setObject(image, forKey: cacheKey)
        print("✅ Image downloaded and cached: \(url)")
        return image
    }

    func clearCache() {
        imageCache.removeAllObjects()
        print("🗑️ Image cache cleared")
    }

    // MARK: - Video Upload

    /// Upload a video and generated thumbnail to S3/CloudFront
    func uploadVideo(
        _ videoURL: URL,
        conversationId: String,
        messageId: String,
        userId: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> (videoURL: String, thumbnailURL: String, duration: TimeInterval) {
        print("🎥 Starting video upload for message: \(messageId)")

        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds

        guard let thumbnail = try await generateVideoThumbnail(from: videoURL),
              let thumbnailData = compressImage(thumbnail, maxDimension: 200, quality: 0.7) else {
            throw MediaError.compressionFailed
        }

        let videoData = try Data(contentsOf: videoURL)

        let maxSize = 50 * 1024 * 1024
        guard videoData.count <= maxSize else {
            throw MediaError.videoTooLarge
        }

        let descriptors = [
            S3FileDescriptor(key: "\(conversationId)/media/\(messageId)_video.mp4", contentType: "video/mp4"),
            S3FileDescriptor(key: "\(conversationId)/media/\(messageId)_video_thumb.jpg", contentType: "image/jpeg")
        ]

        let targets = try await requestS3UploadURLs(
            conversationId: conversationId,
            messageId: messageId,
            userId: userId,
            files: descriptors
        )

        guard targets.count == descriptors.count else {
            throw MediaError.invalidURL
        }

        try await httpPUTUpload(
            to: targets[0].uploadUrl,
            data: videoData,
            contentType: descriptors[0].contentType,
            progressHandler: progressHandler
        )

        try await httpPUTUpload(
            to: targets[1].uploadUrl,
            data: thumbnailData,
            contentType: descriptors[1].contentType,
            progressHandler: nil
        )

        print("✅ Video uploaded to S3")
        return (targets[0].publicUrl, targets[1].publicUrl, duration)
    }

    // MARK: - Audio Upload

    /// Upload an audio clip to S3/CloudFront
    func uploadAudio(
        _ audioData: Data,
        conversationId: String,
        messageId: String,
        userId: String,
        duration: TimeInterval,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> String {
        print("🎙️ Starting audio upload for message: \(messageId)")

        let descriptor = S3FileDescriptor(
            key: "\(conversationId)/media/\(messageId)_audio.m4a",
            contentType: "audio/m4a"
        )

        let targets = try await requestS3UploadURLs(
            conversationId: conversationId,
            messageId: messageId,
            userId: userId,
            files: [descriptor]
        )

        guard let target = targets.first else {
            throw MediaError.invalidURL
        }

        try await httpPUTUpload(
            to: target.uploadUrl,
            data: audioData,
            contentType: descriptor.contentType,
            progressHandler: progressHandler
        )

        print("✅ Audio uploaded to S3")
        return target.publicUrl
    }

    // MARK: - Helpers

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

    private func requestS3UploadURLs(
        conversationId: String,
        messageId: String,
        userId: String,
        files: [S3FileDescriptor]
    ) async throws -> [S3UploadTarget] {
        guard let endpoint = AppConfig.s3UploadEndpoint else {
            throw MediaError.invalidURL
        }

        let body: [String: Any] = [
            "conversationId": conversationId,
            "messageId": messageId,
            "userId": userId,
            "files": files.map { ["key": $0.key, "contentType": $0.contentType] }
        ]

        let (data, _) = try await httpJSONRequest(urlString: endpoint, body: body)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urls = json["urls"] as? [[String: String]],
              !urls.isEmpty else {
            throw MediaError.invalidURL
        }

        var targetsByKey: [String: S3UploadTarget] = [:]
        for entry in urls {
            guard let key = entry["key"],
                  let uploadUrl = entry["uploadUrl"],
                  let publicUrl = entry["publicUrl"] else {
                throw MediaError.invalidURL
            }
            targetsByKey[key] = S3UploadTarget(key: key, uploadUrl: uploadUrl, publicUrl: publicUrl)
        }

        return try files.map { file in
            guard let target = targetsByKey[file.key] else {
                throw MediaError.invalidURL
            }
            return target
        }
    }

    private func httpJSONRequest(urlString: String, body: [String: Any]) async throws -> (Data, URLResponse) {
        guard let url = URL(string: urlString) else {
            throw MediaError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await URLSession.shared.data(for: request)
    }

    private func httpPUTUpload(
        to urlString: String,
        data: Data,
        contentType: String,
        progressHandler: ((Double) -> Void)?
    ) async throws {
        guard let url = URL(string: urlString) else {
            throw MediaError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MediaError.uploadFailed
        }

        progressHandler?(1.0)
    }
}

// MARK: - S3 Helper Models

private struct S3FileDescriptor {
    let key: String
    let contentType: String
}

private struct S3UploadTarget {
    let key: String
    let uploadUrl: String
    let publicUrl: String
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
