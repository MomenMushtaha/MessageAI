//
//  SkeletonView.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemGray5),
                        Color(.systemGray6),
                        Color(.systemGray5)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating.toggle()
                }
            }
    }
}

struct ConversationRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Avatar Skeleton
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 52, height: 52)
            
            // Content Skeleton
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SkeletonView()
                        .frame(width: 120, height: 16)
                    
                    Spacer()
                    
                    SkeletonView()
                        .frame(width: 40, height: 12)
                }
                
                SkeletonView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 14)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack(spacing: 0) {
        ConversationRowSkeleton()
        Divider().padding(.leading, 76)
        ConversationRowSkeleton()
        Divider().padding(.leading, 76)
        ConversationRowSkeleton()
    }
}

