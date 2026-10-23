//
//  ICMPChecksumTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class ICMPChecksumTests: XCTestCase {
    
    /// Tính toán RFC 1071 Checksum
    private func calculateChecksum(_ data: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        let count = data.count
        while i < count - 1 {
            let word = (UInt32(data[i]) << 8) | UInt32(data[i + 1])
            sum += word
            i += 2
        }
        if i < count {
            sum += (UInt32(data[i]) << 8)
        }
        while (sum >> 16) > 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(sum & 0xFFFF)
    }
    
    func testEvenLengthICMPChecksum() {
        // Gói ICMP Echo Request 8 bytes: Type 8, Code 0, Checksum placeholder (0x0000), ID 0x1234, Seq 0x0001
        var packet: [UInt8] = [
            0x08, 0x00, 0x00, 0x00, 0x12, 0x34, 0x00, 0x01
        ]
        
        let checksum = calculateChecksum(packet)
        XCTAssertNotEqual(checksum, 0)
        
        // Gắn checksum vào packet tại offset 2, 3
        packet[2] = UInt8((checksum >> 8) & 0xFF)
        packet[3] = UInt8(checksum & 0xFF)
        
        // Tính lại checksum trên toàn bộ gói: theo RFC 1071 tổng phải bằng 0x0000 (hoặc 16-bit invert = 0)
        let verify = calculateChecksum(packet)
        XCTAssertEqual(verify, 0x0000)
    }
    
    func testOddLengthICMPPayloadChecksum() {
        // Gói tin với độ dài lẻ (9 bytes)
        var packet: [UInt8] = [
            0x08, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x41
        ]
        
        let checksum = calculateChecksum(packet)
        XCTAssertNotEqual(checksum, 0)
        
        packet[2] = UInt8((checksum >> 8) & 0xFF)
        packet[3] = UInt8(checksum & 0xFF)
        
        let verify = calculateChecksum(packet)
        XCTAssertEqual(verify, 0x0000)
    }
    
    func testEmptyDataChecksum() {
        let empty: [UInt8] = []
        XCTAssertEqual(calculateChecksum(empty), 0xFFFF)
    }
}
