//
//  AppConfig.swift
//  MessageAI
//
//  Centralized app configuration loaded from Info.plist
//

import Foundation

enum AppConfig {
    // HTTPS endpoint for generating pre-signed upload URLs
    // Example: https://us-central1-your-project.cloudfunctions.net/generateUploadUrl
    static var s3UploadEndpoint: String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: "S3_UPLOAD_ENDPOINT") as? String, !value.isEmpty {
            return value
        }
        if let env = ProcessInfo.processInfo.environment["S3_UPLOAD_ENDPOINT"], !env.isEmpty {
            return env
        }
        return nil
    }
    
    // MoChain AI Assistant endpoint
    // Example: https://us-central1-your-project.cloudfunctions.net/mochainChat
    static var mochainChatEndpoint: String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: "MOCHAIN_CHAT_ENDPOINT") as? String, !value.isEmpty {
            return value
        }
        if let env = ProcessInfo.processInfo.environment["MOCHAIN_CHAT_ENDPOINT"], !env.isEmpty {
            return env
        }
        return nil
    }
    
    // MushLifts Fitness AI Assistant endpoint
    // Example: https://us-central1-your-project.cloudfunctions.net/mushliftsChat
    static var mushLiftsChatEndpoint: String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: "MUSHLIFTS_CHAT_ENDPOINT") as? String, !value.isEmpty {
            return value
        }
        if let env = ProcessInfo.processInfo.environment["MUSHLIFTS_CHAT_ENDPOINT"], !env.isEmpty {
            return env
        }
        return nil
    }
}
