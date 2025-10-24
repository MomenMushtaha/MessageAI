//
//  AIService.swift
//  MessageAI
//
//  AI-powered features for Remote Team Professional persona
//

import Foundation
import FirebaseAuth
import FirebaseDatabase
import Combine

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var isProcessing = false
    @Published var lastError: String?
    
    // Configuration
    private let openAIAPIKey: String
    private let openAIBaseURL = "https://api.openai.com/v1"
    private let model = "gpt-4o-mini" // Fast and cost-effective
    
    // Cache for AI results
    private var summaryCache: [String: ConversationSummary] = [:]
    private var actionItemCache: [String: [ActionItem]] = [:]
    
    private init() {
        // Load API key from environment/info.plist
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY_HERE" {
            self.openAIAPIKey = apiKey
        } else {
            // Fallback to placeholder for demo mode
            self.openAIAPIKey = "YOUR_OPENAI_API_KEY"
            print("⚠️ OpenAI API key not configured. AI features will use mock responses.")
        }
    }
    
    // MARK: - Cloud Functions Integration (Phase A)

    private let baseURL = URL(string: "https://us-central1-messagingai-swift.cloudfunctions.net")!

    /// Helper: Make authenticated request to Cloud Functions
    private func authedRequest(_ path: String, body: [String: Any]) async throws -> Data {
        guard let user = Auth.auth().currentUser else {
            throw AIError.configurationError("User not authenticated")
        }

        let token = try await user.getIDToken()

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError("Server error: \(errorMsg)")
        }

        return data
    }

    /// Summarize conversation using RAG (Pinecone + Cloud Functions)
    func summarize(convId: String, window: String = "week", style: String = "bullets") async throws -> AISummaryResponse {
        print("🤖 Summarizing conversation: \(convId)")
        isProcessing = true
        defer { isProcessing = false }

        let data = try await authedRequest("/aiSummarize", body: [
            "convId": convId,
            "window": window,
            "style": style
        ])

        let response = try JSONDecoder().decode(AISummaryResponse.self, from: data)
        print("✅ Summary received with \(response.sources.count) sources")
        return response
    }

    /// Extract action items (future endpoint)
    func actionItems(convId: String) async throws -> AIActionItemsResponse {
        print("🤖 Extracting action items: \(convId)")
        isProcessing = true
        defer { isProcessing = false }

        let data = try await authedRequest("/action_items", body: ["convId": convId])
        return try JSONDecoder().decode(AIActionItemsResponse.self, from: data)
    }

    /// Semantic search (future endpoint)
    func search(convId: String, q: String, topK: Int = 8) async throws -> AISearchResponse {
        print("🤖 Semantic search: '\(q)'")
        isProcessing = true
        defer { isProcessing = false }

        let data = try await authedRequest("/search", body: [
            "convId": convId,
            "q": q,
            "topK": topK
        ])
        return try JSONDecoder().decode(AISearchResponse.self, from: data)
    }

    /// Detect message priority (future endpoint)
    func priority(convId: String, msgId: String) async throws -> AIPriorityResponse {
        print("🤖 Detecting priority for message: \(msgId)")
        isProcessing = true
        defer { isProcessing = false }

        let data = try await authedRequest("/priority", body: [
            "convId": convId,
            "msgId": msgId
        ])
        return try JSONDecoder().decode(AIPriorityResponse.self, from: data)
    }

    /// Track decisions (future endpoint)
    func decisions(convId: String) async throws -> AIDecisionsResponse {
        print("🤖 Tracking decisions: \(convId)")
        isProcessing = true
        defer { isProcessing = false }

        let data = try await authedRequest("/decisions", body: ["convId": convId])
        return try JSONDecoder().decode(AIDecisionsResponse.self, from: data)
    }

    /// Translate message (future endpoint)
    func translate(convId: String, msgId: String, targetLang: String) async throws -> AITranslateResponse {
        print("🤖 Translating message: \(msgId) to \(targetLang)")
        isProcessing = true
        defer { isProcessing = false }

        let data = try await authedRequest("/translate", body: [
            "convId": convId,
            "msgId": msgId,
            "targetLang": targetLang
        ])
        return try JSONDecoder().decode(AITranslateResponse.self, from: data)
    }

    // MARK: - 1. Thread Summarization

    /// Summarizes a conversation thread with key points (Legacy - direct OpenAI call)
    func summarizeConversation(messages: [Message], conversationId: String) async throws -> ConversationSummary {
        print("🤖 Summarizing conversation with \(messages.count) messages...")
        
        // Check cache first
        if let cached = summaryCache[conversationId] {
            let age = Date().timeIntervalSince(cached.createdAt)
            if age < 300 { // 5 minutes cache
                print("✅ Using cached summary")
                return cached
            }
        }
        
        let startTime = Date()
        
        // Prepare conversation context
        let conversationText = messages.map { msg in
            "[\(formatDate(msg.createdAt))]: \(msg.text)"
        }.joined(separator: "\n")
        
        let prompt = """
        You are an AI assistant helping remote teams stay organized. Summarize this conversation thread.
        
        Conversation:
        \(conversationText)
        
        Provide a concise summary covering:
        1. Main topics discussed (2-3 bullet points)
        2. Key decisions made
        3. Important information shared
        
        Format as JSON:
        {
            "mainTopics": ["topic1", "topic2"],
            "keyDecisions": ["decision1", "decision2"],
            "importantInfo": ["info1", "info2"],
            "summary": "Brief 2-3 sentence summary"
        }
        """
        
        let response = try await callOpenAI(prompt: prompt)
        let summary = try parseSummaryResponse(response)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Summary generated in \(String(format: "%.2f", duration))s")
        
        // Cache result
        summaryCache[conversationId] = summary
        
        // Track performance
        await PerformanceMonitor.shared.trackNetworkRequest(
            endpoint: "OpenAI-Summarize",
            duration: duration,
            success: true
        )
        
        return summary
    }
    
    // MARK: - 2. Action Item Extraction
    
    /// Extracts action items and tasks from conversation
    func extractActionItems(messages: [Message], conversationId: String) async throws -> [ActionItem] {
        print("🤖 Extracting action items from \(messages.count) messages...")
        
        // Check cache
        if let cached = actionItemCache[conversationId] {
            print("✅ Using cached action items")
            return cached
        }
        
        let startTime = Date()
        
        let conversationText = messages.map { msg in
            "[\(formatDate(msg.createdAt))]: \(msg.text)"
        }.joined(separator: "\n")
        
        let prompt = """
        You are an AI assistant helping remote teams track tasks and action items.
        Analyze this conversation and extract all action items, tasks, and commitments.
        
        Conversation:
        \(conversationText)
        
        For each action item, identify:
        - The task description
        - Who is responsible (if mentioned)
        - Any deadline or time commitment (if mentioned)
        - Priority level (high, medium, low)
        
        Format as JSON array:
        [
            {
                "task": "Complete the report",
                "assignee": "John",
                "deadline": "Friday",
                "priority": "high",
                "context": "Brief context from conversation"
            }
        ]
        
        Return empty array [] if no action items found.
        """
        
        let response = try await callOpenAI(prompt: prompt)
        let actionItems = try parseActionItems(response, conversationId: conversationId)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Extracted \(actionItems.count) action items in \(String(format: "%.2f", duration))s")
        
        // Cache result
        actionItemCache[conversationId] = actionItems
        
        return actionItems
    }
    
    // MARK: - 3. Smart Semantic Search
    
    /// Performs semantic search across messages using AI understanding
    func semanticSearch(query: String, messages: [Message]) async throws -> [Message] {
        print("🤖 Performing semantic search for: '\(query)'")
        
        let startTime = Date()
        
        // For performance, limit to recent messages
        let recentMessages = Array(messages.suffix(100))
        
        let conversationText = recentMessages.enumerated().map { index, msg in
            "Message \(index): [\(formatDate(msg.createdAt))]: \(msg.text)"
        }.joined(separator: "\n")
        
        let prompt = """
        You are a semantic search assistant. Find messages relevant to this query.
        
        Query: "\(query)"
        
        Messages:
        \(conversationText)
        
        Return the indices of ALL relevant messages (0-based), ranked by relevance.
        Consider semantic meaning, context, and related concepts, not just keywords.
        
        Format as JSON:
        {
            "relevantIndices": [5, 12, 23],
            "explanation": "Brief explanation of why these are relevant"
        }
        
        Return empty array if no relevant messages found.
        """
        
        let response = try await callOpenAI(prompt: prompt)
        let result = try parseSemanticSearchResponse(response, messages: recentMessages)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Semantic search found \(result.count) results in \(String(format: "%.2f", duration))s")
        
        return result
    }
    
    // MARK: - 4. Priority/Urgent Message Detection
    
    /// Analyzes message to detect urgency and priority
    func detectPriority(message: Message) async throws -> MessagePriority {
        print("🤖 Detecting priority for message...")
        
        let startTime = Date()
        
        let prompt = """
        You are an AI assistant helping remote teams prioritize messages.
        Analyze this message and determine its priority and urgency.
        
        Message: "\(message.text)"
        
        Consider:
        - Urgency indicators (ASAP, urgent, critical, deadline)
        - Action requirements (need, must, required)
        - Time sensitivity (today, now, immediately)
        - Impact level (important, critical, blocking)
        
        Format as JSON:
        {
            "priority": "high|medium|low",
            "isUrgent": true|false,
            "requiresAction": true|false,
            "reasoning": "Brief explanation",
            "suggestedResponse": "Suggested action or response"
        }
        """
        
        let response = try await callOpenAI(prompt: prompt, maxTokens: 200)
        let priority = try parsePriorityResponse(response, messageId: message.id)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Priority detected: \(priority.level.rawValue) in \(String(format: "%.2f", duration))s")
        
        return priority
    }
    
    // MARK: - 5. Decision Tracking
    
    /// Extracts decisions made in conversation
    func trackDecisions(messages: [Message], conversationId: String) async throws -> [Decision] {
        print("🤖 Tracking decisions in conversation...")
        
        let startTime = Date()
        
        let conversationText = messages.map { msg in
            "[\(formatDate(msg.createdAt))]: \(msg.text)"
        }.joined(separator: "\n")
        
        let prompt = """
        You are an AI assistant helping remote teams track decisions.
        Analyze this conversation and identify all decisions that were made or agreed upon.
        
        Conversation:
        \(conversationText)
        
        Look for:
        - Explicit decisions ("we decided", "let's go with", "agreed")
        - Consensus ("everyone agrees", "sounds good to everyone")
        - Commitments ("we will", "let's do")
        - Conclusions reached
        
        Format as JSON array:
        [
            {
                "decision": "Clear statement of the decision",
                "context": "Why this decision was made",
                "participants": ["person1", "person2"],
                "timestamp": "When it was decided",
                "confidence": "high|medium|low"
            }
        ]
        
        Return empty array [] if no clear decisions found.
        """
        
        let response = try await callOpenAI(prompt: prompt)
        let decisions = try parseDecisions(response, conversationId: conversationId)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Tracked \(decisions.count) decisions in \(String(format: "%.2f", duration))s")
        
        return decisions
    }
    
    // MARK: - Advanced: Multi-Step Agent
    
    /// Multi-step agent that can handle complex workflows with context
    func executeMultiStepAgent(task: AgentTask, context: AgentContext) async throws -> AgentResult {
        print("🤖 Executing multi-step agent task: \(task.type)")
        
        let startTime = Date()
        var steps: [AgentStep] = []
        var currentContext = context
        
        // Step 1: Analyze task and create execution plan
        let plan = try await createExecutionPlan(task: task, context: currentContext)
        steps.append(AgentStep(name: "Plan Created", status: .completed, output: plan.description))
        
        // Step 2-N: Execute each step in the plan
        for (index, planStep) in plan.steps.enumerated() {
            print("🤖 Executing step \(index + 1)/\(plan.steps.count): \(planStep.action)")
            
            let stepResult = try await executeStep(
                step: planStep,
                context: currentContext,
                previousSteps: steps
            )
            
            steps.append(stepResult)
            
            // Update context with results
            currentContext = currentContext.merging(stepResult.contextUpdates)
            
            // Handle errors
            if stepResult.status == .failed {
                print("❌ Step failed: \(stepResult.error ?? "Unknown error")")
                throw AIError.agentStepFailed(stepResult.error ?? "Step failed")
            }
        }
        
        // Final step: Synthesize results
        let finalResult = try await synthesizeResults(steps: steps, context: currentContext)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Agent completed in \(String(format: "%.2f", duration))s with \(steps.count) steps")
        
        return AgentResult(
            task: task,
            steps: steps,
            finalOutput: finalResult,
            duration: duration,
            success: true
        )
    }
    
    // MARK: - Helper Methods

    func callOpenAI(prompt: String, maxTokens: Int = 1000) async throws -> String {
        // Check if API key is configured
        guard openAIAPIKey != "YOUR_OPENAI_API_KEY" else {
            // For demo/testing, return mock response
            print("⚠️ OpenAI API key not configured, using mock response")
            return generateMockResponse(for: prompt)
        }
        
        let url = URL(string: "\(openAIBaseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful AI assistant for team communication."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIError.apiError("OpenAI API error")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        return content ?? ""
    }
    
    private func generateMockResponse(for prompt: String) -> String {
        // Generate appropriate mock responses based on prompt content
        if prompt.contains("summarize") || prompt.contains("Summary") {
            return """
            {
                "mainTopics": ["Project timeline discussion", "Resource allocation", "Next steps"],
                "keyDecisions": ["Deadline moved to next Friday", "John will lead the design phase"],
                "importantInfo": ["Client meeting scheduled for Tuesday", "Budget approved"],
                "summary": "Team discussed project timeline and decided to move deadline to next Friday. John will lead design phase and client meeting is scheduled for Tuesday."
            }
            """
        } else if prompt.contains("action items") || prompt.contains("tasks") {
            return """
            [
                {
                    "task": "Complete project proposal",
                    "assignee": "Sarah",
                    "deadline": "Friday",
                    "priority": "high",
                    "context": "Discussed in team meeting"
                },
                {
                    "task": "Review design mockups",
                    "assignee": "John",
                    "deadline": "Tomorrow",
                    "priority": "medium",
                    "context": "Client feedback needed"
                }
            ]
            """
        } else if prompt.contains("priority") || prompt.contains("urgent") {
            return """
            {
                "priority": "high",
                "isUrgent": true,
                "requiresAction": true,
                "reasoning": "Message contains deadline and action requirement",
                "suggestedResponse": "Acknowledge and confirm timeline"
            }
            """
        } else if prompt.contains("decisions") || prompt.contains("agreed") {
            return """
            [
                {
                    "decision": "Move forward with Design Option B",
                    "context": "After team discussion and client feedback",
                    "participants": ["Sarah", "John", "Team"],
                    "timestamp": "2 hours ago",
                    "confidence": "high"
                }
            ]
            """
        } else if prompt.contains("semantic search") {
            return """
            {
                "relevantIndices": [2, 5, 8],
                "explanation": "These messages discuss related topics and contain relevant context"
            }
            """
        }
        
        return "{}"
    }
    
    private func parseSummaryResponse(_ response: String) throws -> ConversationSummary {
        let data = response.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        return ConversationSummary(
            mainTopics: json?["mainTopics"] as? [String] ?? [],
            keyDecisions: json?["keyDecisions"] as? [String] ?? [],
            importantInfo: json?["importantInfo"] as? [String] ?? [],
            summary: json?["summary"] as? String ?? "Summary not available",
            createdAt: Date()
        )
    }
    
    private func parseActionItems(_ response: String, conversationId: String) throws -> [ActionItem] {
        let data = response.data(using: .utf8)!
        let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        
        return jsonArray.map { json in
            ActionItem(
                id: UUID().uuidString,
                conversationId: conversationId,
                task: json["task"] as? String ?? "",
                assignee: json["assignee"] as? String,
                deadline: json["deadline"] as? String,
                priority: ActionPriority(rawValue: json["priority"] as? String ?? "medium") ?? .medium,
                context: json["context"] as? String ?? "",
                completed: false,
                createdAt: Date()
            )
        }
    }
    
    private func parseSemanticSearchResponse(_ response: String, messages: [Message]) throws -> [Message] {
        let data = response.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let indices = json?["relevantIndices"] as? [Int] ?? []
        
        return indices.compactMap { index in
            guard index >= 0 && index < messages.count else { return nil }
            return messages[index]
        }
    }
    
    private func parsePriorityResponse(_ response: String, messageId: String) throws -> MessagePriority {
        let data = response.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        let priorityStr = json?["priority"] as? String ?? "medium"
        let level = PriorityLevel(rawValue: priorityStr) ?? .medium
        
        return MessagePriority(
            messageId: messageId,
            level: level,
            isUrgent: json?["isUrgent"] as? Bool ?? false,
            requiresAction: json?["requiresAction"] as? Bool ?? false,
            reasoning: json?["reasoning"] as? String ?? "",
            suggestedResponse: json?["suggestedResponse"] as? String,
            detectedAt: Date()
        )
    }
    
    private func parseDecisions(_ response: String, conversationId: String) throws -> [Decision] {
        let data = response.data(using: .utf8)!
        let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        
        return jsonArray.map { json in
            Decision(
                id: UUID().uuidString,
                conversationId: conversationId,
                decision: json["decision"] as? String ?? "",
                context: json["context"] as? String ?? "",
                participants: json["participants"] as? [String] ?? [],
                timestamp: json["timestamp"] as? String ?? "",
                confidence: DecisionConfidence(rawValue: json["confidence"] as? String ?? "medium") ?? .medium,
                createdAt: Date()
            )
        }
    }
    
    // Multi-Step Agent Helpers
    
    private func createExecutionPlan(task: AgentTask, context: AgentContext) async throws -> ExecutionPlan {
        // Analyze task and create step-by-step plan
        // This is a simplified version - in production, this would use GPT-4 for planning
        
        var steps: [PlanStep] = []
        
        switch task.type {
        case .analyzeAndSummarize:
            steps = [
                PlanStep(action: "Load conversation messages", dependencies: []),
                PlanStep(action: "Generate summary", dependencies: [0]),
                PlanStep(action: "Extract action items", dependencies: [0]),
                PlanStep(action: "Detect priorities", dependencies: [0]),
                PlanStep(action: "Track decisions", dependencies: [0]),
                PlanStep(action: "Synthesize final report", dependencies: [1, 2, 3, 4])
            ]
        case .extractInsights:
            steps = [
                PlanStep(action: "Analyze conversation patterns", dependencies: []),
                PlanStep(action: "Identify key themes", dependencies: [0]),
                PlanStep(action: "Extract insights", dependencies: [1])
            ]
        case .generateReport:
            steps = [
                PlanStep(action: "Gather all data", dependencies: []),
                PlanStep(action: "Process and analyze", dependencies: [0]),
                PlanStep(action: "Format report", dependencies: [1])
            ]
        }
        
        return ExecutionPlan(steps: steps, estimatedDuration: Double(steps.count) * 2.0)
    }
    
    private func executeStep(step: PlanStep, context: AgentContext, previousSteps: [AgentStep]) async throws -> AgentStep {
        // Execute individual step
        // In production, this would dynamically call appropriate AI functions
        
        let result = AgentStep(
            name: step.action,
            status: .inProgress,
            output: nil
        )
        
        // Simulate step execution (in production, call actual AI functions)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        return AgentStep(
            name: step.action,
            status: .completed,
            output: "Step completed successfully"
        )
    }
    
    private func synthesizeResults(steps: [AgentStep], context: AgentContext) async throws -> String {
        // Synthesize all step results into final output
        let completedSteps = steps.filter { $0.status == .completed }
        return "Successfully completed \(completedSteps.count) steps. Analysis complete."
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Models (Phase A)

// Response from Cloud Functions /aiSummarize
struct AISummaryResponse: Decodable {
    let summary: String
    let sources: [String] // Message IDs
}

struct AIAction: Codable, Identifiable {
    var id: String { sourceMsgId }
    let title: String
    let ownerId: String
    let due: String
    let sourceMsgId: String
}

struct AIActionItemsResponse: Decodable {
    let actions: [AIAction]
}

struct AIPriorityResponse: Decodable {
    let priority: String
    let reasons: [String]
}

struct AIDecision: Identifiable, Decodable {
    let id: String
    let decision: String
    let rationale: String
    let sources: [String]
}

struct AIDecisionsResponse: Decodable {
    let decisions: [AIDecision]
}

struct AISearchHit: Identifiable, Decodable {
    let id: String
    let msgId: String
    let snippet: String
    let score: Double
}

struct AISearchResponse: Decodable {
    let results: [AISearchHit]
}

struct AITranslateResponse: Decodable {
    let translated: String
    let notes: String?
}

// Legacy model (keeping for backward compatibility)
struct CloudSummary: Codable {
    let summary: String
    let sources: [String] // Message IDs
    let createdAt: Date
}

struct ConversationSummary: Codable {
    let mainTopics: [String]
    let keyDecisions: [String]
    let importantInfo: [String]
    let summary: String
    let createdAt: Date
}

struct ActionItem: Identifiable, Codable {
    let id: String
    let conversationId: String
    let task: String
    let assignee: String?
    let deadline: String?
    let priority: ActionPriority
    let context: String
    var completed: Bool
    let createdAt: Date
}

enum ActionPriority: String, Codable {
    case high, medium, low
}

struct MessagePriority: Codable {
    let messageId: String
    let level: PriorityLevel
    let isUrgent: Bool
    let requiresAction: Bool
    let reasoning: String
    let suggestedResponse: String?
    let detectedAt: Date
}

enum PriorityLevel: String, Codable {
    case high, medium, low
}

struct Decision: Identifiable, Codable {
    let id: String
    let conversationId: String
    let decision: String
    let context: String
    let participants: [String]
    let timestamp: String
    let confidence: DecisionConfidence
    let createdAt: Date
}

enum DecisionConfidence: String, Codable {
    case high, medium, low
}

// Multi-Step Agent Models

struct AgentTask {
    let type: AgentTaskType
    let parameters: [String: Any]
}

enum AgentTaskType {
    case analyzeAndSummarize
    case extractInsights
    case generateReport
}

struct AgentContext {
    var conversationId: String?
    var messages: [Message]?
    var timeRange: DateInterval?
    var additionalData: [String: Any] = [:]
    
    func merging(_ updates: [String: Any]) -> AgentContext {
        var new = self
        new.additionalData.merge(updates) { _, new in new }
        return new
    }
}

struct ExecutionPlan {
    let steps: [PlanStep]
    let estimatedDuration: TimeInterval
    
    var description: String {
        "Plan created with \(steps.count) steps (est. \(Int(estimatedDuration))s)"
    }
}

struct PlanStep {
    let action: String
    let dependencies: [Int]
}

struct AgentStep {
    let name: String
    var status: AgentStepStatus
    var output: String?
    var error: String?
    var contextUpdates: [String: Any] = [:]
}

enum AgentStepStatus {
    case pending, inProgress, completed, failed
}

struct AgentResult {
    let task: AgentTask
    let steps: [AgentStep]
    let finalOutput: String
    let duration: TimeInterval
    let success: Bool
}

// MARK: - Errors

enum AIError: LocalizedError {
    case apiError(String)
    case parsingError(String)
    case agentStepFailed(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiError(let msg):
            return "AI API Error: \(msg)"
        case .parsingError(let msg):
            return "Parsing Error: \(msg)"
        case .agentStepFailed(let msg):
            return "Agent Step Failed: \(msg)"
        case .configurationError(let msg):
            return "Configuration Error: \(msg)"
        }
    }
}

