//
//  PortScannerViewModel.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine

/// ViewModel điều khiển màn hình Quét cổng Port Scanner
@MainActor
public final class PortScannerViewModel: ObservableObject {
    public let engine = PortScannerEngine()
    
    @Published public var targetHost: String = ""
    @Published public var selectedPreset: PortScanPreset = .top20
    @Published public var customStartPort: String = "1"
    @Published public var customEndPort: String = "1024"
    @Published public var onlyShowOpenPorts: Bool = true
    @Published public var shareSheetPresented: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(initialHost: String = "") {
        if !initialHost.isEmpty {
            self.targetHost = initialHost
        } else if let wifi = NetworkInterfaceProvider.getPrimaryWiFiInterface(),
                  let gw = wifi.gateway ?? NetworkInterfaceProvider.getDefaultGateway() {
            self.targetHost = gw
        } else {
            self.targetHost = "127.0.0.1"
        }
        
        engine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    public var displayedPorts: [ScannedPort] {
        if onlyShowOpenPorts {
            return engine.openPorts
        } else {
            return engine.allScannedResults
        }
    }
    
    public func startScan() {
        let ports: [Int]
        switch selectedPreset {
        case .top20, .top100:
            ports = selectedPreset.ports
        case .custom:
            let start = Int(customStartPort) ?? 1
            let end = Int(customEndPort) ?? 1024
            ports = PortScanPreset.custom(start: start, end: end).ports
        }
        
        engine.startScan(host: targetHost, ports: ports)
    }
    
    public func stopScan() {
        engine.stopScan()
    }
    
    public func exportSummary() -> String {
        var text = "=== BÁO CÁO QUÉT CỔNG MẠNG (NETWORK ANALYST) ===\n"
        text += "Mục tiêu: \(targetHost)\n"
        text += "Thời gian: \(Date())\n"
        text += "Tổng số cổng quét: \(engine.scannedCount)\n"
        text += "Số cổng mở phát hiện: \(engine.openPorts.count)\n\n"
        text += "DANH SÁCH CỔNG MỞ:\n"
        for p in engine.openPorts {
            let rttStr = p.rttMs != nil ? String(format: "%.1f ms", p.rttMs!) : "--"
            text += "- Cổng \(p.port) [\(p.serviceName)]: \(p.serviceDescription) (RTT: \(rttStr))\n"
        }
        return text
    }
}
