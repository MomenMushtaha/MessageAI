//
//  PerformanceMonitor.swift
//  MessageAI
//
//  Performance monitoring and metrics tracking service
//

import Foundation
import Combine

/// Tracks performance metrics for the MessageAI app
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Metrics
    
    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    
    // MARK: - Private Properties
    
    private var messageTimestamps: [String: Date] = [:] // messageId -> send start time
    private var renderTimestamps: [String: Date] = [:] // viewId -> render start time
    private var metricsHistory: [MetricEntry] = []
    private let maxHistoryCount = 100
    
    private init() {}
    
    // MARK: - Message Send Performance
    
    /// Start tracking a message send operation
    func startMessageSend(messageId: String) {
        messageTimestamps[messageId] = Date()
        print("⏱️ Started tracking message send: \(messageId)")
    }
    
    /// Complete tracking a message send operation
    func completeMessageSend(messageId: String, success: Bool) {
        guard let startTime = messageTimestamps[messageId] else {
            print("⚠️ No start time found for message: \(messageId)")
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let durationMs = Int(duration * 1000)
        
        // Update metrics
        if success {
            metrics.messageSendSuccessCount += 1
            metrics.averageMessageSendTime = updateAverage(
                current: metrics.averageMessageSendTime,
                newValue: duration,
                count: metrics.messageSendSuccessCount
            )
            
            if durationMs < 500 {
                metrics.fastMessagesCount += 1
            }
        } else {
            metrics.messageSendFailureCount += 1
        }
        
        // Record metric
        recordMetric(.messageSend, duration: duration, success: success)
        
        // Cleanup
        messageTimestamps.removeValue(forKey: messageId)
        
        print("📊 Message send completed in \(durationMs)ms - Success: \(success)")
    }
    
    // MARK: - View Render Performance
    
    /// Start tracking a view render operation
    func startViewRender(viewId: String) {
        renderTimestamps[viewId] = Date()
    }
    
    /// Complete tracking a view render operation
    func completeViewRender(viewId: String) {
        guard let startTime = renderTimestamps[viewId] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        let durationMs = Int(duration * 1000)
        
        metrics.averageViewRenderTime = updateAverage(
            current: metrics.averageViewRenderTime,
            newValue: duration,
            count: metrics.viewRenderCount
        )
        metrics.viewRenderCount += 1
        
        recordMetric(.viewRender, duration: duration, success: true)
        
        renderTimestamps.removeValue(forKey: viewId)
        
        if durationMs > 16 { // 60fps = ~16ms per frame
            print("⚠️ Slow view render: \(viewId) took \(durationMs)ms")
        }
    }
    
    // MARK: - Network Performance
    
    /// Track a network request
    func trackNetworkRequest(endpoint: String, duration: TimeInterval, success: Bool, bytesTransferred: Int = 0) {
        if success {
            metrics.networkRequestSuccessCount += 1
            metrics.averageNetworkLatency = updateAverage(
                current: metrics.averageNetworkLatency,
                newValue: duration,
                count: metrics.networkRequestSuccessCount
            )
        } else {
            metrics.networkRequestFailureCount += 1
        }
        
        metrics.totalBytesTransferred += bytesTransferred
        
        recordMetric(.networkRequest, duration: duration, success: success)
        
        print("🌐 Network request to \(endpoint): \(Int(duration * 1000))ms - Success: \(success)")
    }
    
    // MARK: - Scroll Performance
    
    /// Track scroll performance
    func trackScrollPerformance(messageCount: Int, scrollDuration: TimeInterval) {
        metrics.scrollPerformanceScore = calculateScrollScore(messageCount: messageCount, duration: scrollDuration)
        recordMetric(.scrollPerformance, duration: scrollDuration, success: true)
        
        print("📜 Scroll performance: \(messageCount) messages in \(Int(scrollDuration * 1000))ms")
    }
    
    // MARK: - Memory Usage
    
    /// Update memory usage metrics
    func updateMemoryUsage() {
        let usedMemory = getMemoryUsage()
        metrics.memoryUsageMB = usedMemory
        
        if usedMemory > 200 {
            print("⚠️ High memory usage: \(usedMemory)MB")
        }
    }
    
    // MARK: - FPS Tracking
    
    /// Update FPS metrics
    func updateFPS(fps: Double) {
        metrics.currentFPS = fps
        
        if fps < 55 {
            print("⚠️ Low FPS detected: \(Int(fps))")
        }
    }
    
    // MARK: - Reports
    
    /// Generate a performance report
    func generateReport() -> PerformanceReport {
        return PerformanceReport(
            metrics: metrics,
            recentMetrics: Array(metricsHistory.suffix(20)),
            generatedAt: Date()
        )
    }
    
    /// Print a summary of current performance metrics
    func printSummary() {
        print("""
        
        📊 ===== PERFORMANCE SUMMARY =====
        
        📤 Message Sending:
           - Success: \(metrics.messageSendSuccessCount)
           - Failures: \(metrics.messageSendFailureCount)
           - Average Time: \(Int(metrics.averageMessageSendTime * 1000))ms
           - Fast Messages (<500ms): \(metrics.fastMessagesCount)
        
        🖥️ View Rendering:
           - Total Renders: \(metrics.viewRenderCount)
           - Average Time: \(Int(metrics.averageViewRenderTime * 1000))ms
           - Current FPS: \(Int(metrics.currentFPS))
        
        🌐 Network:
           - Successful Requests: \(metrics.networkRequestSuccessCount)
           - Failed Requests: \(metrics.networkRequestFailureCount)
           - Average Latency: \(Int(metrics.averageNetworkLatency * 1000))ms
           - Data Transferred: \(formatBytes(metrics.totalBytesTransferred))
        
        📜 Scroll Performance:
           - Score: \(String(format: "%.2f", metrics.scrollPerformanceScore))/10
        
        💾 Memory:
           - Current Usage: \(Int(metrics.memoryUsageMB))MB
        
        ===================================
        
        """)
    }
    
    /// Reset all metrics
    func resetMetrics() {
        metrics = PerformanceMetrics()
        metricsHistory.removeAll()
        messageTimestamps.removeAll()
        renderTimestamps.removeAll()
        print("🔄 Performance metrics reset")
    }
    
    // MARK: - Private Helpers
    
    private func updateAverage(current: TimeInterval, newValue: TimeInterval, count: Int) -> TimeInterval {
        guard count > 0 else { return newValue }
        return ((current * Double(count - 1)) + newValue) / Double(count)
    }
    
    private func recordMetric(_ type: MetricType, duration: TimeInterval, success: Bool) {
        let entry = MetricEntry(
            type: type,
            timestamp: Date(),
            duration: duration,
            success: success
        )
        
        metricsHistory.append(entry)
        
        // Keep only recent metrics
        if metricsHistory.count > maxHistoryCount {
            metricsHistory.removeFirst(metricsHistory.count - maxHistoryCount)
        }
    }
    
    private func calculateScrollScore(messageCount: Int, duration: TimeInterval) -> Double {
        // Score based on 60fps target (16ms per message render)
        let targetTime = Double(messageCount) * 0.016
        let ratio = targetTime / duration
        return min(ratio * 10, 10.0) // Score out of 10
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // Convert to MB
        }
        return 0
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Models

struct PerformanceMetrics {
    // Message sending metrics
    var messageSendSuccessCount: Int = 0
    var messageSendFailureCount: Int = 0
    var averageMessageSendTime: TimeInterval = 0
    var fastMessagesCount: Int = 0 // Messages sent in < 500ms
    
    // View rendering metrics
    var viewRenderCount: Int = 0
    var averageViewRenderTime: TimeInterval = 0
    var currentFPS: Double = 60.0
    
    // Network metrics
    var networkRequestSuccessCount: Int = 0
    var networkRequestFailureCount: Int = 0
    var averageNetworkLatency: TimeInterval = 0
    var totalBytesTransferred: Int = 0
    
    // Scroll performance
    var scrollPerformanceScore: Double = 10.0 // Out of 10
    
    // Memory metrics
    var memoryUsageMB: Double = 0
    
    var messageSendSuccessRate: Double {
        let total = messageSendSuccessCount + messageSendFailureCount
        guard total > 0 else { return 1.0 }
        return Double(messageSendSuccessCount) / Double(total)
    }
    
    var networkSuccessRate: Double {
        let total = networkRequestSuccessCount + networkRequestFailureCount
        guard total > 0 else { return 1.0 }
        return Double(networkRequestSuccessCount) / Double(total)
    }
}

struct MetricEntry: Identifiable {
    let id = UUID()
    let type: MetricType
    let timestamp: Date
    let duration: TimeInterval
    let success: Bool
}

enum MetricType: String, Codable {
    case messageSend = "Message Send"
    case viewRender = "View Render"
    case networkRequest = "Network Request"
    case scrollPerformance = "Scroll Performance"
}

struct PerformanceReport: Codable {
    let metrics: PerformanceMetrics
    let recentMetrics: [MetricEntry]
    let generatedAt: Date
}

// Make PerformanceMetrics Codable
extension PerformanceMetrics: Codable {}

// Make MetricEntry Codable
extension MetricEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id, type, timestamp, duration, success
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        // Use object_setClass to bypass the 'let' constraint
        // This is a workaround since we can't reassign 'id' after init
        self.init(
            type: try container.decode(MetricType.self, forKey: .type),
            timestamp: try container.decode(Date.self, forKey: .timestamp),
            duration: try container.decode(TimeInterval.self, forKey: .duration),
            success: try container.decode(Bool.self, forKey: .success)
        )
    }
}

