//
//  WhoisReferralParser.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Bộ phân tích phản hồi WHOIS văn bản (RFC 3912) để trích xuất máy chủ chuyển tiếp (Referral WHOIS Server)
public enum WhoisReferralParser {
    
    private static let referralPrefixes = [
        "refer:",
        "whois:",
        "registrar whois server:",
        "whois server:",
        "registration service provider:",
        "referralserver:"
    ]
    
    /// Trích xuất tên máy chủ chuyển tiếp (ví dụ: "whois.verisign-grs.com" hoặc "whois.markmonitor.com")
    public static func extractReferralServer(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            
            for prefix in referralPrefixes {
                if lower.hasPrefix(prefix) {
                    var candidate = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    
                    // Xử lý trường hợp URL e.g. "rwhois://..." hoặc "whois://..."
                    if candidate.hasPrefix("rwhois://") {
                        candidate = String(candidate.dropFirst(9))
                    } else if candidate.hasPrefix("whois://") {
                        candidate = String(candidate.dropFirst(8))
                    }
                    
                    // Loại bỏ cổng nếu có (e.g. "whois.server.com:43")
                    if let colonIndex = candidate.firstIndex(of: ":") {
                        candidate = String(candidate[..<colonIndex])
                    }
                    
                    // Loại bỏ dấu gạch chéo cuối
                    candidate = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "/ \t\r\n"))
                    
                    // Kiểm tra hostname hợp lệ và không trỏ tới localhost/mạng riêng tư nội bộ (chống SSRF)
                    if isValidPublicWhoisHost(candidate) {
                        return candidate
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Kiểm tra hostname có hợp lệ và thuộc dải công cộng hay không (chống SSRF / kết nối LAN vô ý)
    public static func isValidPublicWhoisHost(_ candidate: String) -> Bool {
        let clean = candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.contains(".") && !clean.contains(" ") && clean.count >= 4 else { return false }
        
        // Ngăn chặn localhost và địa chỉ IP loopback / private RFC 1918 / link-local
        if clean == "localhost" ||
           clean.hasPrefix("127.") ||
           clean.hasPrefix("10.") ||
           clean.hasPrefix("192.168.") ||
           clean.hasPrefix("169.254.") ||
           clean == "::1" ||
           clean.hasPrefix("fe80:") ||
           clean.hasPrefix("fc00:") {
            return false
        }
        
        // Kiểm tra 172.16.0.0 - 172.31.255.255
        if clean.hasPrefix("172.") {
            let parts = clean.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), second >= 16 && second <= 31 {
                return false
            }
        }
        
        return true
    }
}
