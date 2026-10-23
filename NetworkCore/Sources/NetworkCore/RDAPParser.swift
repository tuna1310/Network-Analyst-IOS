//
//  RDAPParser.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Bộ phân tích dữ liệu RDAP theo chuẩn RFC 7483 / RFC 9083 (JSON Responses for RDAP)
public enum RDAPParser {
    
    /// Phân tích dữ liệu JSON RDAP thành `ParsedRDAPRecord`
    public static func parse(data: Data, query: String, queryType: RDAPQueryType) throws -> ParsedRDAPRecord {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "RDAPParserError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed JSON"])
        }
        
        let rawJSON = String(data: data, encoding: .utf8)
        let handle = json["handle"] as? String
        
        // 1. Tiêu đề bản ghi tùy theo queryType
        var title = query
        if let ldhName = json["ldhName"] as? String, !ldhName.isEmpty {
            title = ldhName
        } else if let name = json["name"] as? String, !name.isEmpty {
            title = name
        } else if let startAutnum = json["startAutnum"] as? Int {
            title = "AS\(startAutnum)"
        }
        
        // 2. Trạng thái (status)
        let status = (json["status"] as? [String]) ?? []
        
        // 3. Sự kiện thời gian (events: registration, expiration, last changed)
        var regDate: String? = nil
        var expDate: String? = nil
        var updDate: String? = nil
        
        if let events = json["events"] as? [[String: Any]] {
            for ev in events {
                guard let action = ev["eventAction"] as? String,
                      let dateStr = ev["eventDate"] as? String else { continue }
                
                let normAction = action.lowercased()
                if normAction == "registration" {
                    regDate = dateStr
                } else if normAction == "expiration" {
                    expDate = dateStr
                } else if normAction.contains("last") || normAction == "transfer" {
                    if updDate == nil {
                        updDate = dateStr
                    }
                }
            }
        }
        
        // 4. Phân tích thực thể (Entities: Registrar, Registrant, Contacts)
        var registrarOrOrg: String? = nil
        var registrantName: String? = nil
        var contacts: [RDAPContact] = []
        
        if let entities = json["entities"] as? [[String: Any]] {
            parseEntities(entities, registrar: &registrarOrOrg, registrant: &registrantName, contacts: &contacts)
        }
        
        // Nếu là IP hoặc ASN và chưa có tổ chức từ entities, lấy từ name
        if registrarOrOrg == nil, let name = json["name"] as? String, !name.isEmpty {
            registrarOrOrg = name
        }
        
        // 5. CIDR / Dải địa chỉ IP (cho IP Network)
        var cidrOrRange: String? = nil
        if queryType == .ip {
            if let cidrs = json["cidr0_cidrs"] as? [[String: Any]], !cidrs.isEmpty {
                let formatted = cidrs.compactMap { cidrItem -> String? in
                    let prefix = (cidrItem["v4prefix"] as? String) ?? (cidrItem["v6prefix"] as? String)
                    let length = (cidrItem["length"] as? Int)
                    if let p = prefix, let l = length {
                        return "\(p)/\(l)"
                    }
                    return nil
                }
                if !formatted.isEmpty {
                    cidrOrRange = formatted.joined(separator: ", ")
                }
            }
            
            if cidrOrRange == nil {
                let start = json["startAddress"] as? String
                let end = json["endAddress"] as? String
                if let s = start, let e = end {
                    cidrOrRange = "\(s) - \(e)"
                }
            }
        } else if queryType == .asn {
            let start = json["startAutnum"] as? Int
            let end = json["endAutnum"] as? Int
            if let s = start, let e = end {
                cidrOrRange = s == e ? "AS\(s)" : "AS\(s) - AS\(e)"
            }
        }
        
        // 6. Máy chủ tên miền (Nameservers)
        var nameservers: [String] = []
        if let nsList = json["nameservers"] as? [[String: Any]] {
            for ns in nsList {
                if let ldh = ns["ldhName"] as? String {
                    nameservers.append(ldh)
                }
            }
        }
        
        return ParsedRDAPRecord(
            query: query,
            queryType: queryType,
            handle: handle,
            title: title,
            status: status,
            registrarOrOrg: registrarOrOrg,
            registrantName: registrantName,
            registrationDate: regDate,
            expirationDate: expDate,
            lastUpdatedDate: updDate,
            cidrOrRange: cidrOrRange,
            nameservers: nameservers,
            contacts: contacts,
            rawJSON: rawJSON
        )
    }
    
    // MARK: - Helper vCard parsing
    private static func parseEntities(
        _ entities: [[String: Any]],
        registrar: inout String?,
        registrant: inout String?,
        contacts: inout [RDAPContact]
    ) {
        for ent in entities {
            let roles = (ent["roles"] as? [String]) ?? []
            let handle = ent["handle"] as? String
            
            var name: String? = nil
            var org: String? = nil
            var email: String? = nil
            var phone: String? = nil
            
            // Trích xuất từ vCard (RFC 7095 jCard format)
            if let vcard = ent["vcardArray"] as? [Any], vcard.count > 1,
               let items = vcard[1] as? [[Any]] {
                for item in items {
                    guard let prop = item.first as? String, item.count >= 4 else { continue }
                    let propLower = prop.lowercased()
                    if propLower == "fn" {
                        name = item[3] as? String
                    } else if propLower == "org" {
                        if let orgStr = item[3] as? String {
                            org = orgStr
                        } else if let orgArr = item[3] as? [String], let first = orgArr.first {
                            org = first
                        }
                    } else if propLower == "email" {
                        email = item[3] as? String
                    } else if propLower == "tel" {
                        phone = item[3] as? String
                    }
                }
            }
            
            let primaryRole = roles.first ?? "entity"
            
            if roles.contains("registrar") {
                if registrar == nil {
                    registrar = org ?? name ?? handle
                }
            }
            
            if roles.contains("registrant") {
                if registrant == nil {
                    registrant = name ?? org ?? handle
                }
            }
            
            if name != nil || org != nil || email != nil || phone != nil {
                contacts.append(RDAPContact(
                    role: primaryRole,
                    name: name,
                    organization: org,
                    email: email,
                    phone: phone
                ))
            }
            
            // Đệ quy nếu entity có entities lồng nhau
            if let subEntities = ent["entities"] as? [[String: Any]] {
                parseEntities(subEntities, registrar: &registrar, registrant: &registrant, contacts: &contacts)
            }
        }
    }
}
