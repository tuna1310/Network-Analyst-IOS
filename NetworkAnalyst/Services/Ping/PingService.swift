//
//  PingService.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine

/// Service điều phối phiên Ping, tính toán thống kê và gửi cập nhật về ViewModel
@MainActor
public final class PingService: ObservableObject {
    @Published public private(set) var isPinging: Bool = false
    @Published public private(set) var packets: [PingPacketResult] = []
    @Published public private(set) var currentSummary: PingSessionSummary? = nil
    
    private var pingTask: Task<Void, Never>?
    private var engine: ICMPEngine?
    
    public init() {}
    
    /// Bắt đầu gửi ping liên tục hoặc theo số lượng gói
    public func startPing(
        host: String,
        count: Int = 10,
        interval: TimeInterval = 0.8,
        timeout: TimeInterval = 1.0,
        payloadSize: Int = 32
    ) {
        stopPing()
        isPinging = true
        packets.removeAll()
        currentSummary = nil
        
        let engine = ICMPEngine()
        self.engine = engine
        
        pingTask = Task {
            for seq in 1...count {
                if Task.isCancelled { break }
                
                let result = await engine.pingOnce(
                    to: host,
                    sequence: seq,
                    timeout: timeout,
                    payloadSize: payloadSize
                )
                
                guard !Task.isCancelled else { break }
                
                self.packets.append(result)
                self.currentSummary = PingSessionSummary(host: host, results: self.packets)
                
                if seq < count {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
            
            self.isPinging = false
        }
    }
    
    /// Dừng phiên Ping hiện tại
    public func stopPing() {
        pingTask?.cancel()
        pingTask = nil
        isPinging = false
    }
}
