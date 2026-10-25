//
//  DNSCodecTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class DNSCodecTests: XCTestCase {
    
    // MARK: - Query Builder Tests
    func testBuildQueryWithEDNS0() {
        let domain = "example.com"
        let queryData = DNSCodec.buildQuery(domain: domain, type: .A, transactionId: 0x1234, useEDNS0: true)
        let bytes = [UInt8](queryData)
        
        // Header kiểm tra: ID = 0x1234, Flags = 0x0100 (RD=1), QDCOUNT=1, ANCOUNT=0, NSCOUNT=0, ARCOUNT=1 (EDNS0)
        XCTAssertEqual(bytes[0], 0x12)
        XCTAssertEqual(bytes[1], 0x34)
        XCTAssertEqual(bytes[2], 0x01)
        XCTAssertEqual(bytes[3], 0x00)
        XCTAssertEqual(bytes[4], 0x00)
        XCTAssertEqual(bytes[5], 0x01) // QDCOUNT = 1
        XCTAssertEqual(bytes[10], 0x00)
        XCTAssertEqual(bytes[11], 0x01) // ARCOUNT = 1 (OPT RR)
        
        // Kiểm tra QNAME "example" (7) "com" (3) (0)
        XCTAssertEqual(bytes[12], 7)
        let exampleStr = String(decoding: Array(bytes[13..<20]), as: UTF8.self)
        XCTAssertEqual(exampleStr, "example")
        XCTAssertEqual(bytes[20], 3)
        let comStr = String(decoding: Array(bytes[21..<24]), as: UTF8.self)
        XCTAssertEqual(comStr, "com")
        XCTAssertEqual(bytes[24], 0) // Root
    }
    
    // MARK: - Pointer Compression 0xC0 Tests
    func testReadDomainNameWithStandardPointer() throws {
        // Gói giả lập:
        // Offset 0: nhãn "example" (7), "com" (3), root (0)
        // Offset 13: con trỏ 0xC0 0x00 (trỏ về offset 0)
        let packet: [UInt8] = [
            7, 0x65, 0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, // "example"
            3, 0x63, 0x6f, 0x6d, 0,                      // "com", 0
            0xC0, 0x00                                   // Pointer -> offset 0
        ]
        
        var offset = 13
        let resolved = try DNSCodec.readDomainName(from: packet, offset: &offset)
        XCTAssertEqual(resolved, "example.com")
        XCTAssertEqual(offset, 15) // Sau con trỏ 2 bytes
    }
    
    func testNestedPointers() throws {
        // Offset 0: "com", 0
        // Offset 5: "example", con trỏ trỏ về offset 0 (0xC0 0x00) -> "example.com"
        // Offset 15: "www", con trỏ trỏ về offset 5 (0xC0 0x05) -> "www.example.com"
        let packet: [UInt8] = [
            3, 0x63, 0x6f, 0x6d, 0,                                   // offset 0..4
            7, 0x65, 0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, 0xC0, 0x00, // offset 5..14
            3, 0x77, 0x77, 0x77, 0xC0, 0x05                           // offset 15..20
        ]
        
        var offset = 15
        let resolved = try DNSCodec.readDomainName(from: packet, offset: &offset)
        XCTAssertEqual(resolved, "www.example.com")
    }
    
    // MARK: - Security: Malicious Compression Loop
    func testCompressionLoopDetectedWithoutHanging() {
        // Offset 0: con trỏ trỏ tới offset 2 (0xC0 0x02)
        // Offset 2: con trỏ trỏ ngược lại offset 0 (0xC0 0x00) -> Vòng lặp độc hại
        let loopPacket: [UInt8] = [
            0xC0, 0x02,
            0xC0, 0x00
        ]
        
        var offset = 0
        XCTAssertThrowsError(try DNSCodec.readDomainName(from: loopPacket, offset: &offset)) { error in
            XCTAssertEqual(error as? DNSError, DNSError.compressionLoopDetected)
        }
    }
    
    func testPointerOutOfBoundsThrows() {
        // Con trỏ trỏ tới offset 100 vượt ngoài mảng 2 bytes
        let badPacket: [UInt8] = [0xC0, 100]
        var offset = 0
        XCTAssertThrowsError(try DNSCodec.readDomainName(from: badPacket, offset: &offset)) { error in
            XCTAssertEqual(error as? DNSError, DNSError.pointerOutOfBounds)
        }
    }
    
    func testTruncatedPacketThrows() {
        let shortPacket: [UInt8] = [0x01, 0x02, 0x03]
        XCTAssertThrowsError(try DNSCodec.parseResponse(bytes: shortPacket)) { error in
            XCTAssertEqual(error as? DNSError, DNSError.packetTooShort)
        }
    }
    
    // MARK: - HTTPS / SVCB Record Parsing Test (RFC 9460)
    func testParseHTTPSRecordFixtureSynthetic() throws {
        // Gói DNS Answer hoàn chỉnh giả lập cho bản ghi HTTPS (type 65):
        // SvcPriority = 1, TargetName = "." (rễ)
        // SvcParams: alpn="h2,h3", port=443, ipv4hint=1.2.3.4
        var packet: [UInt8] = [
            // Header (12 bytes)
            0x12, 0x34, // ID
            0x81, 0x80, // Response, RD, RA
            0x00, 0x00, // QDCOUNT = 0
            0x00, 0x01, // ANCOUNT = 1
            0x00, 0x00, // NSCOUNT = 0
            0x00, 0x00, // ARCOUNT = 0
            
            // Answer: NAME = "example.com"
            7, 0x65, 0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, 3, 0x63, 0x6f, 0x6d, 0,
            0x00, 65,         // TYPE = HTTPS (65)
            0x00, 0x01,       // CLASS = IN (1)
            0x00, 0x00, 0x01, 0x2C, // TTL = 300s
            0x00, 23          // RDLENGTH = 23 bytes
        ]
        
        let rdataStart = packet.count
        
        // RDATA:
        // Priority = 1 (2 bytes)
        packet.append(contentsOf: [0x00, 0x01])
        // TargetName = "." (1 byte: 0x00)
        packet.append(0x00)
        // Param 1: ALPN (key 1, len 6: len 2 "h2", len 2 "h3")
        packet.append(contentsOf: [0x00, 0x01, 0x00, 0x06, 0x02, 0x68, 0x32, 0x02, 0x68, 0x33])
        // Param 2: Port (key 3, len 2: 443 = 0x01BB)
        packet.append(contentsOf: [0x00, 0x03, 0x00, 0x02, 0x01, 0xBB])
        // Param 3: IPv4hint (key 4, len 4: 1.2.3.4)
        packet.append(contentsOf: [0x00, 0x04, 0x00, 0x04, 0x01, 0x02, 0x03, 0x04])
        
        // Sửa lại đúng RDLENGTH thực tế
        let rdataLen = packet.count - rdataStart
        packet[rdataStart - 2] = UInt8(rdataLen >> 8)
        packet[rdataStart - 1] = UInt8(rdataLen & 0xFF)
        
        let (header, answers) = try DNSCodec.parseResponse(bytes: packet)
        XCTAssertEqual(header.anCount, 1)
        XCTAssertFalse(header.isTruncated)
        XCTAssertEqual(answers.count, 1)
        
        let rec = answers[0]
        XCTAssertEqual(rec.type, .HTTPS)
        XCTAssertEqual(rec.ttl, 300)
        XCTAssertEqual(rec.priority, 1)
        
        // Kiểm tra giá trị giải mã hiển thị SvcParams
        XCTAssertTrue(rec.displayValue.contains("1 ."))
        XCTAssertTrue(rec.displayValue.contains("alpn=h2,h3"))
        XCTAssertTrue(rec.displayValue.contains("port=443"))
        XCTAssertTrue(rec.displayValue.contains("ipv4hint=1.2.3.4"))
    }
}
