//
//  OUIDatabase.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Kết quả phân tích địa chỉ MAC
public enum MACLookupResult: Sendable, Equatable {
    case randomized
    case vendor(String)
    case unknown
    
    public var displayName: String {
        switch self {
        case .randomized:
            return "Private / Randomized MAC"
        case .vendor(let name):
            return name
        case .unknown:
            return "Unknown Vendor"
        }
    }
}

/// Cơ sở dữ liệu OUI chính thức từ IEEE phục vụ tra cứu nhà sản xuất theo địa chỉ MAC
public final class OUIDatabase: @unchecked Sendable {
    public static let shared = OUIDatabase()
    
    private var database: [String: String] = [:]
    private var isLoaded: Bool = false
    private let lock = NSLock()
    
    public init(customDictionary: [String: String]? = nil) {
        if let custom = customDictionary {
            self.database = custom
            self.isLoaded = true
        }
    }
    
    /// Chuẩn hóa địa chỉ MAC thành chuỗi hex viết hoa
    /// Hỗ trợ: AA:BB:CC:DD:EE:FF, AA-BB-CC-DD-EE-FF, AABB.CCDD.EEFF, hoặc AABBCCDDEEFF
    public static func normalizeMAC(_ mac: String) -> String? {
        let cleaned = mac.filter { $0.isHexDigit }.uppercased()
        guard cleaned.count >= 6 else { return nil }
        return cleaned
    }
    
    /// Kiểm tra bit Locally Administered (bit 1 của byte đầu tiên).
    /// Nếu bit này = 1, đây là địa chỉ MAC ngẫu nhiên/riêng tư (Private/Randomized MAC) của iOS/Android/Windows,
    /// IEEE không cấp phát cho bất kỳ nhà sản xuất nào.
    public static func isLocallyAdministered(mac: String) -> Bool {
        guard let cleaned = normalizeMAC(mac), cleaned.count >= 2 else { return false }
        let byte0Hex = String(cleaned.prefix(2))
        guard let byte0 = UInt8(byte0Hex, radix: 16) else { return false }
        return (byte0 & 0x02) != 0
    }
    
    /// Trích xuất tiền tố OUI 24-bit (6 ký tự hex đầu tiên)
    public static func extractOUI24(from mac: String) -> String? {
        guard let normalized = normalizeMAC(mac), normalized.count >= 6 else { return nil }
        return String(normalized.prefix(6))
    }
    
    /// Đảm bảo nạp dữ liệu lazy từ oui.json thông qua Bundle.module
    private func ensureLoaded() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isLoaded else { return }
        
        #if SWIFT_PACKAGE
        let dataUrl = Bundle.module.url(forResource: "oui", withExtension: "json")
        #else
        let dataUrl = Bundle(for: OUIDatabase.self).url(forResource: "oui", withExtension: "json") ?? Bundle.main.url(forResource: "oui", withExtension: "json")
        #endif
        
        if let url = dataUrl, let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                self.database = decoded
            }
        }
        
        self.isLoaded = true
    }
    
    /// Phân tích địa chỉ MAC và trả về kết quả (Ngẫu nhiên / Vendor / Chưa rõ)
    public func lookupDetail(mac: String) -> MACLookupResult {
        guard let normalized = Self.normalizeMAC(mac) else {
            return .unknown
        }
        
        // 1. Kiểm tra MAC ngẫu nhiên trước
        if Self.isLocallyAdministered(mac: normalized) {
            return .randomized
        }
        
        ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        
        // 2. Thử tra 36-bit OUI (MA-S) nếu có đủ 9 ký tự hex
        if normalized.count >= 9 {
            let prefix36 = String(normalized.prefix(9))
            if let vendor = database[prefix36] {
                return .vendor(vendor)
            }
        }
        
        // 3. Thử tra 28-bit OUI (MA-M) nếu có đủ 7 ký tự hex
        if normalized.count >= 7 {
            let prefix28 = String(normalized.prefix(7))
            if let vendor = database[prefix28] {
                return .vendor(vendor)
            }
        }
        
        // 4. Tra 24-bit OUI (MA-L tiêu chuẩn)
        let prefix24 = String(normalized.prefix(6))
        if let vendor = database[prefix24] {
            return .vendor(vendor)
        }
        
        return .unknown
    }
    
    /// Tra cứu tên nhà sản xuất từ địa chỉ MAC (trả về chuỗi nếu tìm thấy hoặc chuỗi MAC ngẫu nhiên)
    public func lookup(mac: String) -> String? {
        let result = lookupDetail(mac: mac)
        switch result {
        case .randomized:
            return "Private / Randomized MAC"
        case .vendor(let name):
            return name
        case .unknown:
            return nil
        }
    }
    
    public var entryCount: Int {
        ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return database.count
    }
}
