//
//  RDAPBootstrapParser.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Cấu trúc phân tích tệp IANA Bootstrap Registry theo RFC 9224 (dns.json, ipv4.json, ipv6.json, asn.json)
public struct IANABootstrapPayload: Codable, Sendable {
    public let version: String?
    public let publication: String?
    public let description: String?
    public let services: [[[String]]]
    
    public init(version: String? = nil, publication: String? = nil, description: String? = nil, services: [[[String]]] = []) {
        self.version = version
        self.publication = publication
        self.description = description
        self.services = services
    }
}

/// Bộ phân tích dữ liệu IANA Bootstrap Registry thành bản đồ tra cứu máy chủ ủy quyền
public enum RDAPBootstrapParser {
    
    /// Phân tích dữ liệu JSON bootstrap từ IANA (data.iana.org/rdap/*.json)
    /// Trả về từ điển ánh xạ: Key (TLD, CIDR, hoặc dải ASN) -> Base URL của máy chủ RDAP
    public static func parse(data: Data) throws -> [String: String] {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(IANABootstrapPayload.self, from: data)
        
        var mapping: [String: String] = [:]
        
        for entry in payload.services {
            guard entry.count >= 2 else { continue }
            let identifiers = entry[0]
            guard let serverBase = entry[1].first else { continue }
            
            // Chuẩn hóa server base kết thúc bằng dấu gạch chéo
            let normalizedBase = serverBase.hasSuffix("/") ? serverBase : "\(serverBase)/"
            
            for id in identifiers {
                let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !cleanId.isEmpty {
                    mapping[cleanId] = normalizedBase
                }
            }
        }
        
        return mapping
    }
}
