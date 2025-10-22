//
//  AppIconView.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI

struct AppIconView: View {
    let size: CGFloat
    
    init(size: CGFloat = 60) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Speech bubble background with gradient
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.25, blue: 0.85), // Deep purple
                            Color(red: 0.35, green: 0.45, blue: 0.95), // Bright purple-blue
                            Color(red: 0.15, green: 0.65, blue: 1.0)   // Bright blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.25), radius: size * 0.08, x: 0, y: size * 0.05)
            
            // Network/connection icon
            NetworkIconView(size: size * 0.5)
                .foregroundStyle(.white)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct NetworkIconView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Central circle with blue color to match the logo
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.65, blue: 1.0), // Bright blue
                            Color(red: 0.05, green: 0.45, blue: 0.85) // Darker blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.35, height: size * 0.35)
                .shadow(color: .black.opacity(0.15), radius: size * 0.02)
            
            // Connection points
            ForEach(0..<8) { index in
                let angle = Angle.degrees(Double(index) * 45)
                let radius = size * 0.4
                
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.12, height: size * 0.12)
                    .offset(
                        x: cos(angle.radians) * radius,
                        y: sin(angle.radians) * radius
                    )
                    .shadow(color: .black.opacity(0.1), radius: size * 0.01)
                
                // Connection lines
                Rectangle()
                    .fill(.white.opacity(0.9))
                    .frame(width: size * 0.025, height: radius * 0.6)
                    .offset(
                        x: cos(angle.radians) * radius * 0.5,
                        y: sin(angle.radians) * radius * 0.5
                    )
                    .rotationEffect(angle + .degrees(90))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Previews

#Preview("App Icon - Small") {
    HStack(spacing: 20) {
        AppIconView(size: 30)
        AppIconView(size: 40)
        AppIconView(size: 60)
        AppIconView(size: 80)
    }
    .padding()
    .background(.gray.opacity(0.1))
}

#Preview("App Icon - Large") {
    VStack(spacing: 30) {
        AppIconView(size: 120)
        AppIconView(size: 180)
    }
    .padding()
    .background(.gray.opacity(0.1))
}

#Preview("Network Icon Only") {
    VStack(spacing: 20) {
        NetworkIconView(size: 40)
        NetworkIconView(size: 60)
        NetworkIconView(size: 80)
    }
    .padding()
    .background(.blue.opacity(0.2))
}