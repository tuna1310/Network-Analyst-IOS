//
//  TracerouteModels.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Trạng thái của một Hop (Router trung gian) trong Traceroute
public enum HopStatus: Sendable, Equatable {
    case responding
    case timeout
    case destinationReached
    case error(String)
    
    public var displayText: String {
        switch self {
        case .responding: return "Phản hồi"
        case .timeout: return "* (Timeout)"
        case .destinationReached: return "Đã tới đích"
        case .error(let msg): return "Lỗi: \(msg)"
        }
    }
}

/// Thông tin địa lý của một Hop IP (chỉ lấy khi người dùng bật công tắc)
public struct HopGeoIPInfo: Sendable, Equatable, Codable {
    public let ip: String
    public let country: String?
    public let countryCode: String?
    public let city: String?
    
    public init(ip: String, country: String? = nil, countryCode: String? = nil, city: String? = nil) {
        self.ip = ip
        self.country = country
        self.countryCode = countryCode
        self.city = city
    }
}

/// Đại diện cho một chặng (Hop) trong đường đi gói tin mạng
public struct TracerouteHop: Identifiable, Sendable, Equatable {
    public var id: Int { hop }
    public let hop: Int
    public var ipAddress: String?
    public var hostname: String?
    public var probesRTT: [Double?] // Thường là 3 lần probe mỗi hop (ví dụ [12.1, 12.4, 11.9])
    public var geoInfo: HopGeoIPInfo?
    public var status: HopStatus
    public let timestamp: Date
    
    public init(
        hop: Int,
        ipAddress: String? = nil,
        hostname: String? = nil,
        probesRTT: [Double?] = [],
        geoInfo: HopGeoIPInfo? = nil,
        status: HopStatus = .timeout,
        timestamp: Date = Date()
    ) {
        self.hop = hop
        self.ipAddress = ipAddress
        self.hostname = hostname
        self.probesRTT = probesRTT
        self.geoInfo = geoInfo
        self.status = status
        self.timestamp = timestamp
    }
    
    /// Độ trễ trung bình của các lần probe thành công
    public var avgRTT: Double? {
        let valid = probesRTT.compactMap { $0 }
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0.0, +) / Double(valid.count)
    }
    
    public var displayHost: String {
        if let host = hostname, !host.isEmpty, host != ipAddress {
            return "\(host) (\(ipAddress ?? ""))"
        }
        return ipAddress ?? "* * *"
    }
    
    /// Chuỗi hiển thị các lần probe (ví dụ: "12.4 ms  13.0 ms  12.1 ms" hoặc "*  15.2 ms  *")
    public var probesDisplayString: String {
        guard !probesRTT.isEmpty else { return "--" }
        return probesRTT.map { rtt in
            if let val = rtt {
                return String(format: "%.1f ms", val)
            } else {
                return "*"
            }
        }.joined(separator: "  ")
    }
}
