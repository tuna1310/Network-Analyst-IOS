//
//  TracerouteParser.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Phân loại loại gói tin ICMP trong phản hồi Traceroute
public enum TracerouteICMPType: Int, Sendable, Equatable {
    case echoReply = 0               // Đã tới đích (Echo Reply)
    case destinationUnreachable = 3  // Đích không tới được / Cổng đóng
    case timeExceeded = 11           // TTL hết hạn tại router trung gian (Hop)
    case other = -1
    
    public static func fromCode(_ code: UInt8) -> TracerouteICMPType {
        switch code {
        case 0: return .echoReply
        case 3: return .destinationUnreachable
        case 11: return .timeExceeded
        default: return .other
        }
    }
}

/// Dữ liệu gói tin phản hồi Traceroute đã được giải mã
public struct ParsedTraceroutePacket: Sendable, Equatable {
    public let icmpType: TracerouteICMPType
    public let icmpCode: Int
    public let routerIP: String
    public let originalSequence: UInt16?
    public let originalIdentifier: UInt16?
    public let isDestinationReached: Bool
    public let isTTLHopResponse: Bool
    
    public init(
        icmpType: TracerouteICMPType,
        icmpCode: Int,
        routerIP: String,
        originalSequence: UInt16? = nil,
        originalIdentifier: UInt16? = nil,
        isDestinationReached: Bool = false,
        isTTLHopResponse: Bool = false
    ) {
        self.icmpType = icmpType
        self.icmpCode = icmpCode
        self.routerIP = routerIP
        self.originalSequence = originalSequence
        self.originalIdentifier = originalIdentifier
        self.isDestinationReached = isDestinationReached
        self.isTTLHopResponse = isTTLHopResponse
    }
}

/// Bộ phân tích dữ liệu byte thô của phản hồi Traceroute theo RFC 792
public enum TracerouteParser {
    
    /// Phân tích mảng byte nhận được từ socket mạng
    public static func parse(bytes: [UInt8], senderIP: String) -> ParsedTraceroutePacket? {
        guard !bytes.isEmpty else { return nil }
        
        // Kiểm tra xem kernel có kèm theo IP Header ngoài cùng hay không (IPv4 Version 4)
        var offset = 0
        if bytes.count >= 20 && (bytes[0] >> 4) == 4 {
            let ihl = Int(bytes[0] & 0x0F) * 4
            offset = ihl
        }
        
        guard bytes.count >= offset + 8 else { return nil }
        
        let typeVal = bytes[offset]
        let codeVal = Int(bytes[offset + 1])
        let icmpType = TracerouteICMPType.fromCode(typeVal)
        
        switch icmpType {
        case .timeExceeded:
            // Type 11 Code 0: TTL exceeded in transit (Router trung gian phản hồi)
            // Cấu trúc Type 11:
            // [Type: 1B][Code: 1B][Checksum: 2B][Unused: 4B]
            // Tiếp theo là IP Header của gói tin gốc (thường 20B)
            // Tiếp theo là 8B đầu tiên của payload gói tin gốc (chứa ICMP id + sequence)
            var originalSeq: UInt16? = nil
            var originalId: UInt16? = nil
            
            let payloadOffset = offset + 8
            if bytes.count >= payloadOffset + 20 + 8 {
                let innerIHL = Int(bytes[payloadOffset] & 0x0F) * 4
                let originalHeaderOffset = payloadOffset + innerIHL
                if bytes.count >= originalHeaderOffset + 8 {
                    // 2 bytes Identifier (offset + 4), 2 bytes Sequence (offset + 6) của gói ICMP gốc
                    originalId = (UInt16(bytes[originalHeaderOffset + 4]) << 8) | UInt16(bytes[originalHeaderOffset + 5])
                    originalSeq = (UInt16(bytes[originalHeaderOffset + 6]) << 8) | UInt16(bytes[originalHeaderOffset + 7])
                }
            }
            
            return ParsedTraceroutePacket(
                icmpType: .timeExceeded,
                icmpCode: codeVal,
                routerIP: senderIP,
                originalSequence: originalSeq,
                originalIdentifier: originalId,
                isDestinationReached: false,
                isTTLHopResponse: true
            )
            
        case .echoReply:
            // Type 0 Code 0: Đã tới máy chủ đích
            let seq = (UInt16(bytes[offset + 6]) << 8) | UInt16(bytes[offset + 7])
            let idVal = (UInt16(bytes[offset + 4]) << 8) | UInt16(bytes[offset + 5])
            
            return ParsedTraceroutePacket(
                icmpType: .echoReply,
                icmpCode: codeVal,
                routerIP: senderIP,
                originalSequence: seq,
                originalIdentifier: idVal,
                isDestinationReached: true,
                isTTLHopResponse: false
            )
            
        case .destinationUnreachable:
            return ParsedTraceroutePacket(
                icmpType: .destinationUnreachable,
                icmpCode: codeVal,
                routerIP: senderIP,
                isDestinationReached: true,
                isTTLHopResponse: false
            )
            
        case .other:
            return ParsedTraceroutePacket(
                icmpType: .other,
                icmpCode: codeVal,
                routerIP: senderIP,
                isDestinationReached: false,
                isTTLHopResponse: false
            )
        }
    }
}
