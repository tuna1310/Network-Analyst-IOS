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
                    
                    // Kiểm tra hostname hợp lệ (ít nhất chứa ký tự chữ và dấu chấm)
                    if candidate.contains(".") && !candidate.contains(" ") && candidate.count >= 4 {
                        return candidate
                    }
                }
            }
        }
        
        return nil
    }
}
