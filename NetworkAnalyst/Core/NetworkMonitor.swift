//
//  NetworkMonitor.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import Combine

/// Quan sát trạng thái kết nối mạng qua NWPathMonitor
@MainActor
public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var isWiFi: Bool = false
    @Published public private(set) var isCellular: Bool = false
    @Published public private(set) var isEthernet: Bool = false
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var isConstrained: Bool = false
    @Published public private(set) var supportsIPv4: Bool = false
    @Published public private(set) var supportsIPv6: Bool = false
    @Published public private(set) var statusDescription: String = "Đang kiểm tra kết nối..."
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.networkanalyst.networkmonitor", qos: .utility)
    
    public init() {
        self.monitor = NWPathMonitor()
        start()
    }
    
    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.updatePath(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    public func stop() {
        monitor.cancel()
    }
    
    private func updatePath(_ path: NWPath) {
        self.isConnected = (path.status == .satisfied)
        self.isWiFi = path.usesInterfaceType(.wifi)
        self.isCellular = path.usesInterfaceType(.cellular)
        self.isEthernet = path.usesInterfaceType(.wiredEthernet)
        self.isExpensive = path.isExpensive
        self.isConstrained = path.isConstrained
        self.supportsIPv4 = path.supportsIPv4
        self.supportsIPv6 = path.supportsIPv6
        
        switch path.status {
        case .satisfied:
            if isWiFi {
                self.statusDescription = "Đã kết nối Wi-Fi"
            } else if isCellular {
                self.statusDescription = "Đã kết nối Mạng di động (Cellular)"
            } else if isEthernet {
                self.statusDescription = "Đã kết nối Cáp mạng (Ethernet)"
            } else {
                self.statusDescription = "Đã kết nối Internet"
            }
        case .unsatisfied:
            self.statusDescription = "Không có kết nối mạng"
        case .requiresConnection:
            self.statusDescription = "Đang chờ thiết lập kết nối..."
        @unknown default:
            self.statusDescription = "Trạng thái không xác định"
        }
    }
}
