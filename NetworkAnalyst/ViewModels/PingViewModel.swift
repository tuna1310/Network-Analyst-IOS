//
//  PingViewModel.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine

/// ViewModel điều khiển màn hình Ping ICMP
@MainActor
public final class PingViewModel: ObservableObject {
    public let service = PingService()
    
    @Published public var targetHost: String = "1.1.1.1"
    @Published public var packetCount: Int = 10
    @Published public var intervalSeconds: Double = 0.8
    @Published public var payloadSize: Int = 32
    
    public let popularTargets = [
        ("Cloudflare DNS", "1.1.1.1"),
        ("Google DNS", "8.8.8.8"),
        ("Gateway Router", NetworkInterfaceProvider.getDefaultGateway() ?? "192.168.1.1"),
        ("Apple", "apple.com")
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        service.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    public func startPing() {
        service.startPing(
            host: targetHost,
            count: packetCount,
            interval: intervalSeconds,
            timeout: 1.0,
            payloadSize: payloadSize
        )
    }
    
    public func stopPing() {
        service.stopPing()
    }
}
