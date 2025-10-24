//
//  UserDiagnosticView.swift
//  MessageAI
//
//  Diagnostic view to troubleshoot user fetching issues
//

import SwiftUI
import FirebaseDatabase

struct UserDiagnosticView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatService: ChatService

    @State private var diagnosticResult = ""
    @State private var isRunning = false
    @State private var rawData = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("User Fetching Diagnostics")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("This view helps diagnose why users aren't showing up.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Current User Info
                    Group {
                        Text("Current User")
                            .font(.headline)

                        if let user = authService.currentUser {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ID: \(user.id)")
                                    .font(.caption)
                                    .textSelection(.enabled)
                                Text("Name: \(user.displayName)")
                                    .font(.caption)
                                Text("Email: \(user.email)")
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }

                    Divider()

                    // All Users from ChatService
                    Group {
                        Text("Users in ChatService.allUsers")
                            .font(.headline)

                        Text("Count: \(chatService.allUsers.count)")
                            .font(.subheadline)
                            .foregroundStyle(chatService.allUsers.isEmpty ? .red : .green)

                        if !chatService.allUsers.isEmpty {
                            ForEach(chatService.allUsers) { user in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("ID: \(user.id)")
                                        .font(.caption2)
                                        .textSelection(.enabled)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }

                    Divider()

                    // Run Diagnostic
                    Button(action: { Task { await runDiagnostic() } }) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isRunning ? "Running..." : "Run Diagnostic")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRunning)

                    if !diagnosticResult.isEmpty {
                        Group {
                            Text("Diagnostic Results")
                                .font(.headline)

                            Text(diagnosticResult)
                                .font(.caption)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                        }
                    }

                    if !rawData.isEmpty {
                        Group {
                            Text("Raw Firebase Data")
                                .font(.headline)

                            ScrollView {
                                Text(rawData)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 300)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("User Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func runDiagnostic() async {
        guard let currentUserId = authService.currentUser?.id else {
            diagnosticResult = "❌ No current user - not authenticated"
            return
        }

        isRunning = true
        var result = "🔍 Running diagnostics...\n\n"

        // 1. Check if we can read from /users
        result += "1️⃣ Checking Firebase Database connection...\n"
        let db = Database.database().reference()

        do {
            let snapshot = try await db.child("users").getData()

            if !snapshot.exists() {
                result += "❌ /users node does not exist in Firebase RTDB\n"
                result += "   This means no users have been created yet or you're looking at the wrong database.\n\n"
            } else {
                result += "✅ /users node exists\n\n"

                // Get raw data
                if let usersDict = snapshot.value as? [String: Any] {
                    result += "2️⃣ Found \(usersDict.count) user(s) in database\n"

                    rawData = ""
                    for (userId, userData) in usersDict {
                        if let data = userData as? [String: Any] {
                            rawData += "User ID: \(userId)\n"
                            rawData += "  displayName: \(data["displayName"] as? String ?? "N/A")\n"
                            rawData += "  email: \(data["email"] as? String ?? "N/A")\n"
                            rawData += "  createdAt: \(data["createdAt"] ?? "N/A")\n"
                            rawData += "  isOnline: \(data["isOnline"] as? Bool ?? false)\n"
                            rawData += "\n"
                        }
                    }

                    // Filter out current user
                    let otherUsers = usersDict.filter { $0.key != currentUserId }
                    result += "3️⃣ After excluding current user (\(currentUserId)):\n"
                    result += "   Found \(otherUsers.count) other user(s)\n\n"

                    if otherUsers.isEmpty {
                        result += "⚠️ No other users found!\n"
                        result += "   This means only your account exists in the database.\n"
                        result += "   Try creating more test accounts.\n\n"
                    } else {
                        result += "✅ Other users exist:\n"
                        for (userId, userData) in otherUsers {
                            if let data = userData as? [String: Any] {
                                let name = data["displayName"] as? String ?? "Unknown"
                                let email = data["email"] as? String ?? "N/A"
                                result += "   - \(name) (\(email))\n"
                            }
                        }
                        result += "\n"
                    }
                } else {
                    result += "❌ Could not parse users data\n"
                    result += "   Expected dictionary but got: \(type(of: snapshot.value))\n\n"
                }
            }

            // 4. Test fetchAllUsers
            result += "4️⃣ Testing ChatService.fetchAllUsers()...\n"
            await chatService.fetchAllUsers(excludingUserId: currentUserId)
            result += "   ChatService.allUsers count: \(chatService.allUsers.count)\n"

            if chatService.allUsers.isEmpty {
                result += "❌ ChatService.allUsers is empty after fetch\n"
                result += "   Check the parsing logic in ChatService.fetchAllUsers()\n"
            } else {
                result += "✅ ChatService successfully loaded \(chatService.allUsers.count) users\n"
            }

        } catch {
            result += "❌ Error reading from Firebase: \(error.localizedDescription)\n"
            result += "\nPossible causes:\n"
            result += "- Firebase RTDB security rules blocking read access\n"
            result += "- Network connectivity issues\n"
            result += "- Wrong Firebase project selected\n"
        }

        diagnosticResult = result
        isRunning = false
    }
}

#Preview {
    UserDiagnosticView()
        .environmentObject(AuthService.shared)
        .environmentObject(ChatService.shared)
}
