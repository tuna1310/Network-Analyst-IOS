//
//  PingModels.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Trạng thái gói tin Ping
public enum PingStatus: Sendable, Equatable {
    case success
    case timeout
    case destinationUnreachable
    case error(String)
}

/// Kết quả phản hồi của một gói tin Ping đơn lẻ
public struct PingPacketResult: Sendable, Identifiable {
    public let id = UUID()
    public let sequence: Int
    public let host: String
    public let ipAddress: String
    public let rttMs: Double?
    public let bytes: Int
    public let ttl: Int?
    public let status: PingStatus
    public let timestamp: Date
    
    public init(
        sequence: Int,
        host: String,
        ipAddress: String,
        rttMs: Double?,
        bytes: Int,
        ttl: Int? = 64,
        status: PingStatus,
        timestamp: Date = Date()
    ) {
        self.sequence = sequence
        self.host = host
        self.ipAddress = ipAddress
        self.rttMs = rttMs
        self.bytes = bytes
        self.ttl = ttl
        self.status = status
        self.timestamp = timestamp
    }
}

/// Thống kê tổng hợp sau một phiên Ping
public struct PingSessionSummary: Sendable {
    public let host: String
    public let packetsTransmitted: Int
    public let packetsReceived: Int
    public let packetLossPercent: Double
    public let minRTT: Double?
    public let avgRTT: Double?
    public let maxRTT: Double?
    public let stdDevRTT: Double?
    
    public init(host: String, results: [PingPacketResult]) {
        self.host = host
        self.packetsTransmitted = results.count
        let successful = results.compactMap { $0.rttMs }
        self.packetsReceived = successful.count
        
        if results.isEmpty {
            self.packetLossPercent = 0.0
            self.minRTT = nil
            self.avgRTT = nil
            self.maxRTT = nil
            self.stdDevRTT = nil
            return
        }
        
        self.packetLossPercent = Double(results.count - successful.count) / Double(results.count) * 100.0
        
        if successful.isEmpty {
            self.minRTT = nil
            self.avgRTT = nil
            self.maxRTT = nil
            self.stdDevRTT = nil
        } else {
            let minVal = successful.min() ?? 0.0
            let maxVal = successful.max() ?? 0.0
            let avgVal = successful.reduce(0.0, +) / Double(successful.count)
            
            // Standard deviation
            let variance = successful.reduce(0.0) { $0 + pow($1 - avgVal, 2) } / Double(successful.count)
            let stdDev = sqrt(variance)
            
            self.minRTT = minVal
            self.avgRTT = avgVal
            self.maxRTT = maxVal
            self.stdDevRTT = stdDev
        }
    }
}
