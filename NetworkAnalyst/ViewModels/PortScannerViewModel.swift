//
//  PortScannerViewModel.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine
import NetworkCore
#if canImport(UIKit)
import UIKit
#endif

/// Bộ lọc trạng thái hiển thị danh sách cổng
public enum PortFilterOption: String, CaseIterable, Identifiable {
    case openOnly
    case all
    case closed
    case filtered
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .openOnly: return String(localized: "port.filter.open_only", defaultValue: "Chỉ cổng mở")
        case .all: return String(localized: "port.filter.all", defaultValue: "Tất cả")
        case .closed: return String(localized: "port.filter.closed", defaultValue: "Đóng")
        case .filtered: return String(localized: "port.filter.filtered", defaultValue: "Bị chặn")
        }
    }
}

/// ViewModel điều khiển màn hình Quét cổng Port Scanner với 3 chế độ (Phổ biến, Tùy chọn, Toàn dải)
@MainActor
public final class PortScannerViewModel: ObservableObject {
    public var engine = PortScannerEngine()
    
    @Published public var targetHost: String = ""
    @Published public var scanMode: PortScanMode = .popular
    @Published public var selectedPreset: PortScanPreset = .top20
    @Published public var customRangeInput: String = "80, 443, 8000-8100"
    @Published public var customRangeError: String? = nil
    
    @Published public var showFullScanAlert: Bool = false
    @Published public var estimatedDurationText: String = ""
    @Published public var filterOption: PortFilterOption = .openOnly
    @Published public var shareSheetPresented: Bool = false
    @Published public var backgroundPausedWarning: Bool = false
    @Published public var showDisclaimerModal: Bool = false
    
    private var previousIdleTimerDisabled: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    public init(initialHost: String = "") {
        if !initialHost.isEmpty {
            self.targetHost = initialHost
        } else if let wifi = NetworkInterfaceInfo.getPrimaryWiFiInterface(),
                  let gw = wifi.gateway ?? NetworkInterfaceInfo.getDefaultGateway() {
            self.targetHost = gw
        } else {
            self.targetHost = "127.0.0.1"
        }
        
        #if canImport(UIKit)
        self.previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        #endif
        
        engine.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.objectWillChange.send()
                
                // Đồng bộ giữ màn hình sáng khi đang quét
                let active = self.engine.isScanning && !self.engine.isPaused
                self.setScreenIdleTimer(disabled: active)
            }
            .store(in: &cancellables)
            
        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.engine.isScanning && !self.engine.isPaused {
                    self.pauseScan()
                    self.backgroundPausedWarning = true
                }
            }
            .store(in: &cancellables)
        #endif
    }
    
    deinit {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
        #endif
    }
    
    private func setScreenIdleTimer(disabled: Bool) {
        #if canImport(UIKit)
        if disabled {
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
        }
        #endif
    }
    
    public var displayedPorts: [ScannedPort] {
        switch filterOption {
        case .openOnly:
            return engine.openPorts
        case .all:
            return engine.allScannedResults
        case .closed:
            return engine.allScannedResults.filter { $0.status == .closed }
        case .filtered:
            return engine.allScannedResults.filter { $0.status == .filtered }
        }
    }
    
    /// Bắt đầu quét dựa trên chế độ hiện tại
    public func startScan() {
        guard AppConfigManager.shared.config.hasAcceptedScanDisclaimer else {
            showDisclaimerModal = true
            return
        }
        
        customRangeError = nil
        backgroundPausedWarning = false
        
        switch scanMode {
        case .popular:
            let ports = selectedPreset.ports
            engine.startScan(host: targetHost, ports: ports)
            
        case .custom:
            let parseResult = PortRangeParser.parse(customRangeInput)
            switch parseResult {
            case .success(let ports):
                engine.startScan(host: targetHost, ports: ports)
            case .failure(let err):
                customRangeError = err.localizedDescription
            }
            
        case .full:
            // Tính toán thời gian ước tính và hiển thị hộp thoại xác nhận
            let (_, estString) = PortRangeParser.estimateScanDuration(
                portCount: 65535,
                concurrency: engine.maxConcurrency,
                averageTimeoutSeconds: 0.8
            )
            estimatedDurationText = estString
            showFullScanAlert = true
        }
    }
    
    /// Xác nhận thực hiện quét toàn bộ 65,535 cổng
    public func confirmAndStartFullScan() {
        let allPorts = Array(1...65535)
        engine.startScan(host: targetHost, ports: allPorts)
    }
    
    public func pauseScan() {
        engine.pauseScan()
    }
    
    public func resumeScan() {
        backgroundPausedWarning = false
        engine.resumeScan()
    }
    
    public func stopScan() {
        engine.stopScan()
    }
    
    public func exportSummary() -> String {
        var text = String(localized: "portscan.export.header", defaultValue: "=== BÁO CÁO QUÉT CỔNG MẠNG (NETWORK ANALYST) ===\n")
        text += String(format: String(localized: "portscan.export.target_format", defaultValue: "Mục tiêu: %@\n"), targetHost)
        text += String(format: String(localized: "portscan.export.mode_format", defaultValue: "Chế độ: %@\n"), scanMode.title)
        text += String(format: String(localized: "portscan.export.time_format", defaultValue: "Thời gian: %@\n"), "\(Date())")
        text += String(format: String(localized: "portscan.export.total_format", defaultValue: "Tổng số cổng đã quét: %d/%d\n"), engine.scannedCount, engine.totalCount)
        text += String(format: String(localized: "portscan.export.open_format", defaultValue: "Số cổng mở: %d\n\n"), engine.openPorts.count)
        text += String(localized: "portscan.export.open_list_header", defaultValue: "DANH SÁCH CỔNG MỞ:\n")
        for p in engine.openPorts {
            let rttStr = p.rttMs != nil ? String(format: "%.1f ms", p.rttMs!) : "--"
            let bannerStr = p.banner != nil ? " | Banner: \(p.banner!)" : ""
            text += String(format: String(localized: "portscan.export.port_row_format", defaultValue: "- Cổng %d [%@]: %@ (RTT: %@)%@\n"), p.port, p.serviceName, p.serviceDescription, rttStr, bannerStr)
        }
        return text
    }
}
