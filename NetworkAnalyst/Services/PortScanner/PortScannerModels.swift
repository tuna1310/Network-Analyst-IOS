//
//  PortScannerModels.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import NetworkCore

/// 3 Chế độ quét cổng chính
public enum PortScanMode: Int, CaseIterable, Identifiable {
    case popular = 0 // Cổng phổ biến (Top 20 / Top 100)
    case custom = 1  // Dải tùy chọn (80,443,8000-8100)
    case full = 2    // Toàn dải 1 - 65535
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .popular: return "Phổ biến"
        case .custom: return "Tùy chọn"
        case .full: return "Toàn dải (1-65535)"
        }
    }
}

/// Thông tin chi tiết một cổng được quét
public struct ScannedPort: Identifiable, Sendable, Equatable {
    public var id: Int { port }
    public let port: Int
    public let status: PortStatus
    public let serviceName: String
    public let serviceDescription: String
    public let rttMs: Double?
    public let banner: String?
    
    public init(
        port: Int,
        status: PortStatus,
        serviceName: String,
        serviceDescription: String,
        rttMs: Double? = nil,
        banner: String? = nil
    ) {
        self.port = port
        self.status = status
        self.serviceName = serviceName
        self.serviceDescription = serviceDescription
        self.rttMs = rttMs
        self.banner = banner
    }
}

/// Các chế độ quét cổng định sẵn cho mode Phổ biến
public enum PortScanPreset: Hashable, Sendable {
    case top20
    case top100
    
    public var title: String {
        switch self {
        case .top20: return "Top 20 phổ biến"
        case .top100: return "Top 100 dịch vụ"
        }
    }
    
    public var ports: [Int] {
        switch self {
        case .top20:
            return [21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 993, 995, 1433, 1521, 3306, 3389, 5432, 8080]
        case .top100:
            return [
                20, 21, 22, 23, 25, 53, 67, 68, 69, 80, 88, 110, 111, 119, 123, 135, 137, 138, 139, 143,
                161, 162, 179, 194, 389, 443, 445, 465, 514, 515, 587, 631, 636, 873, 990, 993, 995,
                1080, 1194, 1433, 1434, 1521, 1723, 1812, 1813, 2049, 2082, 2083, 2086, 2087, 2181,
                2222, 3000, 3128, 3306, 3389, 4000, 4222, 4443, 5000, 5222, 5432, 5672, 5900, 5984,
                6000, 6379, 6667, 7000, 7001, 8000, 8008, 8080, 8081, 8088, 8443, 8888, 9000, 9042,
                9090, 9092, 9200, 9300, 9418, 9999, 10000, 11211, 27017, 27018, 50000, 62078
            ]
        }
    }
}

/// Cơ sở dữ liệu tra cứu tên và công dụng cổng IANA phổ biến
public enum PortDatabase {
    public static func lookup(port: Int) -> (name: String, desc: String) {
        let name = PortStatusClassifier.serviceName(for: port)
        switch port {
        case 21: return (name, "File Transfer Protocol - Truyền tập tin")
        case 22: return (name, "Secure Shell - Quản trị từ xa an toàn")
        case 23: return (name, "Telnet - Dòng lệnh chưa mã hóa")
        case 25: return (name, "SMTP - Gửi thư điện tử")
        case 53: return (name, "DNS - Phân giải tên miền")
        case 80: return (name, "HTTP - Máy chủ Web không mã hóa")
        case 110: return (name, "POP3 - Nhận thư điện tử")
        case 143: return (name, "IMAP - Đồng bộ thư điện tử")
        case 443: return (name, "HTTPS - Web bảo mật SSL/TLS")
        case 445: return (name, "SMB / CIFS - Chia sẻ tập tin Windows")
        case 554: return (name, "RTSP - Luồng video camera / media")
        case 1433: return (name, "Microsoft SQL Server Database")
        case 1521: return (name, "Oracle Database Listener")
        case 1883: return (name, "MQTT - Giao thức nhắn tin IoT")
        case 3306: return (name, "MySQL / MariaDB Database")
        case 3389: return (name, "RDP - Microsoft Remote Desktop")
        case 5000: return (name, "UPnP / Synology NAS / Flask")
        case 5432: return (name, "PostgreSQL Database")
        case 6379: return (name, "Redis In-Memory Data Store")
        case 8080: return (name, "HTTP Proxy / Apache Tomcat")
        case 8443: return (name, "HTTPS Alt / Quản trị web an toàn")
        case 27017: return (name, "MongoDB NoSQL Database")
        default: return (name, "Dịch vụ mạng")
        }
    }
}
