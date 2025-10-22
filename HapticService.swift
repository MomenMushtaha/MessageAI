//
//  HapticService.swift
//  MessageAI
//
//  Created by MessageAI
//

import Foundation
import CoreHaptics
import UIKit
import SwiftUI

@MainActor
class HapticService {
    static let shared = HapticService()
    
    private var hapticEngine: CHHapticEngine?
    private let impactFeedback = UIImpactFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        // Check if the device supports haptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("🔇 Device does not support haptics")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            // Handle engine stopped/reset events
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("🔇 Haptic engine stopped: \(reason)")
                Task { @MainActor in
                    self?.restartEngine()
                }
            }
            
            hapticEngine?.resetHandler = { [weak self] in
                print("🔄 Haptic engine reset")
                Task { @MainActor in
                    self?.restartEngine()
                }
            }
            
            print("✅ Haptic engine started successfully")
        } catch {
            print("❌ Failed to start haptic engine: \(error.localizedDescription)")
            hapticEngine = nil
        }
    }
    
    private func restartEngine() {
        do {
            try hapticEngine?.start()
        } catch {
            print("❌ Failed to restart haptic engine: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        // Fallback to UIKit feedback if CoreHaptics fails
        impactFeedback.impactOccurred(intensity: CGFloat(intensityFor(style)))
        
        // Try CoreHaptics for richer feedback if available
        playCustomImpact(intensity: intensityFor(style))
    }
    
    func selection() {
        selectionFeedback.selectionChanged()
        playCustomSelection()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationFeedback.notificationOccurred(type)
        playCustomNotification(type)
    }
    
    func messageSent() {
        impact(.light)
    }
    
    func messageReceived() {
        selection()
    }
    
    func buttonPress() {
        impact(.light)
    }
    
    func error() {
        notification(.error)
    }
    
    func success() {
        notification(.success)
    }
    
    // MARK: - Private CoreHaptics Methods
    
    private func intensityFor(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> Float {
        switch style {
        case .light: return 0.5
        case .medium: return 0.7
        case .heavy: return 1.0
        case .soft: return 0.3
        case .rigid: return 0.9
        @unknown default: return 0.7
        }
    }
    
    private func playCustomImpact(intensity: Float) {
        guard let engine = hapticEngine else { return }
        
        do {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensityParam],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Silently fail - we already have UIKit fallback
        }
    }
    
    private func playCustomSelection() {
        guard let engine = hapticEngine else { return }
        
        do {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensity],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Silently fail - we already have UIKit fallback
        }
    }
    
    private func playCustomNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard let engine = hapticEngine else { return }
        
        do {
            let events: [CHHapticEvent]
            
            switch type {
            case .success:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ], relativeTime: 0.1)
                ]
            case .warning:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ], relativeTime: 0)
                ]
            case .error:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ], relativeTime: 0.1),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ], relativeTime: 0.2)
                ]
            @unknown default:
                events = []
            }
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Silently fail - we already have UIKit fallback
        }
    }
}

// MARK: - SwiftUI Integration

extension View {
    func onTapHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.onTapGesture {
            HapticService.shared.impact(style)
        }
    }
}
