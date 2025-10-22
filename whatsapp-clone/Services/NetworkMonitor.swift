//
//  NetworkMonitor.swift
//  whatsapp-clone
//
//  Created by MessageAI
//

import Foundation
import Network
import Combine

@MainActor
class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    static let shared = NetworkMonitor()
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                self.isConnected = path.status == .satisfied
                self.connectionType = path.availableInterfaces.first?.type
                
                if path.status == .satisfied {
                    print("🌐 Network: Connected (\(path.availableInterfaces.first?.type.debugDescription ?? "unknown"))")
                } else {
                    print("📵 Network: Disconnected")
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    nonisolated func stopMonitoring() {
        monitor.cancel()
    }
}

extension NWInterface.InterfaceType {
    var debugDescription: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}

