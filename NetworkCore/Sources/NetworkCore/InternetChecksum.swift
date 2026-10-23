//
//  InternetChecksum.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Chuẩn tính toán RFC 1071 Internet Checksum cho các giao thức ICMP, IP, UDP, TCP
public enum InternetChecksum {
    /// Tính toán bù 1 (One's complement sum) của các từ 16-bit theo RFC 1071
    public static func compute(_ data: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        let count = data.count
        
        while i < count - 1 {
            let word = (UInt32(data[i]) << 8) | UInt32(data[i + 1])
            sum += word
            i += 2
        }
        
        // Nếu độ dài mảng byte là số lẻ, đệm 0 vào byte thấp
        if i < count {
            let word = UInt32(data[i]) << 8
            sum += word
        }
        
        // Gập các bit tràn (carry bits) vào 16-bit
        while (sum >> 16) != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        
        return ~UInt16(sum & 0xFFFF)
    }
}
