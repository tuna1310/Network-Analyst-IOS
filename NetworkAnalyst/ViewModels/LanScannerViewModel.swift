//
//  LanScannerViewModel.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine

/// ViewModel điều khiển màn hình Quét thiết bị mạng LAN
@MainActor
public final class LanScannerViewModel: ObservableObject {
    public let engine = LanScannerEngine()
    
    @Published public var searchText: String = ""
    @Published public var selectedFilter: DeviceType? = nil
    @Published public var selectedDeviceForDetail: DiscoveredDevice? = nil
    @Published public var navigateToPortScannerWithIP: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        engine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    public var filteredDevices: [DiscoveredDevice] {
        var list = engine.discoveredDevices
        
        if let filter = selectedFilter {
            list = list.filter { $0.deviceType == filter }
        }
        
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            list = list.filter {
                $0.ipAddress.contains(query) ||
                ($0.hostname?.lowercased().contains(query) ?? false) ||
                ($0.vendor?.lowercased().contains(query) ?? false)
            }
        }
        return list
    }
    
    public func startScan() {
        engine.startScan()
    }
    
    public func stopScan() {
        engine.stopScan()
    }
}
