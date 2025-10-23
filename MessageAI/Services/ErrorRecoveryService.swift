//
//  ErrorRecoveryService.swift
//  MessageAI
//
//  Created by MessageAI - Phase 7: Error Recovery
//

import Foundation
import Combine

/// Service to handle error recovery and retry logic
@MainActor
class ErrorRecoveryService {
    static let shared = ErrorRecoveryService()

    private init() {}

    /// Retry a network operation with exponential backoff
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - initialDelay: Initial delay in seconds (default: 1.0)
    ///   - maxDelay: Maximum delay in seconds (default: 10.0)
    ///   - operation: The async operation to retry
    /// - Returns: The result of the operation
    /// - Throws: The last error if all retries fail
    func retryWithExponentialBackoff<T>(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 10.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay

        for attempt in 0..<maxRetries {
            do {
                let result = try await operation()
                if attempt > 0 {
                    print("✅ Retry successful on attempt \(attempt + 1)")
                }
                return result
            } catch {
                lastError = error
                print("❌ Attempt \(attempt + 1) failed: \(error.localizedDescription)")

                // Check if error is retryable
                if !isRetryableError(error) {
                    print("⚠️ Non-retryable error, stopping retries")
                    throw error
                }

                // Don't delay after the last attempt
                if attempt < maxRetries - 1 {
                    print("⏳ Waiting \(delay) seconds before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    // Exponential backoff with jitter
                    delay = min(delay * 2.0 * (0.8 + Double.random(in: 0...0.4)), maxDelay)
                }
            }
        }

        // All retries failed
        print("❌ All \(maxRetries) retry attempts failed")
        throw lastError ?? NSError(domain: "ErrorRecoveryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation failed after \(maxRetries) retries"])
    }

    /// Check if an error is retryable (network errors, timeouts, etc.)
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorNotConnectedToInternet:
                return true
            default:
                return false
            }
        }

        // Firebase/Firestore transient errors
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 14: // UNAVAILABLE
                return true
            case 4: // DEADLINE_EXCEEDED
                return true
            case 8: // RESOURCE_EXHAUSTED
                return true
            default:
                return false
            }
        }

        return false
    }

    /// Execute an operation with timeout
    func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }

            group.cancelAll()
            return result
        }
    }

    /// Rollback handler for critical operations
    func executeWithRollback<T>(
        operation: @escaping () async throws -> T,
        rollback: @escaping () async throws -> Void
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            print("❌ Operation failed, executing rollback...")
            do {
                try await rollback()
                print("✅ Rollback completed successfully")
            } catch {
                print("❌ Rollback failed: \(error.localizedDescription)")
            }
            throw error
        }
    }
}

/// Timeout error
struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        return "Operation timed out"
    }
}
