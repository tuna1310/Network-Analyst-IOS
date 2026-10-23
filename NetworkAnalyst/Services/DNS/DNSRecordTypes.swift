//
//  DNSRecordTypes.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import NetworkCore

/// Các loại bản ghi DNS tiêu chuẩn và bản ghi định vị dịch vụ hiện đại (RFC 9460)
public enum DNSRecordType: String, CaseIterable, Identifiable, Sendable {
    case ANY = "ANY"
    case A = "A"
    case AAAA = "AAAA"
    case CNAME = "CNAME"
    case MX = "MX"
    case TXT = "TXT"
    case NS = "NS"
    case SOA = "SOA"
    case SRV = "SRV"
    case PTR = "PTR"
    case CAA = "CAA"
    case SVCB = "SVCB"
    case HTTPS = "HTTPS"
    
    public var id: String { rawValue }
    
    public var code: UInt16 {
        switch self {
        case .A: return 1
        case .NS: return 2
        case .CNAME: return 5
        case .SOA: return 6
        case .PTR: return 12
        case .MX: return 15
        case .TXT: return 16
        case .AAAA: return 28
        case .SRV: return 33
        case .SVCB: return 64
        case .HTTPS: return 65
        case .ANY: return 255
        case .CAA: return 257
        }
    }
    
    public static func fromCode(_ code: UInt16) -> DNSRecordType {
        for type in DNSRecordType.allCases {
            if type.code == code { return type }
        }
        return .ANY
    }
    
    public var explanation: String {
        switch self {
        case .A: return "Bản ghi IPv4 (Address)"
        case .AAAA: return "Bản ghi IPv6 (128-bit Address)"
        case .CNAME: return "Tên miền bí danh (Canonical Name)"
        case .MX: return "Máy chủ thư điện tử (Mail Exchange)"
        case .TXT: return "Chuỗi văn bản (SPF, DKIM, DMARC, Xác minh)"
        case .NS: return "Máy chủ phân giải ủy quyền (Name Server)"
        case .SOA: return "Thông tin quản trị vùng (Start of Authority)"
        case .SRV: return "Bản ghi định vị dịch vụ (Service Record)"
        case .PTR: return "Phân giải ngược địa chỉ IP (Pointer)"
        case .CAA: return "Chính sách cấp chứng chỉ số SSL/TLS"
        case .SVCB: return "Cấu hình dịch vụ chung (RFC 9460 Service Binding)"
        case .HTTPS: return "Cấu hình HTTPS chuyên dụng (RFC 9460 HTTPSSVC)"
        case .ANY: return "Tất cả các bản ghi khả dụng"
        }
    }
    
    public var toCoreType: DNSQueryType {
        DNSQueryType(rawValue: code) ?? .ANY
    }
}

/// Một bản ghi DNS cụ thể trả về
public struct DNSRecordItem: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let name: String
    public let type: DNSRecordType
    public let ttl: Int
    public let value: String
    public let priority: Int?
    
    public init(name: String, type: DNSRecordType, ttl: Int, value: String, priority: Int? = nil) {
        self.name = name
        self.type = type
        self.ttl = ttl
        self.value = value
        self.priority = priority
    }
}

/// Nhà cung cấp Upstream DNS Resolver
public enum DNSProvider: Hashable, Identifiable, Sendable {
    case cloudflare
    case google
    case quad9
    case custom(ip: String)
    case system(gatewayIP: String?)
    
    public var id: String { rawValue }
    
    public var rawValue: String {
        switch self {
        case .cloudflare: return "Cloudflare (1.1.1.1)"
        case .google: return "Google (8.8.8.8)"
        case .quad9: return "Quad9 (9.9.9.9)"
        case .custom(let ip): return "Tùy chỉnh (\(ip))"
        case .system(let gw):
            if let g = gw, !g.isEmpty {
                return "Mạng hiện tại (Gateway: \(g))"
            }
            return "Mạng hiện tại (DHCP Router)"
        }
    }
    
    public static var defaultPresets: [DNSProvider] {
        [.cloudflare, .google, .quad9]
    }
    
    public var dohURL: String? {
        switch self {
        case .cloudflare: return "https://cloudflare-dns.com/dns-query"
        case .google: return "https://dns.google/resolve"
        case .quad9: return "https://dns.quad9.net/dns-query"
        case .custom, .system: return nil
        }
    }
    
    public var udpIP: String {
        switch self {
        case .cloudflare: return "1.1.1.1"
        case .google: return "8.8.8.8"
        case .quad9: return "9.9.9.9"
        case .custom(let ip): return ip
        case .system(let gw): return gw ?? "192.168.1.1"
        }
    }
}

/// Kết quả tổng hợp truy vấn DNS
public struct DNSQueryResult: Sendable {
    public let domain: String
    public let recordType: DNSRecordType
    public let provider: DNSProvider
    public let records: [DNSRecordItem]
    public let responseTimeMs: Double
    public let isTruncated: Bool
    public let retriedOverTCP: Bool
    public let error: String?
    
    public init(
        domain: String,
        recordType: DNSRecordType,
        provider: DNSProvider,
        records: [DNSRecordItem] = [],
        responseTimeMs: Double = 0.0,
        isTruncated: Bool = false,
        retriedOverTCP: Bool = false,
        error: String? = nil
    ) {
        self.domain = domain
        self.recordType = recordType
        self.provider = provider
        self.records = records
        self.responseTimeMs = responseTimeMs
        self.isTruncated = isTruncated
        self.retriedOverTCP = retriedOverTCP
        self.error = error
    }
}
