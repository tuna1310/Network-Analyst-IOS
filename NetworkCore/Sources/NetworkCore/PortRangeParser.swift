//
//  PortRangeParser.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Lỗi phân tích cú pháp dải cổng
public enum PortParseError: Error, Equatable, LocalizedError {
    case emptyInput
    case invalidToken(String)
    case portOutOfRange(Int)
    case invertedRange(start: Int, end: Int)
    
    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Chuỗi nhập dải cổng không được để trống"
        case .invalidToken(let token):
            return "Ký tự hoặc định dạng không hợp lệ: '\(token)'"
        case .portOutOfRange(let port):
            return "Cổng \(port) nằm ngoài phạm vi cho phép (1 - 65535)"
        case .invertedRange(let start, let end):
            return "Dải cổng không hợp lệ: \(start) lớn hơn \(end)"
        }
    }
}

/// Bộ phân tích cú pháp dải cổng TCP và ước tính thời gian quét
public enum PortRangeParser {
    
    /// Phân tích chuỗi đầu vào thành danh sách các số hiệu cổng duy nhất được sắp xếp tăng dần
    /// Hỗ trợ cú pháp: "80, 443, 8000-8080, 22"
    public static func parse(_ input: String) -> Result<[Int], PortParseError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.emptyInput)
        }
        
        let tokens = trimmed.components(separatedBy: CharacterSet(charactersIn: ",; "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        guard !tokens.isEmpty else {
            return .failure(.emptyInput)
        }
        
        var portSet = Set<Int>()
        
        for token in tokens {
            if token.contains("-") {
                // Định dạng dải: "start-end"
                let parts = token.components(separatedBy: "-")
                guard parts.count == 2,
                      let start = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                      let end = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
                    return .failure(.invalidToken(token))
                }
                
                guard start >= 1 && start <= 65535 else {
                    return .failure(.portOutOfRange(start))
                }
                guard end >= 1 && end <= 65535 else {
                    return .failure(.portOutOfRange(end))
                }
                guard start <= end else {
                    return .failure(.invertedRange(start: start, end: end))
                }
                
                for p in start...end {
                    portSet.insert(p)
                }
            } else {
                // Định dạng cổng đơn: "80"
                guard let port = Int(token) else {
                    return .failure(.invalidToken(token))
                }
                guard port >= 1 && port <= 65535 else {
                    return .failure(.portOutOfRange(port))
                }
                portSet.insert(port)
            }
        }
        
        return .success(portSet.sorted())
    }
    
    /// Ước tính thời gian quét dựa trên số cổng, mức độ đồng thời và timeout
    public static func estimateScanDuration(
        portCount: Int,
        concurrency: Int = 200,
        averageTimeoutSeconds: Double = 0.8
    ) -> (estimatedSeconds: Double, displayString: String) {
        guard portCount > 0, concurrency > 0 else {
            return (0.0, "0s")
        }
        
        // Công thức: (số cổng / số luồng đồng thời) * thời gian phản hồi trung bình + độ trễ hàng đợi
        let batches = ceil(Double(portCount) / Double(concurrency))
        let seconds = batches * (averageTimeoutSeconds * 0.75) // Giả định ~25% cổng phản hồi ngay
        
        if seconds < 60 {
            return (seconds, String(format: "~%.0f giây", max(1, seconds)))
        } else {
            let mins = seconds / 60.0
            return (seconds, String(format: "~%.1f phút", mins))
        }
    }
}
