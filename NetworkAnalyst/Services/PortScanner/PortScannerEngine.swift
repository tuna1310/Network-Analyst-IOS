//
//  PortScannerEngine.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import Combine
import NetworkCore

/// Engine quét cổng TCP sử dụng NWConnection và TaskGroup với cửa sổ trượt (Sliding Window Concurrency)
/// Hỗ trợ giới hạn đồng thời cấu hình được (mặc định 200), timeout thích ứng LAN/Internet,
/// phân loại 4 trạng thái (Open, Closed, Filtered, Error), Tạm dừng / Tiếp tục / Hủy an toàn không rò rỉ FD
@MainActor
public final class PortScannerEngine: ObservableObject {
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var scannedCount: Int = 0
    @Published public private(set) var totalCount: Int = 0
    @Published public private(set) var openPorts: [ScannedPort] = []
    @Published public private(set) var allScannedResults: [ScannedPort] = []
    @Published public private(set) var currentPort: Int = 0
    @Published public private(set) var scanRate: Double = 0.0 // Ports/giây
    @Published public private(set) var statusMessage: String = "Sẵn sàng"
    
    // Cấu hình
    @Published public var maxConcurrency: Int = 200 // Mặc định 200, trần cứng 250
    @Published public var enableBannerGrabbing: Bool = false
    
    private var scanTask: Task<Void, Never>?
    private var remainingPorts: [Int] = []
    private var targetHost: String = ""
    private var isPrivateTarget: Bool = false
    
    public init() {}
    
    /// Bắt đầu hoặc tiếp tục quét danh sách các cổng
    public func startScan(host: String, ports: [Int]) {
        guard !isScanning else { return }
        guard !ports.isEmpty else {
            statusMessage = "Danh sách cổng trống."
            return
        }
        
        self.targetHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isPrivateTarget = isPrivateIP(self.targetHost)
        self.remainingPorts = ports
        self.totalCount = ports.count
        self.scannedCount = 0
        self.progress = 0.0
        self.openPorts.removeAll()
        self.allScannedResults.removeAll()
        self.isScanning = true
        self.isPaused = false
        self.statusMessage = "Đang quét \(targetHost)..."
        
        runScanLoop()
    }
    
    /// Tạm dừng quét nhưng giữ nguyên kết quả đã phát hiện
    public func pauseScan() {
        guard isScanning && !isPaused else { return }
        isPaused = true
        statusMessage = "Đã tạm dừng (Đã quét \(scannedCount)/\(totalCount) cổng)."
        scanTask?.cancel()
        scanTask = nil
    }
    
    /// Tiếp tục quét phần cổng còn lại
    public func resumeScan() {
        guard isScanning && isPaused else { return }
        isPaused = false
        statusMessage = "Đang tiếp tục quét \(targetHost)..."
        runScanLoop()
    }
    
