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

/// Triển khai mặc định qua HTTPS API công cộng không cần khóa (ipwho.is - đồng nhất với bản Android)
/// Giới hạn: API miễn phí có hạn mức ~10,000 lượt/tháng, không yêu cầu API key bí mật, tuân thủ ATS (HTTPS thuần túy).
public actor HTTPSGeoIPProvider: GeoIPProvider {
    public static let shared = HTTPSGeoIPProvider()
    
    public static var sourceName: String {
        String(localized: "traceroute.geoip_source_desc", defaultValue: "ipwho.is (HTTPS, miễn phí ~10,000 lượt/tháng, không cần API Key)")
    }
    
    private var cache: [String: HopGeoIPInfo] = [:]
    private let urlSession: URLSession
    private var requestCountThisSession: Int = 0
    private let maxRequestsPerSession: Int = 30
    private var lastRequestTime: ContinuousClock.Instant? = nil
    
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 6.0
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
        
        // 3. Giới hạn tần suất và số lượng gọi trong phiên (Rate Limiting phòng ngừa lạm dụng)
        guard requestCountThisSession < maxRequestsPerSession else {
            return nil
        }
        
        // Đảm bảo giãn cách tối thiểu 250ms giữa các request để bảo vệ quota
        if let last = lastRequestTime {
            let elapsedMs = MonotonicClock.elapsedMs(since: last)
            if elapsedMs < 250.0 {
                let waitNanos = UInt64((250.0 - elapsedMs) * 1_000_000)
                try? await Task.sleep(nanoseconds: waitNanos)
            }
        }
        lastRequestTime = MonotonicClock.now()
        requestCountThisSession += 1
        
        guard let url = URL(string: "https://ipwho.is/\(cleanIP)") else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            
            struct IPWhoIsResponse: Decodable {
                let success: Bool
                let country: String?
                let country_code: String?
                let city: String?
                let message: String?
            }
            
            let decoded = try JSONDecoder().decode(IPWhoIsResponse.self, from: data)
            guard decoded.success else {
                return nil
            }
            
            let result = HopGeoIPInfo(
                ip: cleanIP,
                country: decoded.country,
                countryCode: decoded.country_code,
                city: decoded.city
            )
            cache[cleanIP] = result
            return result
        } catch {
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
