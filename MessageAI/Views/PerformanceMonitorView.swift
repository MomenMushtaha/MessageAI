//
//  PerformanceMonitorView.swift
//  MessageAI
//
//  View for displaying real-time performance metrics
//

import SwiftUI

struct PerformanceMonitorView: View {
    @ObservedObject var monitor = PerformanceMonitor.shared
    @State private var showingDetailedMetrics = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Overall Health Section
                Section("Overall Health") {
                    HealthIndicator(
                        title: "Message Send Success Rate",
                        value: monitor.metrics.messageSendSuccessRate * 100,
                        unit: "%",
                        isGood: monitor.metrics.messageSendSuccessRate > 0.95
                    )
                    
                    HealthIndicator(
                        title: "Network Success Rate",
                        value: monitor.metrics.networkSuccessRate * 100,
                        unit: "%",
                        isGood: monitor.metrics.networkSuccessRate > 0.90
                    )
                    
                    HealthIndicator(
                        title: "Current FPS",
                        value: monitor.metrics.currentFPS,
                        unit: "",
                        isGood: monitor.metrics.currentFPS >= 55
                    )
                }
                
                // Message Performance Section
                Section("Message Performance") {
                    MetricRow(
                        title: "Messages Sent",
                        value: "\(monitor.metrics.messageSendSuccessCount)"
                    )
                    
                    MetricRow(
                        title: "Average Send Time",
                        value: "\(Int(monitor.metrics.averageMessageSendTime * 1000))ms"
                    )
                    
                    MetricRow(
                        title: "Fast Messages (<500ms)",
                        value: "\(monitor.metrics.fastMessagesCount)"
                    )
                    
                    if monitor.metrics.messageSendFailureCount > 0 {
                        MetricRow(
                            title: "Failed Messages",
                            value: "\(monitor.metrics.messageSendFailureCount)",
                            isWarning: true
                        )
                    }
                }
                
                // View Performance Section
                Section("View Performance") {
                    MetricRow(
                        title: "View Renders",
                        value: "\(monitor.metrics.viewRenderCount)"
                    )
                    
                    MetricRow(
                        title: "Average Render Time",
                        value: "\(Int(monitor.metrics.averageViewRenderTime * 1000))ms"
                    )
                    
                    HealthIndicator(
                        title: "Scroll Performance",
                        value: monitor.metrics.scrollPerformanceScore,
                        unit: "/10",
                        isGood: monitor.metrics.scrollPerformanceScore >= 7.0
                    )
                }
                
                // Network Performance Section
                Section("Network") {
                    MetricRow(
                        title: "Successful Requests",
                        value: "\(monitor.metrics.networkRequestSuccessCount)"
                    )
                    
                    MetricRow(
                        title: "Average Latency",
                        value: "\(Int(monitor.metrics.averageNetworkLatency * 1000))ms"
                    )
                    
                    MetricRow(
                        title: "Data Transferred",
                        value: formatBytes(monitor.metrics.totalBytesTransferred)
                    )
                    
                    if monitor.metrics.networkRequestFailureCount > 0 {
                        MetricRow(
                            title: "Failed Requests",
                            value: "\(monitor.metrics.networkRequestFailureCount)",
                            isWarning: true
                        )
                    }
                }
                
                // Memory Section
                Section("Memory") {
                    MetricRow(
                        title: "Memory Usage",
                        value: "\(Int(monitor.metrics.memoryUsageMB))MB"
                    )
                    
                    Button(action: {
                        monitor.updateMemoryUsage()
                    }) {
                        Label("Refresh Memory Usage", systemImage: "arrow.clockwise")
                    }
                }
                
                // Actions Section
                Section("Actions") {
                    Button(action: {
                        monitor.printSummary()
                    }) {
                        Label("Print Summary to Console", systemImage: "printer")
                    }
                    
                    Button(role: .destructive, action: {
                        monitor.resetMetrics()
                    }) {
                        Label("Reset Metrics", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Performance Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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

struct MetricRow: View {
    let title: String
    let value: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(isWarning ? .red : .secondary)
        }
    }
}

struct HealthIndicator: View {
    let title: String
    let value: Double
    let unit: String
    let isGood: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(String(format: "%.1f\(unit)", value))
                    .font(.body.monospacedDigit())
                
                Circle()
                    .fill(isGood ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

#Preview {
    PerformanceMonitorView()
}