    /// Dừng và hủy hoàn toàn tiến trình quét, giải phóng tài nguyên mạng
    public func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        isPaused = false
        statusMessage = "Đã dừng quét."
    }
    
    // MARK: - Core Concurrency Scan Loop
    private func runScanLoop() {
        let host = self.targetHost
        let concurrencyLimit = min(max(10, self.maxConcurrency), 250) // Giới hạn an toàn trần cứng 250
        let isLAN = self.isPrivateTarget
        let timeout: TimeInterval = isLAN ? 0.8 : 1.8 // Timeout thích ứng LAN vs Internet
        let grabBanner = self.enableBannerGrabbing
        let startTime = CFAbsoluteTimeGetCurrent()
        
        scanTask = Task {
            var completedCount = self.scannedCount
            
            await withTaskGroup(of: ScannedPort?.self) { group in
                // Nạp trước các tác vụ vào TaskGroup
                for _ in 0..<concurrencyLimit {
                    guard !self.remainingPorts.isEmpty else { break }
                    let port = self.remainingPorts.removeFirst()
                    group.addTask {
                        guard !Task.isCancelled else { return nil }
                        return await Self.probePort(
                            host: host,
                            port: port,
                            timeout: timeout,
                            enableBanner: grabBanner
                        )
                    }
                }
                
                // Khi một tác vụ xong, nạp cổng tiếp theo
                for await result in group {
                    guard !Task.isCancelled && !self.isPaused else { break }
                    
                    completedCount += 1
                    let elapsed = max(CFAbsoluteTimeGetCurrent() - startTime, 0.01)
                    let currentRate = Double(completedCount) / elapsed
                    
                    self.scannedCount = completedCount
                    self.progress = self.totalCount > 0 ? Double(completedCount) / Double(self.totalCount) : 1.0
                    self.scanRate = currentRate
                    
                    if let item = result {
                        self.currentPort = item.port
                        self.allScannedResults.append(item)
                        if item.status == .open {
                            self.openPorts.append(item)
                            self.openPorts.sort { $0.port < $1.port }
                        }
                    }
                    
                    // Bổ sung cổng tiếp theo nếu còn
                    if !self.remainingPorts.isEmpty && !self.isPaused {
                        let nextPort = self.remainingPorts.removeFirst()
                        group.addTask {
                            guard !Task.isCancelled else { return nil }
                            return await Self.probePort(
                                host: host,
                                port: nextPort,
                                timeout: timeout,
                                enableBanner: grabBanner
                            )
                        }
                    }
                }
            }
            
            if !self.isPaused && self.remainingPorts.isEmpty {
                self.progress = 1.0
                self.statusMessage = "Hoàn tất! Phát hiện \(self.openPorts.count) cổng mở."
                self.isScanning = false
            }
        }
    }
    
    // MARK: - Single Port Probe
    private static func probePort(
        host: String,
        port: Int,
        timeout: TimeInterval,
        enableBanner: Bool
    ) async -> ScannedPort {
        let (serviceName, serviceDesc) = PortDatabase.lookup(port: port)
        
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return ScannedPort(port: port, status: .closed, serviceName: serviceName, serviceDescription: serviceDesc)
        }
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = max(1, Int(ceil(timeout)))
        
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        let connection = NWConnection(to: endpoint, using: params)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()
            
            // Watchdog Timeout độc lập từng cổng
            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: ScannedPort(
                    port: port,
                    status: .filtered,
                    serviceName: serviceName,
                    serviceDescription: serviceDesc,
                    rttMs: nil
                ))
            }
            timer.resume()
            
            let finish = { (status: PortStatus, rtt: Double?, bannerText: String?) in
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                timer.cancel()
                connection.cancel()
                continuation.resume(returning: ScannedPort(
                    port: port,
                    status: status,
                    serviceName: serviceName,
                    serviceDescription: serviceDesc,
                    rttMs: rtt,
                    banner: bannerText
                ))
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let rtt = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    
                    if enableBanner {
                        // Thử đọc banner dịch vụ trong vòng 1.0 giây
                        Self.readBanner(connection: connection, port: port) { banner in
                            finish(.open, rtt, banner)
                        }
                    } else {
                        finish(.open, rtt, nil)
                    }
                    
                case .waiting(let nwError):
                    // Bắt lỗi quyền mạng cục bộ (PolicyDenied) ngay khi rơi vào .waiting
                    let status = Self.mapNWErrorToStatus(nwError)
                    finish(status, nil, nil)
                    
                case .failed(let nwError):
                    let status = Self.mapNWErrorToStatus(nwError)
                    finish(status, nil, nil)
                    
                case .cancelled:
                    finish(.filtered, nil, nil)
                    
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
    
    // MARK: - Banner Grabbing Helper
    private static func readBanner(
        connection: NWConnection,
        port: Int,
        completion: @escaping (String?) -> Void
    ) {
        // Gửi chuỗi thăm dò phù hợp
        let probe: Data
        if port == 80 || port == 8080 || port == 8000 {
            probe = "HEAD / HTTP/1.0\r\n\r\n".data(using: .utf8) ?? Data()
        } else {
            probe = "\r\n".data(using: .utf8) ?? Data()
        }
        
        connection.send(content: probe, completion: .contentProcessed { _ in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { data, _, _, _ in
                if let data = data, !data.isEmpty {
                    let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(text.isEmpty ? nil : text)
                } else {
                    completion(nil)
                }
            }
        })
    }
    
    private static func mapNWErrorToStatus(_ error: NWError) -> PortStatus {
        var code: Int32? = nil
        var desc: String? = nil
        
        switch error {
        case .posix(let posixCode):
            code = posixCode.rawValue
            desc = posixCode.description
        case .dns(let dnsCode):
            code = dnsCode
            desc = "DNS error \(dnsCode)"
        default:
            desc = error.localizedDescription
        }
        
        return PortStatusClassifier.classify(
            isConnected: false,
            isTimedOut: false,
            errorCode: code,
            errorDescription: desc
        )
    }
    
    private func isPrivateIP(_ ip: String) -> Bool {
        return ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") || ip.hasPrefix("127.")
    }
}
