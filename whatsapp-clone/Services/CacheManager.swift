//
//  CacheManager.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import Foundation

@MainActor
class CacheManager {
    static let shared = CacheManager()
    
    // User cache for frequently accessed user data
    private let userCache = NSCache<NSString, UserCacheWrapper>()
    
    // Conversation cache
    private let conversationCache = NSCache<NSString, ConversationCacheWrapper>()
    
    private init() {
        setupCaches()
    }
    
    private func setupCaches() {
        // User cache settings
        userCache.countLimit = 100 // Cache up to 100 users
        userCache.totalCostLimit = 5 * 1024 * 1024 // 5MB
        
        // Conversation cache settings
        conversationCache.countLimit = 50 // Cache up to 50 conversations
        conversationCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    // MARK: - User Cache
    
    func cacheUser(_ user: User) {
        let key = NSString(string: user.id)
        let wrapper = UserCacheWrapper(user: user)
        userCache.setObject(wrapper, forKey: key, cost: user.displayName.utf8.count + user.email.utf8.count)
    }
    
    func getCachedUser(id: String) -> User? {
        let key = NSString(string: id)
        return userCache.object(forKey: key)?.user
    }
    
    func cacheUsers(_ users: [User]) {
        users.forEach { cacheUser($0) }
    }
    
    // MARK: - Conversation Cache
    
    func cacheConversation(_ conversation: Conversation) {
        let key = NSString(string: conversation.id)
        let wrapper = ConversationCacheWrapper(conversation: conversation)
        let cost = (conversation.lastMessageText?.utf8.count ?? 0) + (conversation.groupName?.utf8.count ?? 0)
        conversationCache.setObject(wrapper, forKey: key, cost: cost)
    }
    
    func getCachedConversation(id: String) -> Conversation? {
        let key = NSString(string: id)
        return conversationCache.object(forKey: key)?.conversation
    }
    
    // MARK: - Clear Cache
    
    func clearUserCache() {
        userCache.removeAllObjects()
    }
    
    func clearConversationCache() {
        conversationCache.removeAllObjects()
    }
    
    func clearAllCaches() {
        clearUserCache()
        clearConversationCache()
    }
}

// MARK: - Cache Wrappers

class UserCacheWrapper {
    let user: User
    init(user: User) {
        self.user = user
    }
}

class ConversationCacheWrapper {
    let conversation: Conversation
    init(conversation: Conversation) {
        self.conversation = conversation
    }
}

