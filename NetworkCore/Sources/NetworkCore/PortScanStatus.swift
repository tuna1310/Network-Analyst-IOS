//
//  PortScanStatus.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Trạng thái cổng quét TCP
public enum PortStatus: Sendable, Codable, Equatable {
    case open
    case closed
    case filtered
    case error(String)
    
    public var displayName: String {
        switch self {
        case .open: return "Mở (Open)"
        case .closed: return "Đóng (Closed)"
        case .filtered: return "Bị chặn (Filtered / Timeout)"
        case .error(let reason): return "Lỗi (\(reason))"
        }
    }
    
    public var badgeColorName: String {
        switch self {
        case .open: return "green"
        case .closed: return "gray"
        case .filtered: return "orange"
        case .error: return "red"
        }
    }
}

/// Bộ phân loại trạng thái cổng từ mã lỗi mạng POSIX và Network.framework
public enum PortStatusClassifier {
    
    // POSIX Darwin Error Codes
    public static let posixEPERM: Int32 = 1          // Operation not permitted
    public static let posixEACCES: Int32 = 13        // Permission denied
    public static let posixECONNREFUSED: Int32 = 61  // Connection refused
    public static let posixETIMEDOUT: Int32 = 60     // Operation timed out
    public static let posixENETUNREACH: Int32 = 51   // Network is unreachable
    public static let posixEHOSTUNREACH: Int32 = 65  // No route to host
    public static let policyDeniedDNS: Int32 = -65570 // kDNSServiceErr_PolicyDenied (Local network denied)
    public static let policyDeniedOld: Int32 = -65565
    
    /// Phân loại kết quả cổng dựa trên trạng thái kết nối và mã lỗi
    public static func classify(
        isConnected: Bool,
        isTimedOut: Bool,
        errorCode: Int32?,
        errorDescription: String? = nil
    ) -> PortStatus {
        if isConnected {
            return .open
        }
        
        if isTimedOut {
            return .filtered
        }
        
        guard let code = errorCode else {
            return .filtered
        }
        
        // 1. Cổng đóng: Router/Host phản hồi TCP RST (ECONNREFUSED = 61)
        if code == posixECONNREFUSED {
            return .closed
        }
        
        // 2. Quyền mạng cục bộ (Local Network Permission): KHÔNG gộp vào Closed!
        if code == policyDeniedDNS || code == policyDeniedOld || code == posixEPERM || code == posixEACCES {
            return .error("Quyền Mạng cục bộ bị từ chối")
        }
        
        // 3. Mạng / Máy chủ không thể tiếp cận (Unreachable)
        if code == posixEHOSTUNREACH || code == posixENETUNREACH {
            return .error("Host/Network không thể tiếp cận")
        }
        
        // 4. Hết thời gian chờ POSIX
        if code == posixETIMEDOUT {
            return .filtered
        }
        
        // 5. Các lỗi hệ thống khác
        let desc = errorDescription ?? "Mã lỗi \(code)"
        return .error(desc)
    }
    
    /// Danh mục dịch vụ chuẩn gán theo số hiệu cổng IANA
    public static func serviceName(for port: Int) -> String {
        switch port {
        case 20, 21: return "FTP"
        case 22: return "SSH / SFTP"
        case 23: return "Telnet"
        case 25: return "SMTP"
        case 53: return "DNS"
        case 80: return "HTTP"
        case 110: return "POP3"
        case 123: return "NTP"
        case 135: return "MS-RPC"
        case 137, 138, 139: return "NetBIOS"
        case 143: return "IMAP"
        case 161: return "SNMP"
        case 443: return "HTTPS"
        case 445: return "SMB / CIFS"
        case 465: return "SMTPS"
        case 554: return "RTSP"
        case 587: return "SMTP Submission"
        case 993: return "IMAPS"
        case 995: return "POP3S"
        case 1433: return "Microsoft SQL Server"
        case 1521: return "Oracle DB"
        case 1883: return "MQTT"
        case 3000: return "Node.js / Dev Server"
        case 3306: return "MySQL"
        case 3389: return "RDP (Remote Desktop)"
        case 5000: return "UPnP / Docker"
        case 5432: return "PostgreSQL"
        case 5900: return "VNC"
        case 6379: return "Redis"
        case 8000, 8008: return "HTTP Alt"
        case 8080: return "HTTP Proxy / Apache Tomcat"
        case 8443: return "HTTPS Alt"
        case 8883: return "MQTT SSL"
        case 9000: return "PHP-FPM / SonarQube"
        case 9092: return "Apache Kafka"
        case 9200: return "Elasticsearch"
        case 27017: return "MongoDB"
        default: return "Dịch vụ mạng khác"
        }
    }
}
