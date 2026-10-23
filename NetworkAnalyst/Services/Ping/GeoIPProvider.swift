//
//  GeoIPProvider.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Protocol trừu tượng cho dịch vụ tra cứu vị trí địa lý của router IP
public protocol GeoIPProvider: Sendable {
    func lookup(ip: String) async -> HopGeoIPInfo?
}

/// Triển khai mặc định qua HTTPS API công cộng (ipinfo.io)
/// Giới hạn: API miễn phí có hạn mức ~50,000 lượt/tháng, tuân thủ ATS (HTTPS thuần túy).
public actor HTTPSGeoIPProvider: GeoIPProvider {
    public static let shared = HTTPSGeoIPProvider()
    
    public static let sourceName = "ipinfo.io (HTTPS API)"
    
    private var cache: [String: HopGeoIPInfo] = [:]
    private let urlSession: URLSession
    private var requestCountThisSession: Int = 0
    private let maxRequestsPerSession: Int = 40
    private var lastRequestTime: CFAbsoluteTime = 0
    
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3.5
        config.timeoutIntervalForResource = 5.0
        self.urlSession = URLSession(configuration: config)
    }
    
    public func resetSessionLimit() {
        self.requestCountThisSession = 0
    }
    
    public func lookup(ip: String) async -> HopGeoIPInfo? {
        let cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Kiểm tra cache
        if let cached = cache[cleanIP] {
            return cached
        }
        
        // 2. Bỏ qua IP cục bộ (RFC 1918) và loopback
        if isPrivateIP(cleanIP) {
            let localInfo = HopGeoIPInfo(ip: cleanIP, country: "Private LAN", countryCode: "LAN", city: "Local")
            cache[cleanIP] = localInfo
            return localInfo
        }
        
        // 3. Giới hạn tần suất và số lượng gọi trong phiên (Rate Limiting)
        guard requestCountThisSession < maxRequestsPerSession else {
            return nil
        }
        
        // Đảm bảo giãn cách tối thiểu 200ms giữa các request để tránh bị 429
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastRequestTime
        if elapsed < 0.2 {
            let waitNanos = UInt64((0.2 - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: waitNanos)
        }
        lastRequestTime = CFAbsoluteTimeGetCurrent()
        requestCountThisSession += 1
        
        guard let url = URL(string: "https://ipinfo.io/\(cleanIP)/json") else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            
            struct RawGeo: Decodable {
                let country: String?
                let city: String?
            }
            
            let decoded = try JSONDecoder().decode(RawGeo.self, from: data)
            let result = HopGeoIPInfo(
                ip: cleanIP,
                country: decoded.country,
                countryCode: decoded.country,
                city: decoded.city
            )
            cache[cleanIP] = result
            return result
        } catch {
            // Lỗi mạng hoặc rate limit -> trả về nil để UI hiện "không rõ"
            return nil
        }
    }
    
    private func isPrivateIP(_ ip: String) -> Bool {
        return ip.hasPrefix("10.") ||
               ip.hasPrefix("192.168.") ||
               ip.hasPrefix("127.") ||
               ip.hasPrefix("172.16.") || ip.hasPrefix("172.17.") || ip.hasPrefix("172.18.") ||
               ip.hasPrefix("172.19.") || ip.hasPrefix("172.20.") || ip.hasPrefix("172.21.") ||
               ip.hasPrefix("172.22.") || ip.hasPrefix("172.23.") || ip.hasPrefix("172.24.") ||
               ip.hasPrefix("172.25.") || ip.hasPrefix("172.26.") || ip.hasPrefix("172.27.") ||
               ip.hasPrefix("172.28.") || ip.hasPrefix("172.29.") || ip.hasPrefix("172.30.") ||
               ip.hasPrefix("172.31.")
    }
}
