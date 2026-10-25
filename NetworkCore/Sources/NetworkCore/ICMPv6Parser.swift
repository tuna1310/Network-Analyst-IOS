//
//  ICMPv6Parser.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Phân loại loại thông điệp ICMPv6 theo RFC 4443
public enum ICMPv6Type: Int, Sendable, Equatable, Codable {
    case destinationUnreachable = 1
    case packetTooBig = 2
    case timeExceeded = 3
    case parameterProblem = 4
    case echoRequest = 128
    case echoReply = 129
    case other = -1
    
    public static func fromCode(_ code: UInt8) -> ICMPv6Type {
        switch code {
        case 1: return .destinationUnreachable
        case 2: return .packetTooBig
        case 3: return .timeExceeded
        case 4: return .parameterProblem
        case 128: return .echoRequest
        case 129: return .echoReply
        default: return .other
        }
    }
    
    public var description: String {
        switch self {
        case .destinationUnreachable: return "Đích không tới được (Destination Unreachable)"
        case .packetTooBig: return "Gói tin quá lớn (Packet Too Big)"
        case .timeExceeded: return "Hết thời gian / Hop Limit (Time Exceeded)"
        case .parameterProblem: return "Lỗi tham số gói tin (Parameter Problem)"
        case .echoRequest: return "Yêu cầu phản hồi (Echo Request)"
        case .echoReply: return "Phản hồi Echo (Echo Reply)"
        case .other: return "Thông điệp khác"
        }
    }
}

/// Mã chi tiết ICMPv6 theo RFC 4443
public enum ICMPv6CodeExplanation {
    public static func explain(type: ICMPv6Type, code: UInt8) -> String {
        switch type {
        case .destinationUnreachable:
            switch code {
            case 0: return "Không có tuyến đường tới đích (No route to destination)"
            case 1: return "Bị chặn bởi chính sách quản trị (Administratively prohibited)"
            case 2: return "Vượt quá phạm vi địa chỉ nguồn (Beyond scope of source address)"
            case 3: return "Địa chỉ không tới được (Address unreachable)"
            case 4: return "Cổng dịch vụ không khả dụng (Port unreachable)"
            default: return "Lỗi không tới được (Mã \(code))"
            }
        case .timeExceeded:
            switch code {
            case 0: return "Vượt quá giới hạn số bước chuyển tiếp (Hop limit exceeded in transit)"
            case 1: return "Hết thời gian ghép mảnh gói tin (Fragment reassembly time exceeded)"
            default: return "Hết thời gian (Mã \(code))"
            }
        default:
            return "Mã \(code)"
        }
    }
}

/// Dữ liệu gói tin phản hồi ICMPv6 đã giải mã
public struct ParsedICMPv6Packet: Sendable, Equatable {
    public let type: ICMPv6Type
    public let rawTypeCode: UInt8
    public let code: UInt8
    public let explanation: String
    public let senderIP: String
    public let identifier: UInt16?
    public let sequence: UInt16?
    public let isDestinationReached: Bool
    public let isHopLimitExceeded: Bool
    
    public init(
        type: ICMPv6Type,
        rawTypeCode: UInt8,
        code: UInt8,
        explanation: String,
        senderIP: String,
        identifier: UInt16? = nil,
        sequence: UInt16? = nil,
        isDestinationReached: Bool = false,
        isHopLimitExceeded: Bool = false
    ) {
        self.type = type
        self.rawTypeCode = rawTypeCode
        self.code = code
        self.explanation = explanation
        self.senderIP = senderIP
        self.identifier = identifier
        self.sequence = sequence
        self.isDestinationReached = isDestinationReached
        self.isHopLimitExceeded = isHopLimitExceeded
    }
}

/// Bộ phân tích và đóng gói gói tin ICMPv6 (RFC 4443)
public enum ICMPv6Codec {
    
