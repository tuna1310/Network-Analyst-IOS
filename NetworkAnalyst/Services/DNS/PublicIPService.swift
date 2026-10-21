//
//  PublicIPService.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Dữ liệu định vị và thông tin nhà mạng của IP công khai
public struct PublicIPDetails: Sendable, Codable {
    public let ip: String
    public let hostname: String?
    public let city: String?
    public let region: String?
    public let country: String?
    public let countryCode: String?
    public let loc: String?
    public let org: String?
    public let postal: String?
    public let timezone: String?
    public let queryTimeMs: Double?
    
    public init(
        ip: String,
        hostname: String? = nil,
        city: String? = nil,
        region: String? = nil,
        country: String? = nil,
        countryCode: String? = nil,
        loc: String? = nil,
        org: String? = nil,
        postal: String? = nil,
        timezone: String? = nil,
        queryTimeMs: Double? = nil
    ) {
        self.ip = ip
        self.hostname = hostname
        self.city = city
        self.region = region
        self.country = country
        self.countryCode = countryCode
        self.loc = loc
        self.org = org
        self.postal = postal
        self.timezone = timezone
        self.queryTimeMs = queryTimeMs
    }
}

/// Dịch vụ tra cứu IP công khai qua URLSession
public actor PublicIPService {
    public static let shared = PublicIPService()
    
    private let session: URLSession
    
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 8.0
        self.session = URLSession(configuration: config)
    }
    
    /// Lấy thông tin IP công khai hiện tại cùng vị trí địa lý và ISP
    public func fetchPublicIP() async throws -> PublicIPDetails {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Thử ipinfo.io trước để lấy đầy đủ ISP và vị trí
        if let details = await queryIPInfo(startTime: startTime) {
            return details
        }
        
        // Dự phòng ipify.org nếu ipinfo bị rate-limit
        if let ip = await queryIpify() {
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return PublicIPDetails(ip: ip, queryTimeMs: elapsed)
        }
        
        throw URLError(.cannotFindHost)
    }
    
    private func queryIPInfo(startTime: Double) async -> PublicIPDetails? {
        guard let url = URL(string: "https://ipinfo.io/json") else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            
            struct IPInfoResponse: Decodable {
                let ip: String
                let hostname: String?
                let city: String?
                let region: String?
                let country: String?
                let loc: String?
                let org: String?
                let postal: String?
                let timezone: String?
            }
            
            let decoded = try JSONDecoder().decode(IPInfoResponse.self, from: data)
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            
            return PublicIPDetails(
                ip: decoded.ip,
                hostname: decoded.hostname,
                city: decoded.city,
                region: decoded.region,
                country: decoded.country,
                countryCode: decoded.country,
                loc: decoded.loc,
                org: decoded.org,
                postal: decoded.postal,
                timezone: decoded.timezone,
                queryTimeMs: elapsed
            )
        } catch {
            return nil
        }
    }
    
    private func queryIpify() async -> String? {
        guard let url = URL(string: "https://api.ipify.org?format=json") else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            struct IpifyResponse: Decodable {
                let ip: String
            }
            let res = try JSONDecoder().decode(IpifyResponse.self, from: data)
            return res.ip
        } catch {
            return nil
        }
    }
}
