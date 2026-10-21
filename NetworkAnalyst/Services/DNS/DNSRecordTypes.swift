//
//  DNSRecordTypes.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Các loại bản ghi DNS tiêu chuẩn
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
        case .CAA: return 257
        case .ANY: return 255
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
        case .ANY: return "Tất cả các bản ghi khả dụng"
        }
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
public enum DNSProvider: String, CaseIterable, Identifiable, Sendable {
    case cloudflare = "Cloudflare (1.1.1.1)"
    case google = "Google (8.8.8.8)"
    case quad9 = "Quad9 (9.9.9.9)"
    
    public var id: String { rawValue }
    
    public var dohURL: String {
        switch self {
        case .cloudflare: return "https://cloudflare-dns.com/dns-query"
        case .google: return "https://dns.google/resolve"
        case .quad9: return "https://dns.quad9.net/dns-query"
        }
    }
    
    public var udpIP: String {
        switch self {
        case .cloudflare: return "1.1.1.1"
        case .google: return "8.8.8.8"
        case .quad9: return "9.9.9.9"
        }
    }
}

/// Kết quả của một truy vấn DNS
public struct DNSQueryResult: Sendable {
    public let domain: String
    public let recordType: DNSRecordType
    public let provider: DNSProvider
    public let records: [DNSRecordItem]
    public let responseTimeMs: Double
    public let error: String?
    
    public init(
        domain: String,
        recordType: DNSRecordType,
        provider: DNSProvider,
        records: [DNSRecordItem] = [],
        responseTimeMs: Double = 0.0,
        error: String? = nil
    ) {
        self.domain = domain
        self.recordType = recordType
        self.provider = provider
        self.records = records
        self.responseTimeMs = responseTimeMs
        self.error = error
    }
}
