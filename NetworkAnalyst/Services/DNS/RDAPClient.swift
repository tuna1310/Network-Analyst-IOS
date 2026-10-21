//
//  RDAPClient.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Kết quả phân tích thông tin đăng ký tên miền / IP qua giao thức RDAP
public struct RDAPResult: Sendable, Identifiable {
    public let id = UUID()
    public let query: String
    public let handle: String?
    public let ldhName: String?
    public let status: [String]
    public let registrar: String?
    public let registrationDate: String?
    public let expirationDate: String?
    public let lastUpdatedDate: String?
    public let nameservers: [String]
    public let rawJSON: String?
    public let error: String?
    
    public init(
        query: String,
        handle: String? = nil,
        ldhName: String? = nil,
        status: [String] = [],
        registrar: String? = nil,
        registrationDate: String? = nil,
        expirationDate: String? = nil,
        lastUpdatedDate: String? = nil,
        nameservers: [String] = [],
        rawJSON: String? = nil,
        error: String? = nil
    ) {
        self.query = query
        self.handle = handle
        self.ldhName = ldhName
        self.status = status
        self.registrar = registrar
        self.registrationDate = registrationDate
        self.expirationDate = expirationDate
        self.lastUpdatedDate = lastUpdatedDate
        self.nameservers = nameservers
        self.rawJSON = rawJSON
        self.error = error
    }
}

/// Client tra cứu thông tin WHOIS/RDAP chính quy qua URLSession theo RFC 7480-7484
public actor RDAPClient {
    public static let shared = RDAPClient()
    
    private let session: URLSession
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        self.session = URLSession(configuration: config)
    }
    
    /// Tra cứu tên miền hoặc IP
    public func lookup(query: String) async -> RDAPResult {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanQuery.isEmpty else {
            return RDAPResult(query: query, error: "Tên miền hoặc IP không hợp lệ")
        }
        
        let isIP = cleanQuery.split(separator: ".").compactMap { UInt8($0) }.count == 4 || cleanQuery.contains(":")
        let endpointString = isIP
            ? "https://rdap.arin.net/registry/ip/\(cleanQuery)"
            : "https://rdap.org/domain/\(cleanQuery)"
        
        guard let url = URL(string: endpointString) else {
            return RDAPResult(query: cleanQuery, error: "Đường dẫn tra cứu không hợp lệ")
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/rdap+json, application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else {
                return RDAPResult(query: cleanQuery, error: "Không nhận được phản hồi từ máy chủ RDAP")
            }
            
            if httpResp.statusCode == 404 {
                return RDAPResult(query: cleanQuery, error: "Không tìm thấy thông tin đăng ký cho \(cleanQuery) (Chưa đăng ký hoặc được bảo vệ riêng tư).")
            }
            
            guard httpResp.statusCode == 200 else {
                return RDAPResult(query: cleanQuery, error: "Máy chủ RDAP trả về mã HTTP \(httpResp.statusCode)")
            }
            
            let rawString = String(data: data, encoding: .utf8)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            let handle = json["handle"] as? String
            let ldhName = json["ldhName"] as? String ?? cleanQuery
            let status = json["status"] as? [String] ?? []
            
            // Events: dates
            var regDate: String? = nil
            var expDate: String? = nil
            var updDate: String? = nil
            
            if let events = json["events"] as? [[String: Any]] {
                for ev in events {
                    let action = ev["eventAction"] as? String ?? ""
                    let date = ev["eventDate"] as? String ?? ""
                    if action == "registration" { regDate = date }
                    else if action == "expiration" { expDate = date }
                    else if action == "last changed" || action == "last update" { updDate = date }
                }
            }
            
            // Entities: Registrar
            var registrarName: String? = nil
            if let entities = json["entities"] as? [[String: Any]] {
                for ent in entities {
                    let roles = ent["roles"] as? [String] ?? []
                    if roles.contains("registrar") {
                        if let vcard = ent["vcardArray"] as? [Any], vcard.count > 1, let items = vcard[1] as? [[Any]] {
                            for item in items {
                                if let prop = item.first as? String, prop == "fn", item.count > 3 {
                                    registrarName = item[3] as? String
                                }
                            }
                        }
                        if registrarName == nil {
                            registrarName = ent["handle"] as? String
                        }
                    }
                }
            }
            
            // Nameservers
            var nsList: [String] = []
            if let ns = json["nameservers"] as? [[String: Any]] {
                for server in ns {
                    if let name = server["ldhName"] as? String {
                        nsList.append(name)
                    }
                }
            }
            
            return RDAPResult(
                query: cleanQuery,
                handle: handle,
                ldhName: ldhName,
                status: status,
                registrar: registrarName,
                registrationDate: regDate,
                expirationDate: expDate,
                lastUpdatedDate: updDate,
                nameservers: nsList,
                rawJSON: rawString,
                error: nil
            )
            
        } catch {
            return RDAPResult(query: cleanQuery, error: "Lỗi kết nối: \(error.localizedDescription)")
        }
    }
}
