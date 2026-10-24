//
//  RDAPClient.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import NetworkCore

/// Client tra cứu thông tin sở hữu tên miền / IP / ASN chính quy qua giao thức RDAP (RFC 7480-7484, RFC 9083)
public actor RDAPClient {
    public static let shared = RDAPClient()
    
    private let session: URLSession
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: config)
    }
    
    /// Thực hiện tra cứu RDAP với hỗ trợ tự động phát hiện loại (Domain, IP, ASN)
    public func lookup(query: String, explicitType: RDAPQueryType? = nil) async -> Result<ParsedRDAPRecord, Error> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(NSError(domain: "RDAPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Chuỗi tra cứu không được để trống"]))
        }
        
        let (cleanQuery, detectedType) = RDAPBootstrap.detectQueryType(from: trimmed)
        let finalType = explicitType ?? detectedType
        
        // Đảm bảo nạp dữ liệu Bootstrap động từ IANA (cache đĩa 24h)
        await RDAPBootstrapManager.shared.ensureBootstrapLoaded()
        
        guard let url = RDAPBootstrap.resolveQueryURL(for: cleanQuery, type: finalType) else {
            return .failure(NSError(domain: "RDAPClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo URL RDAP hợp lệ"]))
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/rdap+json, application/json", forHTTPHeaderField: "Accept")
        request.setValue("NetworkAnalyst/1.0 (iOS; Swift 5.9)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else {
                return .failure(NSError(domain: "RDAPClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Không nhận được phản hồi HTTP từ máy chủ"]))
            }
            
            if httpResp.statusCode == 404 {
                let msg = String(localized: "rdap.not_found", defaultValue: "Không tìm thấy hồ sơ đăng ký cho \(cleanQuery) (Chưa đăng ký hoặc được bảo vệ danh tính).")
                return .failure(NSError(domain: "RDAPClient", code: 404, userInfo: [NSLocalizedDescriptionKey: msg]))
            }
            
            if httpResp.statusCode == 429 {
                let msg = String(localized: "rdap.rate_limited", defaultValue: "Máy chủ RDAP vượt quá giới hạn tần suất (HTTP 429). Vui lòng thử lại sau giây lát.")
                return .failure(NSError(domain: "RDAPClient", code: 429, userInfo: [NSLocalizedDescriptionKey: msg]))
            }
            
            guard httpResp.statusCode == 200 else {
                return .failure(NSError(domain: "RDAPClient", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "Máy chủ RDAP trả về mã HTTP \(httpResp.statusCode)"]))
            }
            
            let parsed = try RDAPParser.parse(data: data, query: cleanQuery, queryType: finalType)
            return .success(parsed)
            
        } catch {
            return .failure(error)
        }
    }
}
