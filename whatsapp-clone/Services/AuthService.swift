//
//  AuthService.swift
//  whatsapp-clone
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
            throw AuthError.invalidInput
        }
        
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }
        
        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }
        
        do {
            // Create Firebase Auth user
            let authResult = try await auth.createUser(withEmail: email, password: password)
            
            // Create user document in Firestore
            let newUser = User(
                id: authResult.user.uid,
                displayName: displayName,
                email: email,
                createdAt: Date()
            )
            
            try await createUserDocument(user: newUser)
            
            // Update current user
            currentUser = newUser
            isAuthenticated = true
            
        } catch let error as NSError {
            errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    // MARK: - Login
    
    func login(email: String, password: String) async throws {
        errorMessage = nil
        
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthError.invalidInput
        }
        
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            await loadUserData(userId: authResult.user.uid)
            
        } catch let error as NSError {
            errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    // MARK: - Logout
    
    func logout() throws {
        do {
            try auth.signOut()
            currentUser = nil
            isAuthenticated = false
            errorMessage = nil
            
        } catch let error as NSError {
            errorMessage = "Failed to logout: \(error.localizedDescription)"
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
            "createdAt": Timestamp(date: user.createdAt)
        ]
        
        try await db.collection("users").document(user.id).setData(userData)
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
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
                
                currentUser = user
                isAuthenticated = true
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
            case 17007: // emailAlreadyInUse
                return "This email is already registered"
            case 17008: // invalidEmail
                return "Invalid email address"
            case 17026: // weakPassword
                return "Password must be at least 6 characters"
            case 17009: // wrongPassword
                return "Incorrect password"
            case 17011: // userNotFound
                return "No account found with this email"
            case 17020: // networkError
                return "Network error. Please check your connection"
            case 17010: // tooManyRequests
                return "Too many attempts. Please try again later"
            default:
                return error.localizedDescription
            }
        }
        
        return error.localizedDescription
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

