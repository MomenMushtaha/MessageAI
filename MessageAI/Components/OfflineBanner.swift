//
//  OfflineBanner.swift
//  MessageAI
//
//  Created by MessageAI
//

import SwiftUI

struct OfflineBanner: View {
    let isConnected: Bool
    
    var body: some View {
        if !isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                Text("No Internet Connection")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VStack {
        OfflineBanner(isConnected: false)
        Spacer()
    }
}



