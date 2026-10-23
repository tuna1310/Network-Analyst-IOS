//
//  PortScannerEngine.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import Combine

/// Engine quét cổng TCP sử dụng NWConnection và TaskGroup có giới hạn đồng thời (ví dụ tối đa 200 concurrent tasks)
@MainActor
public final class PortScannerEngine: ObservableObject {
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var scannedCount: Int = 0
    @Published public private(set) var totalCount: Int = 0
    @Published public private(set) var openPorts: [ScannedPort] = []
    @Published public private(set) var allScannedResults: [ScannedPort] = []
    @Published public private(set) var currentPort: Int = 0
    @Published public private(set) var scanRate: Double = 0.0 // Ports/sec
    @Published public private(set) var statusMessage: String = "Sẵn sàng"
    
    private var scanTask: Task<Void, Never>?
    public var maxConcurrency: Int = 180
    public var timeoutPerPort: TimeInterval = 1.2
    
    public init() {}
    
    /// Bắt đầu quét danh sách các cổng của host mục tiêu
    public func startScan(host: String, ports: [Int]) {
        guard !isScanning else { return }
        guard !ports.isEmpty else {
            statusMessage = "Danh sách cổng trống."
            return
        }
        
        isScanning = true
        progress = 0.0
        scannedCount = 0
        totalCount = ports.count
        openPorts.removeAll()
        allScannedResults.removeAll()
        statusMessage = "Đang quét \(host)..."
        
        let targetHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let concurrencyLimit = self.maxConcurrency
        let timeout = self.timeoutPerPort
        let startTime = CFAbsoluteTimeGetCurrent()
        
        scanTask = Task {
            var portIterator = ports.makeIterator()
            var completedCount = 0
            
            await withTaskGroup(of: ScannedPort?.self) { group in
                // Nạp trước số lượng tác vụ tối đa
                for _ in 0..<concurrencyLimit {
                    if let port = portIterator.next() {
                        group.addTask {
                            return await Self.probePort(host: targetHost, port: port, timeout: timeout)
                        }
                    }
                }
                
                // Khi có một tác vụ hoàn tất, bổ sung cổng tiếp theo vào group
                for await result in group {
                    guard !Task.isCancelled else { break }
                    
                    completedCount += 1
                    let elapsed = max(CFAbsoluteTimeGetCurrent() - startTime, 0.01)
                    let currentRate = Double(completedCount) / elapsed
                    
                    self.scannedCount = completedCount
                    self.progress = Double(completedCount) / Double(ports.count)
                    self.scanRate = currentRate
                    
                    if let item = result {
                        self.currentPort = item.port
                        self.allScannedResults.append(item)
                        if item.status == .open {
                            self.openPorts.append(item)
                            // Sắp xếp danh sách cổng mở theo số hiệu
                            self.openPorts.sort { $0.port < $1.port }
                        }
                    }
                    
                    // Thêm cổng tiếp theo
                    if let nextPort = portIterator.next() {
                        group.addTask {
                            return await Self.probePort(host: targetHost, port: nextPort, timeout: timeout)
                        }
                    }
                }
            }
            
            self.progress = 1.0
            self.statusMessage = "Hoàn tất! Phát hiện \(self.openPorts.count) cổng đang mở."
            self.isScanning = false
        }
    }
    
    /// Dừng tiến trình quét cổng
    public func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        statusMessage = "Đã dừng quét."
    }
    
    /// Kiểm tra kết nối TCP tới một cổng cụ thể với NWConnection và timeout riêng
    private static func probePort(host: String, port: Int, timeout: TimeInterval) async -> ScannedPort {
        let (serviceName, serviceDesc) = PortDatabase.lookup(port: port)
        
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return ScannedPort(port: port, status: .closed, serviceName: serviceName, serviceDescription: serviceDesc)
        }
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = max(1, Int(timeout))
        // Lưu ý: NWConnection thực hiện bắt tay 3 bước TCP đầy đủ (full connect handshake)
        // tuân thủ sandbox iOS, không dùng raw SYN packet và không bật TFO.
        
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        let connection = NWConnection(to: endpoint, using: params)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            // Bộ hẹn giờ timeout riêng cho cổng này
            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                if !hasResumed {
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
            }
            timer.resume()
            
            connection.stateUpdateHandler = { state in
                guard !hasResumed else { return }
                
                switch state {
                case .ready:
                    hasResumed = true
                    timer.cancel()
                    let rtt = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    connection.cancel()
                    continuation.resume(returning: ScannedPort(
                        port: port,
                        status: .open,
                        serviceName: serviceName,
                        serviceDescription: serviceDesc,
                        rttMs: rtt
                    ))
                    
                case .failed:
                    hasResumed = true
                    timer.cancel()
                    connection.cancel()
                    continuation.resume(returning: ScannedPort(
                        port: port,
                        status: .closed,
                        serviceName: serviceName,
                        serviceDescription: serviceDesc,
                        rttMs: nil
                    ))
                    
                case .cancelled:
                    if !hasResumed {
                        hasResumed = true
                        timer.cancel()
                        continuation.resume(returning: ScannedPort(
                            port: port,
                            status: .filtered,
                            serviceName: serviceName,
                            serviceDescription: serviceDesc,
                            rttMs: nil
                        ))
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
}
