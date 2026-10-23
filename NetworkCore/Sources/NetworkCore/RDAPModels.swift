//
//  RDAPModels.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Loại đối tượng truy vấn RDAP (RFC 7480-7484, RFC 9083)
public enum RDAPQueryType: String, Sendable, Codable, CaseIterable {
    case domain
    case ip
    case asn
    
    public var pathComponent: String {
        switch self {
        case .domain: return "domain"
        case .ip: return "ip"
        case .asn: return "autnum"
        }
    }
}

/// Thông tin liên hệ trong hồ sơ RDAP trích xuất từ vCard (RFC 7095)
public struct RDAPContact: Sendable, Codable, Equatable {
    public let role: String
    public let name: String?
    public let organization: String?
    public let email: String?
    public let phone: String?
    
    public init(role: String, name: String? = nil, organization: String? = nil, email: String? = nil, phone: String? = nil) {
        self.role = role
        self.name = name
        self.organization = organization
        self.email = email
        self.phone = phone
    }
}

/// Kết quả phân tích đầy đủ một bản ghi RDAP đã được chuẩn hóa
public struct ParsedRDAPRecord: Sendable, Codable, Equatable {
    public let query: String
    public let queryType: RDAPQueryType
    public let handle: String?
    public let title: String
    public let status: [String]
    
    // Chủ thể & Tổ chức
    public let registrarOrOrg: String?
    public let registrantName: String?
    
    // Các mốc thời gian
    public let registrationDate: String?
    public let expirationDate: String?
    public let lastUpdatedDate: String?
    
    // Mạng & Định tuyến
    public let cidrOrRange: String?
    public let nameservers: [String]
    
    // Danh bạ liên hệ
    public let contacts: [RDAPContact]
    
    // Phản hồi gốc (JSON)
    public let rawJSON: String?
    
    public init(
        query: String,
        queryType: RDAPQueryType,
        handle: String? = nil,
        title: String,
        status: [String] = [],
        registrarOrOrg: String? = nil,
        registrantName: String? = nil,
        registrationDate: String? = nil,
        expirationDate: String? = nil,
        lastUpdatedDate: String? = nil,
        cidrOrRange: String? = nil,
        nameservers: [String] = [],
        contacts: [RDAPContact] = [],
        rawJSON: String? = nil
    ) {
        self.query = query
        self.queryType = queryType
        self.handle = handle
        self.title = title
        self.status = status
        self.registrarOrOrg = registrarOrOrg
        self.registrantName = registrantName
        self.registrationDate = registrationDate
        self.expirationDate = expirationDate
        self.lastUpdatedDate = lastUpdatedDate
        self.cidrOrRange = cidrOrRange
        self.nameservers = nameservers
        self.contacts = contacts
        self.rawJSON = rawJSON
    }
}
