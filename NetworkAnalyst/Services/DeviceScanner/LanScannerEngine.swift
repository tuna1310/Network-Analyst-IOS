//
//  LanScannerEngine.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import Combine

/// Quản lý toàn bộ tiến trình quét mạng LAN với Concurrency giới hạn và kết hợp Bonjour + Unicast Probing
@MainActor
public final class LanScannerEngine: ObservableObject {
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var currentHost: String = ""
    @Published public private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published public private(set) var errorMessage: String? = nil
    
    private var scanTask: Task<Void, Never>?
    private let maxConcurrentProbes = 60
    
    public init() {}
    
    /// Bắt đầu phiên quét toàn bộ dải mạng LAN hiện tại
    public func startScan() {
        guard AppConfigManager.shared.config.hasAcceptedScanDisclaimer else {
            self.errorMessage = String(localized: "lan.error.disclaimer_required", defaultValue: "Yêu cầu xác nhận cam kết chỉ quét mạng được ủy quyền trước khi thực hiện.")
            self.isScanning = false
            return
        }
        guard !isScanning else { return }
        isScanning = true
        progress = 0.0
        currentHost = String(localized: "lan.status.initializing", defaultValue: "Đang khởi tạo cấu hình giao diện mạng...")
        discoveredDevices.removeAll()
        errorMessage = nil
        
        // 1. Lấy thông tin interface Wi-Fi hiện tại
        guard let wifi = NetworkInterfaceProvider.getPrimaryWiFiInterface(),
              let localIP = wifi.ipv4Address else {
            self.errorMessage = String(localized: "lan.error.no_wifi", defaultValue: "Không tìm thấy giao diện Wi-Fi đang hoạt động. Vui lòng kết nối Wi-Fi để quét mạng LAN.")
            self.isScanning = false
            return
        }
        
        let gatewayIP = wifi.gateway ?? NetworkInterfaceProvider.getDefaultGateway()
        let hostRange = wifi.subnetHostRange
        
        guard !hostRange.isEmpty else {
            self.errorMessage = String(localized: "lan.error.no_subnet", defaultValue: "Không thể xác định dải địa chỉ IP của mạng nội bộ (Subnet).")
            self.isScanning = false
            return
        }
        
        // Luôn đưa chính thiết bị này (Self) và Gateway vào danh sách đầu tiên
        var initialList: [DiscoveredDevice] = []
        
        let selfDevice = DiscoveredDevice(
            ipAddress: localIP,
            ipv6Address: wifi.ipv6Address,
            ipv6StatusExplanation: wifi.ipv6Address == nil ? String(localized: "lan.self_no_ipv6", defaultValue: "Thiết bị chưa được cấp địa chỉ IPv6") : nil,
            hostname: HostNameResolver.getDeviceName(),
            hostnameSource: .mDNS,
            macAddress: "iOS Sandbox (Protected)",
            vendor: "Apple Inc.",
            deviceType: .appleDevice,
            openPorts: [],
            bonjourServices: [],
            rttMs: 0.1,
            isGateway: (localIP == gatewayIP),
            isSelf: true,
            discoveryMethods: [.localInterface]
        )
        initialList.append(selfDevice)
        self.discoveredDevices = initialList
        
        scanTask = Task {
            // 2. Chạy quét Bonjour song song
            async let bonjourTask: [BonjourDiscoveredService] = BonjourBrowser().browse(duration: 2.5)
            
            // 3. Quét dải IP bằng UnicastProber với TaskGroup có giới hạn đồng thời
            let prober = UnicastProber()
            let totalHosts = hostRange.count
            var scannedCount = 0
            
            // Dùng buffer để giới hạn concurrency
            var results: [DiscoveredDevice] = initialList
            
            await withTaskGroup(of: DiscoveredDevice?.self) { group in
                var hostIterator = hostRange.makeIterator()
                
                // Nạp trước maxConcurrentProbes tasks
                for _ in 0..<maxConcurrentProbes {
                    if let targetIP = hostIterator.next() {
                        let isGw = (targetIP == gatewayIP)
                        let isMe = (targetIP == localIP)
                        group.addTask {
                            if let probeRes = await prober.probe(
                                ipAddress: targetIP,
                                isGateway: isGw,
                                isSelf: isMe,
                                gatewayIP: gatewayIP,
                                timeout: 0.45
                            ) {
                                return DiscoveredDevice(
                                    ipAddress: targetIP,
                                    ipv6Address: probeRes.ipv6Address,
                                    ipv6StatusExplanation: probeRes.ipv6StatusExplanation,
                                    hostname: probeRes.hostname,
                                    hostnameSource: probeRes.hostnameSource,
                                    macAddress: probeRes.macAddress,
                                    vendor: probeRes.vendor,
                                    deviceType: probeRes.deviceType,
                                    openPorts: probeRes.openPorts,
                                    bonjourServices: [],
                                    rttMs: probeRes.rttMs,
                                    isGateway: isGw,
                                    isSelf: isMe,
                                    discoveryMethods: probeRes.methods
                                )
                            }
                            return nil
                        }
                    }
                }
                
                // Khi một task hoàn thành, thêm task mới nếu còn IP
                for await device in group {
                    scannedCount += 1
                    self.progress = Double(scannedCount) / Double(totalHosts)
                    
                    if let device = device {
                        if !results.contains(where: { $0.ipAddress == device.ipAddress }) {
                            results.append(device)
                            // Sắp xếp theo IP tăng dần
                            self.discoveredDevices = results.sorted {
                                if $0.isGateway { return true }
                                if $1.isGateway { return false }
                                if $0.isSelf { return true }
                                if $1.isSelf { return false }
                                return $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending
                            }
                        }
                    }
                    
                    if let nextIP = hostIterator.next() {
                        let checkingFormat = String(localized: "lan.status.checking_host", defaultValue: "Đang kiểm tra %@...")
                        self.currentHost = String(format: checkingFormat, nextIP)
                        let isGw = (nextIP == gatewayIP)
                        let isMe = (nextIP == localIP)
                        group.addTask {
                            if let probeRes = await prober.probe(
                                ipAddress: nextIP,
                                isGateway: isGw,
                                isSelf: isMe,
                                gatewayIP: gatewayIP,
                                timeout: 0.45
                            ) {
                                return DiscoveredDevice(
                                    ipAddress: nextIP,
                                    ipv6Address: probeRes.ipv6Address,
                                    ipv6StatusExplanation: probeRes.ipv6StatusExplanation,
                                    hostname: probeRes.hostname,
                                    hostnameSource: probeRes.hostnameSource,
                                    macAddress: probeRes.macAddress,
                                    vendor: probeRes.vendor,
                                    deviceType: probeRes.deviceType,
                                    openPorts: probeRes.openPorts,
                                    bonjourServices: [],
                                    rttMs: probeRes.rttMs,
                                    isGateway: isGw,
                                    isSelf: isMe,
                                    discoveryMethods: probeRes.methods
                                )
                            }
                            return nil
                        }
                    }
                }
            }
            
            // 4. Kết hợp kết quả Bonjour
            let bonjourResults = await bonjourTask
            for b in bonjourResults {
                if let ip = b.ipAddress, let idx = results.firstIndex(where: { $0.ipAddress == ip }) {
                    results[idx].bonjourServices.append("\(b.name) (\(b.serviceType))")
                    if results[idx].hostnameSource == nil || results[idx].hostnameSource != .mDNS {
                        results[idx].hostname = b.name
                        results[idx].hostnameSource = .mDNS
                    }
                    if !results[idx].discoveryMethods.contains(.bonjour) {
                        results[idx].discoveryMethods.append(.bonjour)
                    }
                }
            }
            
            self.discoveredDevices = results
            self.progress = 1.0
            self.currentHost = String(format: String(localized: "lan.status.completed_format", defaultValue: "Hoàn tất quét. Tìm thấy %d thiết bị."), results.count)
            self.isScanning = false
            
            // Ghi nhận vào lịch sử quét cục bộ
            let targetRange = hostRange.first.map { "\($0)/\(wifi.subnetMask ?? "24")" } ?? localIP
            ScanHistoryManager.shared.addEntry(
                type: .lan,
                target: targetRange,
                summary: String(format: String(localized: "lan.history.summary_format", defaultValue: "Tìm thấy %d thiết bị trong mạng nội bộ"), results.count),
                details: results.map { d in
                    let vendorStr = d.vendor ?? String(localized: "lan.vendor_unknown", defaultValue: "Chưa rõ")
                    let ipv6Str = d.ipv6Address ?? String(localized: "lan.ipv6_none", defaultValue: "Không có")
                    return "\(d.ipAddress) | \(d.displayName) | \(vendorStr) | IPv6: \(ipv6Str)"
                }.joined(separator: "\n")
            )
        }
    }
    
    /// Hủy phiên quét đang chạy
    public func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentHost = String(localized: "lan.status.stopped", defaultValue: "Đã dừng quét.")
    }
}
