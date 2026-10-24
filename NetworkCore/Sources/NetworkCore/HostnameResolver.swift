//
//  HostnameResolver.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Nguồn gốc của tên máy chủ được phát hiện trong mạng LAN
public enum HostnameSource: String, Sendable, Comparable, Codable {
    case mDNS = "mDNS"
    case netBIOS = "NetBIOS"
    case llmnr = "LLMNR"
    case ptr = "DNS PTR"
    case none = "Không xác định"
    
    public var priorityValue: Int {
        switch self {
        case .mDNS: return 4
        case .netBIOS: return 3
        case .llmnr: return 2
        case .ptr: return 1
        case .none: return 0
        }
    }
    
    public static func < (lhs: HostnameSource, rhs: HostnameSource) -> Bool {
        return lhs.priorityValue < rhs.priorityValue
    }
}

/// Kết quả phân giải tên máy chủ kèm nguồn
public struct ResolvedHostname: Sendable, Equatable, Codable {
    public let name: String
    public let source: HostnameSource
    
    public init(name: String, source: HostnameSource) {
        self.name = name
        self.source = source
    }
}

/// Bộ phân giải tên thiết bị mạng LAN với phân cấp độ ưu tiên: mDNS > NetBIOS > LLMNR > PTR
public enum HostnameResolver {
    
    /// Lựa chọn tên thiết bị tốt nhất dựa trên thứ tự ưu tiên chuẩn:
    /// 1. mDNS (Multicast DNS - Bonjour / Apple / IoT)
    /// 2. NetBIOS (Windows / Samba / NAS)
    /// 3. LLMNR (Link-Local Multicast Name Resolution)
    /// 4. DNS PTR (Phân giải ngược từ DNS router nội bộ)
    public static func resolveBestHostname(
        mDNS: String? = nil,
        netBIOS: String? = nil,
        llmnr: String? = nil,
        ptr: String? = nil
    ) -> ResolvedHostname? {
        if let m = sanitizeHostname(mDNS) {
            return ResolvedHostname(name: m, source: .mDNS)
        }
        if let nb = sanitizeHostname(netBIOS) {
            return ResolvedHostname(name: nb, source: .netBIOS)
        }
        if let ll = sanitizeHostname(llmnr) {
            return ResolvedHostname(name: ll, source: .llmnr)
        }
        if let p = sanitizeHostname(ptr) {
            return ResolvedHostname(name: p, source: .ptr)
        }
        return nil
    }
    
    /// Làm sạch chuỗi hostname (loại bỏ dấu chấm cuối, khoảng trắng thừa, ký tự null, và tên rỗng)
    public static func sanitizeHostname(_ candidate: String?) -> String? {
        guard let raw = candidate else { return nil }
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\0", with: "")
        
        // Loại bỏ dấu chấm cuối cùng (FQDN root dot e.g. "myhost.local.")
        while cleaned.hasSuffix(".") {
            cleaned = String(cleaned.dropLast())
        }
        
        // Bỏ qua các chuỗi vô nghĩa hoặc placeholder rỗng
        guard !cleaned.isEmpty,
              cleaned != "unknown",
              cleaned != "(null)",
              cleaned != "localhost" else {
            return nil
        }
        
        return cleaned
    }
    
    /// Chuyển đổi địa chỉ IPv4 thành tên miền tra cứu ngược RFC 1035 (in-addr.arpa)
    /// Ví dụ: "192.168.1.42" -> "42.1.168.192.in-addr.arpa"
    public static func ipv4ToReverseDomain(_ ip: String) -> String? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        for part in parts {
            guard let val = Int(part), val >= 0 && val <= 255 else { return nil }
        }
        return "\(parts[3]).\(parts[2]).\(parts[1]).\(parts[0]).in-addr.arpa"
    }
    
    /// Chuyển đổi địa chỉ IPv6 thành tên miền tra cứu ngược RFC 3596 (ip6.arpa)
    /// Đầy đủ 32 nibbles đảo ngược
    public static func ipv6ToReverseDomain(_ ip: String) -> String? {
        var sin6 = sockaddr_in6()
        guard inet_pton(AF_INET6, ip, &sin6.sin6_addr) == 1 else { return nil }
        
        // Đọc 16 bytes của IPv6
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: sin6.sin6_addr) { buffer in
            for i in 0..<16 {
                bytes[i] = buffer[i]
            }
        }
        
        // Đảo ngược 32 nibbles và ghép nối với .ip6.arpa
        var nibbles: [String] = []
        for byte in bytes.reversed() {
            let low = byte & 0x0F
            let high = (byte >> 4) & 0x0F
            nibbles.append(String(format: "%x", low))
            nibbles.append(String(format: "%x", high))
        }
        
        return nibbles.joined(separator: ".") + ".ip6.arpa"
    }
}