    /// Xây dựng gói tin ICMPv6 Echo Request (Type 128, Code 0)
    /// LƯU Ý VỀ ICMPv6 CHECKSUM TRÊN DARWIN/IOS:
    /// Trên lý thuyết nhân Darwin có thể tự tính toán checksum cho unprivileged datagram ICMPv6 socket,
    /// nhưng hành vi này chưa chắc chắn trên các thiết bị iPhone thương mại và bắt buộc phải kiểm chứng trên iPhone thật.
    /// Hàm này mặc định để 2 byte checksum là 0x0000, đồng thời hỗ trợ cờ tính toán RFC 4443 pseudo-header checksum nếu cần.
    public static func buildEchoRequest(
        identifier: UInt16,
        sequence: UInt16,
        payloadSize: Int = 32,
        calculateChecksum: Bool = false,
        sourceIPv6: String? = nil,
        destIPv6: String? = nil
    ) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: 8 + payloadSize)
        packet[0] = 128 // Type: Echo Request
        packet[1] = 0   // Code: 0
        packet[2] = 0   // Checksum byte 1
        packet[3] = 0   // Checksum byte 2
        
        // Identifier (bytes 4-5)
        packet[4] = UInt8((identifier >> 8) & 0xFF)
        packet[5] = UInt8(identifier & 0xFF)
        
        // Sequence (bytes 6-7)
        packet[6] = UInt8((sequence >> 8) & 0xFF)
        packet[7] = UInt8(sequence & 0xFF)
        
        // Payload: Ghi timestamp microsecond hoặc pattern kiểm thử
        let nowMicros = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        withUnsafeBytes(of: nowMicros.bigEndian) { rawBytes in
            for i in 0..<min(8, payloadSize) {
                packet[8 + i] = rawBytes[i]
            }
        }
        
        for i in 8..<payloadSize {
            packet[8 + i] = UInt8((i + 65) % 256)
        }
        
        // Tùy chọn tính toán Checksum theo RFC 4443 nếu kernel không tự tính
        if calculateChecksum, let src = sourceIPv6, let dst = destIPv6 {
            let cs = computeICMPv6Checksum(sourceIPv6: src, destinationIPv6: dst, icmpPacket: packet)
            packet[2] = UInt8((cs >> 8) & 0xFF)
            packet[3] = UInt8(cs & 0xFF)
        }
        
        return packet
    }
    
    /// Tính toán Checksum ICMPv6 kèm IPv6 Pseudo-Header (RFC 4443 / RFC 2460)
    public static func computeICMPv6Checksum(
        sourceIPv6: String,
        destinationIPv6: String,
        icmpPacket: [UInt8]
    ) -> UInt16 {
        var srcSin6 = sockaddr_in6()
        var dstSin6 = sockaddr_in6()
        guard inet_pton(AF_INET6, sourceIPv6, &srcSin6.sin6_addr) == 1,
              inet_pton(AF_INET6, destinationIPv6, &dstSin6.sin6_addr) == 1 else {
            return 0
        }
        
        var pseudoHeader = [UInt8]()
        pseudoHeader.reserveCapacity(40 + icmpPacket.count)
        
        // 16 bytes Source IPv6
        withUnsafeBytes(of: srcSin6.sin6_addr) { buffer in
            pseudoHeader.append(contentsOf: buffer)
        }
        // 16 bytes Destination IPv6
        withUnsafeBytes(of: dstSin6.sin6_addr) { buffer in
            pseudoHeader.append(contentsOf: buffer)
        }
        // 4 bytes Upper-Layer Packet Length (32-bit big endian)
        let length = UInt32(icmpPacket.count).bigEndian
        withUnsafeBytes(of: length) { buffer in
            pseudoHeader.append(contentsOf: buffer)
        }
        // 3 bytes zeros + 1 byte Next Header (58 = ICMPv6)
        pseudoHeader.append(contentsOf: [0, 0, 0, 58])
        
        // Ghép toàn bộ ICMP packet với checksum = 0
        var packetZeroChecksum = icmpPacket
        if packetZeroChecksum.count >= 4 {
            packetZeroChecksum[2] = 0
            packetZeroChecksum[3] = 0
        }
        pseudoHeader.append(contentsOf: packetZeroChecksum)
        
        return InternetChecksum.compute(pseudoHeader)
    }
    
    /// Phân giải phản hồi byte nhận được từ socket ICMPv6
    public static func parseResponse(bytes: [UInt8], senderIP: String) -> ParsedICMPv6Packet? {
        guard bytes.count >= 8 else { return nil }
        
        let rawType = bytes[0]
        let code = bytes[1]
        let icmpType = ICMPv6Type.fromCode(rawType)
        let explanation = ICMPv6CodeExplanation.explain(type: icmpType, code: code)
        
        switch icmpType {
        case .echoReply:
            // Type 129: Echo Reply [Type:1B][Code:1B][Checksum:2B][ID:2B][Seq:2B]
            let id = (UInt16(bytes[4]) << 8) | UInt16(bytes[5])
            let seq = (UInt16(bytes[6]) << 8) | UInt16(bytes[7])
            return ParsedICMPv6Packet(
                type: .echoReply,
                rawTypeCode: rawType,
                code: code,
                explanation: explanation,
                senderIP: senderIP,
                identifier: id,
                sequence: seq,
                isDestinationReached: true,
                isHopLimitExceeded: false
            )
            
        case .timeExceeded:
            // Type 3: Time Exceeded (Code 0: Hop limit exceeded in transit)
            // Cấu trúc Type 3 RFC 4443:
            // [Type: 1B][Code: 1B][Checksum: 2B][Unused: 4B]
            // Tiếp theo là gói tin IPv6 gốc (IPv6 Header 40B + payload ICMPv6 gốc)
            var originalId: UInt16? = nil
            var originalSeq: UInt16? = nil
            
            let headerOffset = 8
            if bytes.count >= headerOffset + 40 + 8 {
                // Kiểm tra Next Header tại offset 6 của IPv6 header gốc
                let nextHeader = bytes[headerOffset + 6]
                if nextHeader == 58 { // 58 = IPPROTO_ICMPV6
                    let invokingIcmpOffset = headerOffset + 40
                    originalId = (UInt16(bytes[invokingIcmpOffset + 4]) << 8) | UInt16(bytes[invokingIcmpOffset + 5])
                    originalSeq = (UInt16(bytes[invokingIcmpOffset + 6]) << 8) | UInt16(bytes[invokingIcmpOffset + 7])
                }
            }
            
            return ParsedICMPv6Packet(
                type: .timeExceeded,
                rawTypeCode: rawType,
                code: code,
                explanation: explanation,
                senderIP: senderIP,
                identifier: originalId,
                sequence: originalSeq,
                isDestinationReached: false,
                isHopLimitExceeded: (code == 0)
            )
            
        case .destinationUnreachable:
            var originalId: UInt16? = nil
            var originalSeq: UInt16? = nil
            
            let headerOffset = 8
            if bytes.count >= headerOffset + 40 + 8 {
                let nextHeader = bytes[headerOffset + 6]
                if nextHeader == 58 {
                    let invokingIcmpOffset = headerOffset + 40
                    originalId = (UInt16(bytes[invokingIcmpOffset + 4]) << 8) | UInt16(bytes[invokingIcmpOffset + 5])
                    originalSeq = (UInt16(bytes[invokingIcmpOffset + 6]) << 8) | UInt16(bytes[invokingIcmpOffset + 7])
                }
            }
            
            return ParsedICMPv6Packet(
                type: .destinationUnreachable,
                rawTypeCode: rawType,
                code: code,
                explanation: explanation,
                senderIP: senderIP,
                identifier: originalId,
                sequence: originalSeq,
                isDestinationReached: false,
                isHopLimitExceeded: false
            )
            
        default:
            return ParsedICMPv6Packet(
                type: icmpType,
                rawTypeCode: rawType,
                code: code,
                explanation: explanation,
                senderIP: senderIP,
                identifier: nil,
                sequence: nil,
                isDestinationReached: false,
                isHopLimitExceeded: false
            )
        }
    }
}
