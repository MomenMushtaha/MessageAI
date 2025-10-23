//
//  ValidationUtility.swift
//  MessageAI
//
//  Created by MessageAI - Phase 7: Production Hardening
//

import Foundation

enum ValidationError: LocalizedError {
    case emptyInput(field: String)
    case tooShort(field: String, minLength: Int)
    case tooLong(field: String, maxLength: Int)
    case invalidFormat(field: String)
    case invalidCharacters(field: String)
    case containsProfanity(field: String)

    var errorDescription: String? {
        switch self {
        case .emptyInput(let field):
            return "\(field) cannot be empty"
        case .tooShort(let field, let minLength):
            return "\(field) must be at least \(minLength) characters"
        case .tooLong(let field, let maxLength):
            return "\(field) must be no more than \(maxLength) characters"
        case .invalidFormat(let field):
            return "\(field) has an invalid format"
        case .invalidCharacters(let field):
            return "\(field) contains invalid characters"
        case .containsProfanity(let field):
            return "\(field) contains inappropriate content"
        }
    }
}

struct ValidationUtility {

    // MARK: - Message Validation

    static func validateMessage(_ text: String) throws {
        // Remove leading/trailing whitespace
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "Message")
        }

        guard trimmed.count <= 4096 else {
            throw ValidationError.tooLong(field: "Message", maxLength: 4096)
        }

        // Check for excessive special characters (potential spam)
        let specialCharCount = trimmed.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }.count
        if Double(specialCharCount) / Double(trimmed.count) > 0.5 {
            throw ValidationError.invalidCharacters(field: "Message")
        }
    }

    // MARK: - Display Name Validation

    static func validateDisplayName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "Display name")
        }

        guard trimmed.count >= 1 else {
            throw ValidationError.tooShort(field: "Display name", minLength: 1)
        }

        guard trimmed.count <= 100 else {
            throw ValidationError.tooLong(field: "Display name", maxLength: 100)
        }

        // Check for valid characters (letters, numbers, spaces, basic punctuation)
        let validCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "'-.,"))

        if trimmed.rangeOfCharacter(from: validCharacterSet.inverted) != nil {
            throw ValidationError.invalidCharacters(field: "Display name")
        }
    }

    // MARK: - Email Validation

    static func validateEmail(_ email: String) throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "Email")
        }

        guard trimmed.count >= 3 else {
            throw ValidationError.tooShort(field: "Email", minLength: 3)
        }

        guard trimmed.count <= 100 else {
            throw ValidationError.tooLong(field: "Email", maxLength: 100)
        }

        // Basic email format validation
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        guard emailPredicate.evaluate(with: trimmed) else {
            throw ValidationError.invalidFormat(field: "Email")
        }
    }

    // MARK: - Password Validation

    static func validatePassword(_ password: String) throws {
        guard !password.isEmpty else {
            throw ValidationError.emptyInput(field: "Password")
        }

        guard password.count >= 6 else {
            throw ValidationError.tooShort(field: "Password", minLength: 6)
        }

        guard password.count <= 128 else {
            throw ValidationError.tooLong(field: "Password", maxLength: 128)
        }
    }

    // MARK: - Group Name Validation

    static func validateGroupName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "Group name")
        }

        guard trimmed.count >= 1 else {
            throw ValidationError.tooShort(field: "Group name", minLength: 1)
        }

        guard trimmed.count <= 100 else {
            throw ValidationError.tooLong(field: "Group name", maxLength: 100)
        }
    }

    // MARK: - Bio Validation

    static func validateBio(_ bio: String) throws {
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        // Bio can be empty
        if trimmed.isEmpty {
            return
        }

        guard trimmed.count <= 500 else {
            throw ValidationError.tooLong(field: "Bio", maxLength: 500)
        }
    }

    // MARK: - Group Description Validation

    static func validateGroupDescription(_ description: String) throws {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Description can be empty
        if trimmed.isEmpty {
            return
        }

        guard trimmed.count <= 1000 else {
            throw ValidationError.tooLong(field: "Group description", maxLength: 1000)
        }
    }

    // MARK: - File Size Validation

    static func validateImageSize(_ data: Data) throws {
        let maxSize = 10 * 1024 * 1024 // 10MB
        guard data.count <= maxSize else {
            throw ValidationError.tooLong(field: "Image", maxLength: maxSize)
        }
    }

    static func validateVideoSize(_ data: Data) throws {
        let maxSize = 100 * 1024 * 1024 // 100MB
        guard data.count <= maxSize else {
            throw ValidationError.tooLong(field: "Video", maxLength: maxSize)
        }
    }

    // MARK: - Sanitization

    /// Sanitize text by removing potentially harmful content
    static func sanitize(_ text: String) -> String {
        var sanitized = text

        // Remove control characters (except newlines and tabs)
        sanitized = sanitized.filter { character in
            let isControl = CharacterSet.controlCharacters.contains(character.unicodeScalars.first!)
            return !isControl || character.isNewline || character == "\t"
        }

        // Trim excessive whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        // Replace multiple consecutive spaces with single space
        while sanitized.contains("  ") {
            sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
        }

        // Replace multiple consecutive newlines with double newline (max)
        while sanitized.contains("\n\n\n") {
            sanitized = sanitized.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return sanitized
    }

    /// Sanitize and validate message text
    static func sanitizeAndValidateMessage(_ text: String) throws -> String {
        let sanitized = sanitize(text)
        try validateMessage(sanitized)
        return sanitized
    }

    /// Sanitize and validate display name
    static func sanitizeAndValidateDisplayName(_ name: String) throws -> String {
        let sanitized = sanitize(name)
        try validateDisplayName(sanitized)
        return sanitized
    }

    /// Sanitize and validate group name
    static func sanitizeAndValidateGroupName(_ name: String) throws -> String {
        let sanitized = sanitize(name)
        try validateGroupName(sanitized)
        return sanitized
    }
}
