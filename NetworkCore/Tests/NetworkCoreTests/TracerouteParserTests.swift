//
//  TracerouteParserTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class TracerouteParserTests: XCTestCase {
    
    func testParseEchoReplyPacket() {
        // ICMP Echo Reply (Type 0, Code 0, Checksum, ID: 0x1234, Sequence: 0x0005)
        let packet: [UInt8] = [
            0x00, 0x00,             // Type: 0 (Echo Reply), Code: 0
            0xFF, 0xFF,             // Checksum
            0x12, 0x34,             // Identifier: 0x1234
            0x00, 0x05,             // Sequence: 5
            0x41, 0x42, 0x43, 0x44  // Payload 'ABCD'
        ]
        
        let parsed = TracerouteParser.parse(bytes: packet, senderIP: "8.8.8.8")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.icmpType, .echoReply)
        XCTAssertEqual(parsed?.routerIP, "8.8.8.8")
        XCTAssertEqual(parsed?.isDestinationReached, true)
        XCTAssertEqual(parsed?.isTTLHopResponse, false)
        XCTAssertEqual(parsed?.originalSequence, 5)
        XCTAssertEqual(parsed?.originalIdentifier, 0x1234)
    }
    
    func testParseTimeExceededHopPacket() {
        // ICMP Time Exceeded (Type 11, Code 0)
        // Header: [Type: 11, Code: 0, Checksum: 2B, Unused: 4B]
        var packet: [UInt8] = [
            0x0B, 0x00,             // Type: 11 (Time Exceeded), Code: 0
            0x00, 0x00,             // Checksum
            0x00, 0x00, 0x00, 0x00  // Unused 4 bytes
        ]
        
        // Inner IPv4 Header (20 bytes: 0x45, ...)
        let innerIP: [UInt8] = [
            0x45, 0x00, 0x00, 0x3c, 0x1c, 0x46, 0x40, 0x00,
            0x01, 0x01, 0x00, 0x00, 0xc0, 0xa8, 0x01, 0x64, // 192.168.1.100
            0x08, 0x08, 0x08, 0x08                          // 8.8.8.8
        ]
        packet.append(contentsOf: innerIP)
        
        // Inner ICMP Echo Request (first 8 bytes: Type 8, Code 0, Checksum, ID: 0x5678, Seq: 0x0003)
        let innerICMP: [UInt8] = [
            0x08, 0x00,             // Type: 8 (Echo Request), Code: 0
            0x00, 0x00,             // Checksum
            0x56, 0x78,             // Identifier: 0x5678
            0x00, 0x03              // Sequence: 3
        ]
        packet.append(contentsOf: innerICMP)
        
        let parsed = TracerouteParser.parse(bytes: packet, senderIP: "10.0.0.1")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.icmpType, .timeExceeded)
        XCTAssertEqual(parsed?.routerIP, "10.0.0.1")
        XCTAssertEqual(parsed?.isTTLHopResponse, true)
        XCTAssertEqual(parsed?.isDestinationReached, false)
        XCTAssertEqual(parsed?.originalIdentifier, 0x5678)
        XCTAssertEqual(parsed?.originalSequence, 3)
    }
    
    func testParseDestinationUnreachablePacket() {
        // ICMP Destination Unreachable (Type 3, Code 3: Port Unreachable)
        let packet: [UInt8] = [
            0x03, 0x03,             // Type: 3, Code: 3
            0x00, 0x00,             // Checksum
            0x00, 0x00, 0x00, 0x00  // Unused
        ]
        
        let parsed = TracerouteParser.parse(bytes: packet, senderIP: "1.1.1.1")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.icmpType, .destinationUnreachable)
        XCTAssertEqual(parsed?.routerIP, "1.1.1.1")
        XCTAssertEqual(parsed?.isDestinationReached, true)
        XCTAssertEqual(parsed?.isTTLHopResponse, false)
    }
    
    func testTruncatedPacketReturnsNil() {
        let shortPacket: [UInt8] = [0x08, 0x00, 0x00]
        XCTAssertNil(TracerouteParser.parse(bytes: shortPacket, senderIP: "1.1.1.1"))
    }
}
