//
//  PortScannerModels.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Trạng thái cổng sau khi quét
public enum PortStatus: String, Sendable, CaseIterable {
    case open = "Mở (Open)"
    case closed = "Đóng (Closed)"
    case filtered = "Bị lọc (Filtered)"
    
    public var badgeColor: String {
        switch self {
        case .open: return "green"
        case .closed: return "red"
        case .filtered: return "orange"
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
    
    public init(
        port: Int,
        status: PortStatus,
        serviceName: String,
        serviceDescription: String,
        rttMs: Double? = nil
    ) {
        self.port = port
        self.status = status
        self.serviceName = serviceName
        self.serviceDescription = serviceDescription
        self.rttMs = rttMs
    }
}

/// Các chế độ quét cổng định sẵn
public enum PortScanPreset: Hashable, Sendable {
    case top20
    case top100
    case custom(start: Int, end: Int)
    
    public var title: String {
        switch self {
        case .top20: return "Top 20 phổ biến"
        case .top100: return "Top 100 dịch vụ"
        case .custom(let start, let end): return "Tùy chỉnh (\(start)-\(end))"
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
        case .custom(let start, let end):
            let s = max(1, min(start, 65535))
            let e = max(s, min(end, 65535))
            return Array(s...e)
        }
    }
}

/// Cơ sở dữ liệu tra cứu tên và công dụng cổng IANA phổ biến
public enum PortDatabase {
    private static let services: [Int: (name: String, desc: String)] = [
        21: ("FTP", "File Transfer Protocol - Truyền tập tin"),
        22: ("SSH", "Secure Shell - Quản trị từ xa an toàn"),
        23: ("Telnet", "Giao thức dòng lệnh chưa mã hóa"),
        25: ("SMTP", "Simple Mail Transfer Protocol - Gửi thư điện tử"),
        53: ("DNS", "Domain Name System - Phân giải tên miền"),
        67: ("DHCP", "DHCP Server"),
        68: ("DHCP", "DHCP Client"),
        80: ("HTTP", "Hypertext Transfer Protocol - Web không mã hóa"),
        88: ("Kerberos", "Hệ thống xác thực mạng Kerberos"),
        110: ("POP3", "Post Office Protocol - Nhận thư"),
        111: ("RPCBind", "ONC RPC Portmapper"),
        123: ("NTP", "Network Time Protocol - Đồng bộ thời gian"),
        135: ("MSRPC", "Microsoft Windows RPC Endpoint"),
        137: ("NetBIOS-NS", "NetBIOS Name Service"),
        138: ("NetBIOS-DGM", "NetBIOS Datagram Service"),
        139: ("NetBIOS-SSN", "NetBIOS Session Service"),
        143: ("IMAP", "Internet Message Access Protocol - Nhận thư"),
        161: ("SNMP", "Simple Network Management Protocol"),
        179: ("BGP", "Border Gateway Protocol"),
        389: ("LDAP", "Lightweight Directory Access Protocol"),
        443: ("HTTPS", "HTTP over TLS/SSL - Web bảo mật"),
        445: ("SMB", "Server Message Block - Chia sẻ tệp Windows"),
        465: ("SMTPS", "SMTP qua SSL"),
        514: ("Syslog", "Ghi log hệ thống"),
        587: ("Submission", "SMTP Message Submission"),
        631: ("IPP", "Internet Printing Protocol - Máy in"),
        636: ("LDAPS", "LDAP qua SSL"),
        873: ("rsync", "Đồng bộ tập tin rsync"),
        993: ("IMAPS", "IMAP qua SSL"),
        995: ("POP3S", "POP3 qua SSL"),
        1080: ("SOCKS", "SOCKS Proxy"),
        1194: ("OpenVPN", "OpenVPN Tunnel"),
        1433: ("MSSQL", "Microsoft SQL Server Database"),
        1521: ("Oracle", "Oracle Database Listener"),
        1723: ("PPTP", "Point-to-Point Tunneling Protocol"),
        2049: ("NFS", "Network File System"),
        3000: ("Node/Dev", "Development Web Server / Grafana"),
        3306: ("MySQL", "MySQL / MariaDB Database"),
        3389: ("RDP", "Remote Desktop Protocol - Điều khiển Windows"),
        4443: ("HTTPS-Alt", "Cổng HTTPS thay thế"),
        5000: ("UPnP/Synology", "Synology DSM / UPnP Control"),
        5432: ("PostgreSQL", "PostgreSQL Database"),
        5672: ("RabbitMQ", "AMQP Message Broker"),
        5900: ("VNC", "Virtual Network Computing - Màn hình từ xa"),
        6379: ("Redis", "Redis In-Memory Key-Value Store"),
        8000: ("HTTP-Dev", "Phát triển Web / Django / FastAPI"),
        8080: ("HTTP-Proxy", "HTTP Alternate / Tomcat / Jenkins"),
        8443: ("HTTPS-Alt", "HTTPS Alternate"),
        8888: ("HTTP-Alt", "Jupyter Notebook / Web admin"),
        9000: ("PHP-FPM/Portainer", "FastCGI / Portainer Docker"),
        9092: ("Kafka", "Apache Kafka Message Queue"),
        9200: ("Elasticsearch", "Elasticsearch REST API"),
        27017: ("MongoDB", "MongoDB NoSQL Database"),
        62078: ("Apple-Sync", "Apple MobileDevice Service / Wi-Fi Sync")
    ]
    
    public static func lookup(port: Int) -> (name: String, desc: String) {
        if let found = services[port] {
            return found
        }
        return ("Unknown", "Dịch vụ cổng \(port)")
    }
}
