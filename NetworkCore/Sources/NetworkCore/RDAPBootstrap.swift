//
//  RDAPBootstrap.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Bộ phân giải máy chủ RDAP ủy quyền và hỗ trợ IANA Bootstrap Registry (RFC 9224 / RFC 7484)
/// Sử dụng IANA data.iana.org/rdap làm nguồn bootstrap chính thức, rdap.org làm cổng phân phối dự phòng
public enum RDAPBootstrap {
    
    // IANA Official Bootstrap Registry Endpoints (RFC 9224)
    public static let ianaDNSBootstrapURL = URL(string: "https://data.iana.org/rdap/dns.json")!
    public static let ianaIPv4BootstrapURL = URL(string: "https://data.iana.org/rdap/ipv4.json")!
    public static let ianaIPv6BootstrapURL = URL(string: "https://data.iana.org/rdap/ipv6.json")!
    public static let ianaASNBootstrapURL = URL(string: "https://data.iana.org/rdap/asn.json")!
    
    // Bộ đệm tĩnh trong bộ nhớ (In-memory Bootstrap Cache)
    private static var dnsRegistryCache: [String: String] = [
        "com": "https://rdap.verisign.com/com/v1/",
        "net": "https://rdap.verisign.com/net/v1/",
        "org": "https://rdap.publicinterestregistry.org/rdap/",
        "info": "https://rdap.identitydigital.services/rdap/",
        "io": "https://rdap.identitydigital.services/rdap/",
        "me": "https://rdap.identitydigital.services/rdap/",
        "vn": "https://rdap.vnnic.vn/"
    ]
    
    /// Cập nhật cache từ phản hồi bootstrap IANA dns.json
    public static func updateDNSCache(from services: [[[String]]]) {
        for service in services {
            guard service.count >= 2 else { continue }
            let tlds = service[0]
            guard let serverBase = service[1].first else { continue }
            for tld in tlds {
                dnsRegistryCache[tld.lowercased()] = serverBase
            }
        }
    }
    
    /// Tự động phát hiện loại đối tượng truy vấn (Domain, IP, hoặc ASN)
    public static func detectQueryType(from query: String) -> (cleanQuery: String, type: RDAPQueryType) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Kiểm tra ASN: e.g. "AS15169", "as13335", hoặc số nguyên dương thuần túy
        if trimmed.uppercased().hasPrefix("AS") {
            let numberPart = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if Int(numberPart) != nil {
                return (numberPart, .asn)
            }
        } else if let _ = Int(trimmed), trimmed.count >= 2, trimmed.count <= 7 {
            return (trimmed, .asn)
        }
        
        // 2. Kiểm tra IPv4
        let ipv4Parts = trimmed.split(separator: ".")
        if ipv4Parts.count == 4 && ipv4Parts.allSatisfy({ UInt8($0) != nil }) {
            return (trimmed, .ip)
        }
        
        // 3. Kiểm tra IPv6
        if trimmed.contains(":") && !trimmed.contains("/") && !trimmed.contains(" ") {
            return (trimmed, .ip)
        }
        
        // 4. Mặc định là Domain (loại bỏ giao thức https:// nếu người dùng dán URL)
        var domain = trimmed.lowercased()
        if let url = URL(string: domain), let host = url.host {
            domain = host
        }
        if domain.hasPrefix("http://") { domain = String(domain.dropFirst(7)) }
        if domain.hasPrefix("https://") { domain = String(domain.dropFirst(8)) }
        domain = domain.trimmingCharacters(in: CharacterSet(charactersIn: "/."))
        
        return (domain, .domain)
    }
    
    /// Trích xuất TLD (Top-Level Domain) từ tên miền
    public static func extractTLD(from domain: String) -> String? {
        let parts = domain.split(separator: ".")
        guard let last = parts.last, !last.isEmpty else { return nil }
        return String(last).lowercased()
    }
    
    /// Sinh URL truy vấn RDAP phù hợp:
    /// 1. Nếu tìm thấy máy chủ ủy quyền trong IANA bootstrap cache -> truy vấn trực tiếp máy chủ đó
    /// 2. Dự phòng: sử dụng rdap.org (Cổng phân phối IANA RFC 7484 proxy)
    public static func resolveQueryURL(for query: String, type: RDAPQueryType) -> URL? {
        let (clean, detectedType) = detectQueryType(from: query)
        let finalType = type == .domain && detectedType != .domain ? detectedType : type
        
        switch finalType {
        case .domain:
            guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
            if let tld = extractTLD(from: clean), let serverBase = dnsRegistryCache[tld] {
                let formattedBase = serverBase.hasSuffix("/") ? serverBase : "\(serverBase)/"
                return URL(string: "\(formattedBase)domain/\(encoded)")
            }
            // Fallback sang rdap.org
            return URL(string: "https://rdap.org/domain/\(encoded)")
            
        case .ip:
            guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
            // Dự phòng tin cậy: rdap.org tự động redirect 307 tới ARIN, RIPE, APNIC, LACNIC, AFRINIC
            return URL(string: "https://rdap.org/ip/\(encoded)")
            
        case .asn:
            guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
            return URL(string: "https://rdap.org/autnum/\(encoded)")
        }
    }
}
