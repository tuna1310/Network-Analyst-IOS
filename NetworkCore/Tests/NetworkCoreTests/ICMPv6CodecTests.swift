//
//  ICMPv6CodecTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class ICMPv6CodecTests: XCTestCase {
    
    // MARK: - Test 1: Build Echo Request (Type 128)
    func testBuildEchoRequest() {
        let req = ICMPv6Codec.buildEchoRequest(identifier: 0x1234, sequence: 0x0005, payloadSize: 16)
        
        // 8 bytes header + 16 bytes payload = 24 bytes
        XCTAssertEqual(req.count, 24)
        XCTAssertEqual(req[0], 128) // Type: Echo Request
        XCTAssertEqual(req[1], 0)   // Code: 0
        XCTAssertEqual(req[2], 0)   // Checksum byte 1 must be 0 for Darwin
        XCTAssertEqual(req[3], 0)   // Checksum byte 2 must be 0 for Darwin
        XCTAssertEqual(req[4], 0x12) // Identifier high
        XCTAssertEqual(req[5], 0x34) // Identifier low
        XCTAssertEqual(req[6], 0x00) // Sequence high
        XCTAssertEqual(req[7], 0x05) // Sequence low
    }
    
    // MARK: - Test 2: Parse Echo Reply (Type 129)
    func testParseEchoReply() {
        var replyBytes: [UInt8] = [
            129, // Type Echo Reply
            0,   // Code
            0xAB, 0xCD, // Checksum
            0x12, 0x34, // Identifier
            0x00, 0x07  // Sequence
        ]
        replyBytes.append(contentsOf: [1, 2, 3, 4, 5, 6, 7, 8]) // Payload
        
        let parsed = ICMPv6Codec.parseResponse(bytes: replyBytes, senderIP: "2001:4860:4860::8888")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.type, .echoReply)
        XCTAssertEqual(parsed?.senderIP, "2001:4860:4860::8888")
        XCTAssertEqual(parsed?.identifier, 0x1234)
        XCTAssertEqual(parsed?.sequence, 0x0007)
        XCTAssertTrue(parsed?.isDestinationReached == true)
        XCTAssertFalse(parsed?.isHopLimitExceeded == true)
    }
    
    // MARK: - Test 3: Parse Time Exceeded (Type 3, Code 0)
    func testParseTimeExceeded() {
        var teBytes: [UInt8] = [
            3,  // Type Time Exceeded
            0,  // Code 0: Hop limit exceeded in transit
            0x11, 0x22, // Checksum
            0, 0, 0, 0  // 4 unused bytes
        ]
        
        // 40 bytes IPv6 Header:
        // Version 6 + Traffic class + Flow label (4B)
        // Payload length (2B)
        // Next Header: 58 (ICMPv6) (1B) at index 6
        // Hop limit (1B)
        // Source IPv6 (16B)
        // Dest IPv6 (16B)
        var ipv6Header = [UInt8](repeating: 0, count: 40)
        ipv6Header[0] = 0x60 // Version 6
        ipv6Header[6] = 58   // Next Header = 58 (ICMPv6)
        teBytes.append(contentsOf: ipv6Header)
        
        // Original ICMPv6 Echo Request Header:
        // Type 128 (1B), Code 0 (1B), Checksum 0 (2B), ID 0x5566 (2B), Seq 0x0009 (2B)
        let origIcmp: [UInt8] = [128, 0, 0, 0, 0x55, 0x66, 0x00, 0x09]
        teBytes.append(contentsOf: origIcmp)
        
        let parsed = ICMPv6Codec.parseResponse(bytes: teBytes, senderIP: "2404:6800:4005:809::200e")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.type, .timeExceeded)
        XCTAssertEqual(parsed?.code, 0)
        XCTAssertTrue(parsed?.isHopLimitExceeded == true)
        XCTAssertFalse(parsed?.isDestinationReached == true)
        XCTAssertEqual(parsed?.identifier, 0x5566)
        XCTAssertEqual(parsed?.sequence, 0x0009)
        XCTAssertTrue(parsed?.explanation.contains("Hop limit") == true)
    }
    
    // MARK: - Test 4: Parse Destination Unreachable (Type 1, Code 3)
    func testParseDestinationUnreachable() {
        let unreachBytes: [UInt8] = [
            1,  // Type Destination Unreachable
            3,  // Code 3: Address unreachable
            0x33, 0x44, // Checksum
            0, 0, 0, 0  // Unused
        ]
        
        let parsed = ICMPv6Codec.parseResponse(bytes: unreachBytes, senderIP: "fe80::1")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.type, .destinationUnreachable)
        XCTAssertEqual(parsed?.code, 3)
        XCTAssertFalse(parsed?.isDestinationReached == true)
        XCTAssertTrue(parsed?.explanation.contains("Address unreachable") == true)
    }
    
    // MARK: - Test 5: Truncated or Empty packet
    func testTruncatedPacket() {
        XCTAssertNil(ICMPv6Codec.parseResponse(bytes: [], senderIP: "::1"))
        XCTAssertNil(ICMPv6Codec.parseResponse(bytes: [129, 0, 0], senderIP: "::1"))
    }
    
    // MARK: - Test 6: Compute ICMPv6 Pseudo-Header Checksum
    func testComputeICMPv6Checksum() {
        let src = "fe80::1"
        let dst = "fe80::2"
        let packet = ICMPv6Codec.buildEchoRequest(
            identifier: 0x1234,
            sequence: 0x0001,
            payloadSize: 16,
            calculateChecksum: true,
            sourceIPv6: src,
            destIPv6: dst
        )
        
        let checksum = (UInt16(packet[2]) << 8) | UInt16(packet[3])
        XCTAssertNotEqual(checksum, 0)
    }
}
