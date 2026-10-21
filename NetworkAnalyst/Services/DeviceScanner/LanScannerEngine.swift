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
        guard !isScanning else { return }
        isScanning = true
        progress = 0.0
        currentHost = "Đang khởi tạo cấu hình giao diện mạng..."
        discoveredDevices.removeAll()
        errorMessage = nil
        
        // 1. Lấy thông tin interface Wi-Fi hiện tại
        guard let wifi = NetworkInterfaceProvider.getPrimaryWiFiInterface(),
              let localIP = wifi.ipv4Address else {
            self.errorMessage = "Không tìm thấy giao diện Wi-Fi đang hoạt động. Vui lòng kết nối Wi-Fi để quét mạng LAN."
            self.isScanning = false
            return
        }
        
        let gatewayIP = wifi.gateway ?? NetworkInterfaceProvider.getDefaultGateway()
        let hostRange = wifi.subnetHostRange
        
        guard !hostRange.isEmpty else {
            self.errorMessage = "Không thể xác định dải địa chỉ IP của mạng nội bộ (Subnet)."
            self.isScanning = false
            return
        }
        
        // Luôn đưa chính thiết bị này (Self) và Gateway vào danh sách đầu tiên
        var initialList: [DiscoveredDevice] = []
        
        let selfDevice = DiscoveredDevice(
            ipAddress: localIP,
            hostname: HostNameResolver.getDeviceName(),
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
                                timeout: 0.45
                            ) {
                                return DiscoveredDevice(
                                    ipAddress: targetIP,
                                    hostname: probeRes.hostname,
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
                        self.currentHost = "Đang kiểm tra \(nextIP)..."
                        let isGw = (nextIP == gatewayIP)
                        let isMe = (nextIP == localIP)
                        group.addTask {
                            if let probeRes = await prober.probe(
                                ipAddress: nextIP,
                                isGateway: isGw,
                                isSelf: isMe,
                                timeout: 0.45
                            ) {
                                return DiscoveredDevice(
                                    ipAddress: nextIP,
                                    hostname: probeRes.hostname,
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
                    if results[idx].hostname == nil {
                        results[idx].hostname = b.name
                    }
                    if !results[idx].discoveryMethods.contains(.bonjour) {
                        results[idx].discoveryMethods.append(.bonjour)
                    }
                }
            }
            
            self.discoveredDevices = results
            self.progress = 1.0
            self.currentHost = "Hoàn tất quét. Tìm thấy \(results.count) thiết bị."
            self.isScanning = false
        }
    }
    
    /// Hủy phiên quét đang chạy
    public func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentHost = "Đã dừng quét."
    }
}
