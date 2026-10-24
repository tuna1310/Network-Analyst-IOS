//
//  ScanHistoryModels.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Phân loại loại tác vụ quét được ghi nhận vào lịch sử
public enum ScanHistoryType: String, Codable, CaseIterable, Identifiable, Sendable {
    case lan = "Quét mạng LAN"
    case port = "Quét cổng TCP"
    case ping = "Kiểm tra Ping"
    case traceroute = "Dò tuyến Traceroute"
    case dns = "Tra cứu DNS"
    case rdap = "WHOIS / RDAP"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .lan: return "network"
        case .port: return "server.rack"
        case .ping: return "waveform.path.ecg"
        case .traceroute: return "point.topleft.down.curvedto.point.bottomright.up"
        case .dns: return "text.magnifyingglass"
        case .rdap: return "globe.americas.fill"
        }
    }
}

/// Bản ghi lịch sử quét mạng cục bộ
public struct ScanHistoryEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let type: ScanHistoryType
    public let target: String
    public let summary: String
    public let details: String?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ScanHistoryType,
        target: String,
        summary: String,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.target = target
        self.summary = summary
        self.details = details
    }
}
