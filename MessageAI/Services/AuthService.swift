//
//  AuthService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    static let shared = AuthService()
    
    private init() {
        // Listen to auth state changes
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateListenerHandle = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    // User is signed in, load user data
                    await self?.loadUserData(userId: user.uid)
                } else {
                    // User is signed out
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, displayName: String) async throws {
        errorMessage = nil
        
        // Validate inputs
        guard !email.isEmpty, !password.isEmpty, !displayName.isEmpty else {
            errorMessage = "Please fill in all fields"
            throw AuthError.invalidInput
        }
        
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            throw AuthError.invalidEmail
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            throw AuthError.weakPassword
        }
        
        do {
            print("🔐 Starting signup for email: \(email)")
            
            // Create Firebase Auth user
            let authResult = try await auth.createUser(withEmail: email, password: password)
            print("✅ Firebase Auth user created: \(authResult.user.uid)")
            
            // Create user document in Firestore
            let newUser = User(
                id: authResult.user.uid,
                displayName: displayName,
                email: email,
                createdAt: Date()
            )
            
            print("📝 Creating Firestore user document...")
            try await createUserDocument(user: newUser)
            print("✅ Firestore user document created")
            
            // Update current user
            currentUser = newUser
            isAuthenticated = true
            print("✅ Signup complete!")
            
        } catch let error as NSError {
            print("❌ Signup error - Domain: \(error.domain), Code: \(error.code)")
            print("❌ Error description: \(error.localizedDescription)")
            print("❌ Full error: \(error)")
            errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    // MARK: - Login
    
    func login(email: String, password: String) async throws {
        errorMessage = nil
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            throw AuthError.invalidInput
        }
        
        do {
            print("🔐 Starting login for email: \(email)")
            let authResult = try await auth.signIn(withEmail: email, password: password)
            print("✅ Firebase Auth login successful: \(authResult.user.uid)")
            
            await loadUserData(userId: authResult.user.uid)
            print("✅ Login complete!")
            
        } catch let error as NSError {
            print("❌ Login error - Domain: \(error.domain), Code: \(error.code)")
            print("❌ Error description: \(error.localizedDescription)")
            errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    // MARK: - Logout
    
    func logout() throws {
        do {
            // Stop presence tracking before logout
            if let userId = currentUser?.id {
                Task {
                    await PresenceService.shared.stopPresenceTracking(userId: userId)
                }
            }
            
            try auth.signOut()
            currentUser = nil
            isAuthenticated = false
            errorMessage = nil
            
            // Clear all caches for memory efficiency
            Task { @MainActor in
                CacheManager.shared.clearAllCaches()
            }
            
        } catch let error as NSError {
            errorMessage = "Failed to logout: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Update Profile

    func updateProfile(userId: String, displayName: String?, bio: String?) async throws {
        var updateData: [String: Any] = [:]

        if let displayName = displayName {
            updateData["displayName"] = displayName
        }

        if let bio = bio {
            updateData["bio"] = bio
        }

        guard !updateData.isEmpty else { return }

        do {
            try await db.collection("users").document(userId).updateData(updateData)

            // Update local currentUser
            if var user = currentUser {
                if let displayName = displayName {
                    user.displayName = displayName
                }
                if let bio = bio {
                    user.bio = bio
                }
                currentUser = user
            }

            print("✅ Profile updated successfully")
        } catch {
            print("❌ Error updating profile: \(error.localizedDescription)")
            throw error
        }
    }

    func updatePrivacySettings(
        userId: String,
        showReadReceipts: Bool? = nil,
        showOnlineStatus: Bool? = nil,
        showLastSeen: Bool? = nil
    ) async throws {
        var updateData: [String: Any] = [:]

        if let showReadReceipts = showReadReceipts {
            updateData["privacySettings.showReadReceipts"] = showReadReceipts
        }

        if let showOnlineStatus = showOnlineStatus {
            updateData["privacySettings.showOnlineStatus"] = showOnlineStatus
        }

        if let showLastSeen = showLastSeen {
            updateData["privacySettings.showLastSeen"] = showLastSeen
        }

        guard !updateData.isEmpty else { return }

        do {
            try await db.collection("users").document(userId).updateData(updateData)

            // Update local currentUser
            if var user = currentUser {
                var settings = user.privacySettings ?? UserPrivacySettings()

                if let showReadReceipts = showReadReceipts {
                    settings.showReadReceipts = showReadReceipts
                }
                if let showOnlineStatus = showOnlineStatus {
                    settings.showOnlineStatus = showOnlineStatus
                }
                if let showLastSeen = showLastSeen {
                    settings.showLastSeen = showLastSeen
                }

                user.privacySettings = settings
                currentUser = user
            }

            print("✅ Privacy settings updated successfully")
        } catch {
            print("❌ Error updating privacy settings: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Firestore Operations
    
    private func createUserDocument(user: User) async throws {
        let userData: [String: Any] = [
            "id": user.id,
            "displayName": user.displayName,
            "email": user.email,
            "avatarURL": user.avatarURL as Any,
            "createdAt": Timestamp(date: user.createdAt),
            "isOnline": true, // New user starts online
            "lastSeen": FieldValue.serverTimestamp()
        ]
        
        print("📝 Writing to Firestore: users/\(user.id)")
        do {
            try await db.collection("users").document(user.id).setData(userData)
            print("✅ Firestore write successful")
        } catch let error as NSError {
            print("❌ Firestore write error - Domain: \(error.domain), Code: \(error.code)")
            print("❌ Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func loadUserData(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if let data = document.data() {
                let user = User(
                    id: data["id"] as? String ?? userId,
                    displayName: data["displayName"] as? String ?? "Unknown",
                    email: data["email"] as? String ?? "",
                    avatarURL: data["avatarURL"] as? String,
                    bio: data["bio"] as? String,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    isOnline: data["isOnline"] as? Bool ?? false,
                    lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue()
                )
                
                currentUser = user
                isAuthenticated = true
                
                // Start presence tracking
                Task {
                    await PresenceService.shared.startPresenceTracking(userId: userId)
                }
            }
            
        } catch {
            print("Error loading user data: \(error.localizedDescription)")
            errorMessage = "Failed to load user data"
        }
    }
    
    // MARK: - Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func handleAuthError(_ error: NSError) -> String {
        // Check if it's a Firebase Auth error
        if error.domain == "FIRAuthErrorDomain" {
            switch error.code {
            // Account errors
            case 17007: // emailAlreadyInUse
                return "This email is already registered. Please log in instead."
            case 17011: // userNotFound
                return "No account found with this email. Please sign up first."
            case 17012: // userDisabled
                return "This account has been disabled. Please contact support."
            
            // Password errors
            case 17009: // wrongPassword
                return "Incorrect password. Please try again."
            case 17026: // weakPassword
                return "Password is too weak. Please use at least 6 characters."
            
            // Email errors
            case 17008: // invalidEmail
                return "Invalid email address. Please check and try again."
            
            // Credential errors
            case 17999: // invalidCredential
                return "Incorrect email or password. Please try again."
            case 17014: // invalidVerificationCode
                return "Invalid verification code. Please try again."
            case 17044: // invalidVerificationId
                return "Invalid verification. Please try again."
            case 17048: // credentialAlreadyInUse
                return "This credential is already associated with another account."
            
            // Network errors
            case 17020: // networkError
                return "Network error. Please check your internet connection."
            
            // Rate limiting
            case 17010: // tooManyRequests
                return "Too many attempts. Please wait a moment and try again."
            
            // Session errors
            case 17014: // requiresRecentLogin
                return "Please log in again to continue."
            case 17051: // userTokenExpired
                return "Your session has expired. Please log in again."
            
            // Operation errors
            case 17001: // operationNotAllowed
                return "This operation is not allowed. Please contact support."
            
            default:
                // Handle generic errors with user-friendly messages
                let message = error.localizedDescription.lowercased()
                
                // Check for common error phrases and replace with friendly messages
                if message.contains("credential") && (message.contains("malformed") || message.contains("expired")) {
                    return "Incorrect email or password. Please try again."
                } else if message.contains("password") {
                    return "Incorrect password. Please try again."
                } else if message.contains("email") {
                    return "There's an issue with this email address. Please check and try again."
                } else if message.contains("network") || message.contains("connection") {
                    return "Network error. Please check your internet connection."
                } else if message.contains("timeout") {
                    return "Request timed out. Please try again."
                } else {
                    return "Something went wrong. Please try again."
                }
            }
        }
        
        // Handle other error domains
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "No internet connection. Please check your network."
            case NSURLErrorTimedOut:
                return "Request timed out. Please try again."
            default:
                return "Network error. Please check your connection."
            }
        }
        
        // Default fallback
        return "Something went wrong. Please try again."
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidInput
    case invalidEmail
    case weakPassword
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Please fill in all fields"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 6 characters"
        }
    }
}

#if DEBUG
extension AuthService {
    /// Reset singleton state to provide a clean slate for integration tests.
    func resetForTesting() {
        if auth.currentUser != nil {
            try? auth.signOut()
        }
        
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
    }
}
#endif
