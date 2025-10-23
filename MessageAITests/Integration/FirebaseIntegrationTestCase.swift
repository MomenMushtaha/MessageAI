//
//  FirebaseIntegrationTestCase.swift
//  MessageAITests
//
//  Shared base class for end-to-end Firebase integration tests.
//

import XCTest
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import SwiftData
@testable import MessageAI

@MainActor
class FirebaseIntegrationTestCase: XCTestCase {
    
    struct TestUser {
        let id: String
        let email: String
        let password: String
        let displayName: String
    }
    
    private static let integrationFlag = "MESSAGEAI_INTEGRATION_TESTS"
    private static let hostEnv = "MESSAGEAI_FIREBASE_HOST"
    private static let firestorePortEnv = "MESSAGEAI_FIRESTORE_PORT"
    private static let authPortEnv = "MESSAGEAI_AUTH_PORT"
    
    private static let host = ProcessInfo.processInfo.environment[hostEnv] ?? "127.0.0.1"
    private static let firestorePort = Int(ProcessInfo.processInfo.environment[firestorePortEnv] ?? "") ?? 8080
    private static let authPort = Int(ProcessInfo.processInfo.environment[authPortEnv] ?? "") ?? 9099
    
    private static let integrationEnabled = ProcessInfo.processInfo.environment[integrationFlag] == "1"
    private static let skipMessage = """
    Integration tests require the Firebase emulator. \
    Start the emulator (auth + firestore) and run tests with \(integrationFlag)=1.
    """
    
    private static var firebaseConfigured = false
    
    static var shouldSkipAllTests: Bool {
        return !integrationEnabled
    }
    
    var modelContainer: ModelContainer?
    
    override class func setUp() {
        super.setUp()
        
        guard !shouldSkipAllTests else { return }
        guard !firebaseConfigured else { return }
        
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        let firestore = Firestore.firestore()
        firestore.useEmulator(withHost: host, port: firestorePort)
        let settings = firestore.settings
        settings.isPersistenceEnabled = false
        firestore.settings = settings
        
        Auth.auth().useEmulator(withHost: host, port: authPort)
        
        firebaseConfigured = true
    }
    
    override func setUp() async throws {
        try await super.setUp()
        
        guard !Self.shouldSkipAllTests else {
            throw XCTSkip(Self.skipMessage)
        }
        
        resetSingletonState()
        
        do {
            let container = try ModelContainer(
                for: LocalMessage.self,
                LocalConversation.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            modelContainer = container
            let context = ModelContext(container)
            LocalStorageService.initialize(with: context)
        } catch {
            XCTFail("Failed to initialise in-memory SwiftData container: \(error)")
        }
    }
    
    override func tearDown() async throws {
        try? AuthService.shared.logout()
        resetSingletonState()
        modelContainer = nil
        
        try await super.tearDown()
    }
    
    func createTestUser(displayName: String) async throws -> TestUser {
        let email = "\(displayName.lowercased())_\(UUID().uuidString)@integration.messageai"
        let password = Self.defaultPassword
        
        try await AuthService.shared.signUp(
            email: email,
            password: password,
            displayName: displayName
        )
        
        guard let id = AuthService.shared.currentUser?.id else {
            throw XCTSkip("Unable to capture user id after sign up")
        }
        
        let user = TestUser(id: id, email: email, password: password, displayName: displayName)
        try? AuthService.shared.logout()
        resetSingletonState()
        return user
    }
    
    func login(_ user: TestUser) async throws {
        try await AuthService.shared.login(email: user.email, password: user.password)
    }
    
    func logoutCurrentUser() {
        try? AuthService.shared.logout()
        resetSingletonState()
    }
    
    func waitForPropagation(milliseconds: UInt64 = 500) async {
        let nanos = milliseconds * 1_000_000
        try? await Task.sleep(nanoseconds: nanos)
    }
    
    private static let defaultPassword = "TestPassword123!"
    
    private func resetSingletonState() {
#if DEBUG
        AuthService.shared.resetForTesting()
        ChatService.shared.resetForTesting()
#endif
    }
}
