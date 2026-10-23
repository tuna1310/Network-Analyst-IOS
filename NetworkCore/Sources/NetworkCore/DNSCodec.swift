//
//  DNSCodec.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Lỗi giải mã và đóng gói gói tin DNS
public enum DNSError: Error, Equatable {
    case packetTooShort
    case compressionLoopDetected
    case pointerOutOfBounds
    case pointerDepthExceeded
    case invalidLabelLength
    case malformedRData
    case truncatedResponse
}

/// Các loại bản ghi DNS hỗ trợ
public enum DNSQueryType: UInt16, Sendable, CaseIterable, Identifiable {
    case A = 1
    case NS = 2
    case CNAME = 5
    case SOA = 6
    case PTR = 12
    case MX = 15
    case TXT = 16
    case AAAA = 28
    case SRV = 33
    case OPT = 41
    case SVCB = 64
    case HTTPS = 65
    case ANY = 255
    case CAA = 257
    
    public var id: UInt16 { rawValue }
    
    public var name: String {
        switch self {
        case .A: return "A"
        case .NS: return "NS"
        case .CNAME: return "CNAME"
        case .SOA: return "SOA"
        case .PTR: return "PTR"
        case .MX: return "MX"
        case .TXT: return "TXT"
        case .AAAA: return "AAAA"
        case .SRV: return "SRV"
        case .OPT: return "OPT"
        case .SVCB: return "SVCB"
        case .HTTPS: return "HTTPS"
        case .ANY: return "ANY"
        case .CAA: return "CAA"
        }
    }
}

/// Header gói tin DNS theo chuẩn RFC 1035
public struct DNSHeader: Sendable, Equatable {
    public let id: UInt16
    public let flags: UInt16
    public let qdCount: UInt16
    public let anCount: UInt16
    public let nsCount: UInt16
    public let arCount: UInt16
    
    public var isResponse: Bool { (flags & 0x8000) != 0 }
    public var isTruncated: Bool { (flags & 0x0200) != 0 } // Bit TC (Truncated)
    public var responseCode: UInt8 { UInt8(flags & 0x000F) } // RCODE
}

/// Bản ghi DNS đã được phân tích
public struct ParsedDNSRecord: Sendable, Equatable, Identifiable {
    public var id = UUID()
    public let name: String
    public let type: DNSQueryType
    public let dnsClass: UInt16
    public let ttl: UInt32
    public let displayValue: String
    public let priority: Int?
    
    public init(name: String, type: DNSQueryType, dnsClass: UInt16 = 1, ttl: UInt32, displayValue: String, priority: Int? = nil) {
        self.name = name
        self.type = type
        self.dnsClass = dnsClass
        self.ttl = ttl
        self.displayValue = displayValue
        self.priority = priority
    }
}

/// SvcParam của bản ghi SVCB / HTTPS (RFC 9460)
public struct ParsedSVCBParam: Sendable, Equatable {
    public let key: UInt16
    public let name: String
    public let value: String
}

/// Bộ đóng gói và giải mã nhị phân DNS Wire Format (RFC 1035, RFC 6891 EDNS0, RFC 9460 SVCB/HTTPS)
public enum DNSCodec {
    
    private static let maxPointerJumps = 16
    
    // MARK: - Build DNS Query
    /// Tạo gói tin truy vấn DNS nhị phân kèm EDNS0 (RFC 6891 OPT RR 4096 bytes)
    public static func buildQuery(
        domain: String,
        type: DNSQueryType,
        transactionId: UInt16 = UInt16.random(in: 1000...65000),
        useEDNS0: Bool = true
    ) -> Data {
        var data = Data()
        
        // 1. Header (12 bytes)
        // ID
        data.append(UInt8(transactionId >> 8))
        data.append(UInt8(transactionId & 0xFF))
        
        // Flags: Standard query, Recursion Desired (RD = 1 -> 0x0100)
        data.append(0x01)
        data.append(0x00)
        
        // QDCOUNT = 1
        data.append(0x00)
        data.append(0x01)
        
        // ANCOUNT = 0
        data.append(0x00)
        data.append(0x00)
        
        // NSCOUNT = 0
        data.append(0x00)
        data.append(0x00)
        
        // ARCOUNT = 1 (nếu bật EDNS0) hoặc 0
        data.append(0x00)
        data.append(useEDNS0 ? 0x01 : 0x00)
        
        // 2. Question Section
        let clean = domain.trimmingCharacters(in: CharacterSet(charactersIn: ". \t\r\n"))
        let labels = clean.split(separator: ".")
        for label in labels {
            let labelBytes = Array(label.utf8)
            data.append(UInt8(labelBytes.count))
            data.append(contentsOf: labelBytes)
        }
        data.append(0x00) // Root label
        
        // QTYPE
        data.append(UInt8(type.rawValue >> 8))
        data.append(UInt8(type.rawValue & 0xFF))
        
        // QCLASS = IN (1)
        data.append(0x00)
        data.append(0x01)
        
        // 3. EDNS0 OPT RR (RFC 6891) in Additional Section
        if useEDNS0 {
            data.append(0x00) // NAME = Root (.)
            data.append(0x00); data.append(41) // TYPE = OPT (41)
            data.append(0x10); data.append(0x00) // CLASS = 4096 (UDP payload size)
            data.append(0x00); data.append(0x00); data.append(0x00); data.append(0x00) // TTL = 0 (Extended RCODE + flags)
            data.append(0x00); data.append(0x00) // RDLENGTH = 0
        }
        
        return data
    }
    
    // MARK: - Parse DNS Response
    /// Phân tích phản hồi DNS nhị phân an toàn, chống lặp con trỏ nén và kiểm tra cờ Truncated (TC)
    public static func parseResponse(bytes: [UInt8]) throws -> (header: DNSHeader, answers: [ParsedDNSRecord]) {
        guard bytes.count >= 12 else {
            throw DNSError.packetTooShort
        }
        
        // 1. Header
        let id = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        let flags = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
        let qdCount = (UInt16(bytes[4]) << 8) | UInt16(bytes[5])
        let anCount = (UInt16(bytes[6]) << 8) | UInt16(bytes[7])
        let nsCount = (UInt16(bytes[8]) << 8) | UInt16(bytes[9])
        let arCount = (UInt16(bytes[10]) << 8) | UInt16(bytes[11])
        
        let header = DNSHeader(
            id: id,
            flags: flags,
            qdCount: qdCount,
            anCount: anCount,
            nsCount: nsCount,
            arCount: arCount
        )
        
        var offset = 12
        
        // 2. Bỏ qua Question Section
        for _ in 0..<qdCount {
            _ = try readDomainName(from: bytes, offset: &offset)
            guard offset + 4 <= bytes.count else { throw DNSError.packetTooShort }
            offset += 4 // QTYPE (2) + QCLASS (2)
        }
        
        // 3. Đọc Answer Section
        var answers: [ParsedDNSRecord] = []
        for _ in 0..<anCount {
            guard offset < bytes.count else { break }
            let name = try readDomainName(from: bytes, offset: &offset)
            
            guard offset + 10 <= bytes.count else { throw DNSError.packetTooShort }
            let typeCode = (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
            let dnsClass = (UInt16(bytes[offset + 2]) << 8) | UInt16(bytes[offset + 3])
            let ttl = (UInt32(bytes[offset + 4]) << 24) | (UInt32(bytes[offset + 5]) << 16) | (UInt32(bytes[offset + 6]) << 8) | UInt32(bytes[offset + 7])
            let rdLength = Int((UInt16(bytes[offset + 8]) << 8) | UInt16(bytes[offset + 9]))
            offset += 10
            
            guard offset + rdLength <= bytes.count else { throw DNSError.packetTooShort }
            let rdataBytes = Array(bytes[offset..<(offset + rdLength)])
            
            let queryType = DNSQueryType(rawValue: typeCode) ?? .ANY
            let (displayVal, prio) = try parseRData(
                type: queryType,
                rdata: rdataBytes,
                fullPacket: bytes,
                rdataOffset: offset
            )
            
            offset += rdLength
            
            answers.append(
                ParsedDNSRecord(
                    name: name,
                    type: queryType,
                    dnsClass: dnsClass,
                    ttl: ttl,
                    displayValue: displayVal,
                    priority: prio
                )
            )
        }
        
        return (header, answers)
    }
    
    // MARK: - Safe Name Decompression (RFC 1035 section 4.1.4)
    public static func readDomainName(from bytes: [UInt8], offset: inout Int) throws -> String {
        var labels: [String] = []
        var jumped = false
        var jumpsCount = 0
        var visitedOffsets: Set<Int> = []
        var currentOffset = offset
        
        while currentOffset < bytes.count {
            let lengthByte = bytes[currentOffset]
            
            // Kết thúc nhãn rễ (0x00)
            if lengthByte == 0 {
                if !jumped {
                    offset = currentOffset + 1
                }
                return labels.isEmpty ? "." : labels.joined(separator: ".")
            }
            
            // Con trỏ nén 0xC0 (Compression Pointer)
            if (lengthByte & 0xC0) == 0xC0 {
                guard currentOffset + 1 < bytes.count else { throw DNSError.packetTooShort }
                let pointer = Int((UInt16(lengthByte & 0x3F) << 8) | UInt16(bytes[currentOffset + 1]))
                
                // Kiểm tra con trỏ trỏ ra ngoài gói
                guard pointer < bytes.count else { throw DNSError.pointerOutOfBounds }
                
                // Kiểm tra vòng lặp vô hạn (Cycle detection)
                if visitedOffsets.contains(pointer) {
                    throw DNSError.compressionLoopDetected
                }
                visitedOffsets.insert(pointer)
                
                // Kiểm tra giới hạn số bước nhảy
                jumpsCount += 1
                if jumpsCount > maxPointerJumps {
                    throw DNSError.pointerDepthExceeded
                }
                
                if !jumped {
                    offset = currentOffset + 2
                    jumped = true
                }
                currentOffset = pointer
                continue
            }
            
            // Nhãn văn bản thông thường
            let labelLength = Int(lengthByte)
            currentOffset += 1
            
            guard currentOffset + labelLength <= bytes.count else {
                throw DNSError.invalidLabelLength
            }
            
            let labelData = Array(bytes[currentOffset..<(currentOffset + labelLength)])
            let labelStr = String(decoding: labelData, as: UTF8.self)
            labels.append(labelStr)
            currentOffset += labelLength
            
            if !jumped {
                offset = currentOffset
            }
        }
        
        throw DNSError.packetTooShort
    }
    
    // MARK: - Parse RDATA
    private static func parseRData(
        type: DNSQueryType,
        rdata: [UInt8],
        fullPacket: [UInt8],
        rdataOffset: Int
    ) throws -> (value: String, priority: Int?) {
        switch type {
        case .A:
            guard rdata.count == 4 else { throw DNSError.malformedRData }
            let ip = "\(rdata[0]).\(rdata[1]).\(rdata[2]).\(rdata[3])"
            return (ip, nil)
            
        case .AAAA:
            guard rdata.count == 16 else { throw DNSError.malformedRData }
            var parts: [String] = []
            for i in stride(from: 0, to: 16, by: 2) {
                let val = (UInt16(rdata[i]) << 8) | UInt16(rdata[i + 1])
                parts.append(String(val, radix: 16))
            }
            return (parts.joined(separator: ":"), nil)
            
        case .CNAME, .NS, .PTR:
            var ptrOffset = rdataOffset
            let name = try readDomainName(from: fullPacket, offset: &ptrOffset)
            return (name, nil)
            
        case .MX:
            guard rdata.count >= 3 else { throw DNSError.malformedRData }
            let preference = Int((UInt16(rdata[0]) << 8) | UInt16(rdata[1]))
            var ptrOffset = rdataOffset + 2
            let host = try readDomainName(from: fullPacket, offset: &ptrOffset)
            return ("\(preference) \(host)", preference)
            
        case .TXT:
            var texts: [String] = []
            var i = 0
            while i < rdata.count {
                let len = Int(rdata[i])
                i += 1
                if i + len <= rdata.count {
                    let sub = Array(rdata[i..<(i + len)])
                    texts.append(String(decoding: sub, as: UTF8.self))
                    i += len
                } else {
                    break
                }
            }
            return (texts.map { "\"\($0)\"" }.joined(separator: " "), nil)
            
        case .SOA:
            var ptrOffset = rdataOffset
            let mname = try readDomainName(from: fullPacket, offset: &ptrOffset)
            let rname = try readDomainName(from: fullPacket, offset: &ptrOffset)
            let remaining = fullPacket.count - ptrOffset
            if remaining >= 20 {
                let serial = readUInt32(fullPacket, ptrOffset)
                return ("\(mname) \(rname) (Serial: \(serial))", nil)
            }
            return ("\(mname) \(rname)", nil)
            
        case .SRV:
            guard rdata.count >= 7 else { throw DNSError.malformedRData }
            let prio = Int((UInt16(rdata[0]) << 8) | UInt16(rdata[1]))
            let weight = Int((UInt16(rdata[2]) << 8) | UInt16(rdata[3]))
            let port = Int((UInt16(rdata[4]) << 8) | UInt16(rdata[5]))
            var ptrOffset = rdataOffset + 6
            let target = try readDomainName(from: fullPacket, offset: &ptrOffset)
            return ("\(prio) \(weight) \(port) \(target)", prio)
            
        case .CAA:
            guard rdata.count >= 2 else { throw DNSError.malformedRData }
            let tagLen = Int(rdata[1])
            guard rdata.count >= 2 + tagLen else { throw DNSError.malformedRData }
            let tag = String(decoding: Array(rdata[2..<(2 + tagLen)]), as: UTF8.self)
            let val = String(decoding: Array(rdata[(2 + tagLen)...]), as: UTF8.self)
            return ("\(tag) \"\(val)\"", nil)
            
        case .SVCB, .HTTPS:
            return try parseSVCBorHTTPS(rdata: rdata, fullPacket: fullPacket, rdataOffset: rdataOffset)
            
        default:
            return ("\(rdata.count) bytes data", nil)
        }
    }
    
    // MARK: - Parse SVCB (64) / HTTPS (65) (RFC 9460)
    public static func parseSVCBorHTTPS(
        rdata: [UInt8],
        fullPacket: [UInt8],
        rdataOffset: Int
    ) throws -> (value: String, priority: Int?) {
        guard rdata.count >= 2 else { throw DNSError.malformedRData }
        let prio = Int((UInt16(rdata[0]) << 8) | UInt16(rdata[1]))
        
        var ptrOffset = rdataOffset + 2
        let target = try readDomainName(from: fullPacket, offset: &ptrOffset)
        let targetDisplay = target.isEmpty ? "." : target
        
        let paramsStartInFull = ptrOffset
        let paramsLength = (rdataOffset + rdata.count) - paramsStartInFull
        
        var paramStrings: [String] = []
        if paramsLength > 0 && paramsStartInFull + paramsLength <= fullPacket.count {
            var pOff = paramsStartInFull
            while pOff + 4 <= paramsStartInFull + paramsLength {
                let key = (UInt16(fullPacket[pOff]) << 8) | UInt16(fullPacket[pOff + 1])
                let len = Int((UInt16(fullPacket[pOff + 2]) << 8) | UInt16(fullPacket[pOff + 3]))
                pOff += 4
                
                guard pOff + len <= paramsStartInFull + paramsLength else { break }
                let valBytes = Array(fullPacket[pOff..<(pOff + len)])
                pOff += len
                
                let paramDesc = formatSVCBParam(key: key, valueData: valBytes)
                paramStrings.append(paramDesc)
            }
        }
        
        var result = "\(prio) \(targetDisplay)"
        if !paramStrings.isEmpty {
            result += " " + paramStrings.joined(separator: " ")
        }
        return (result, prio)
    }
    
    private static func formatSVCBParam(key: UInt16, valueData: [UInt8]) -> String {
        switch key {
        case 1: // alpn
            var alpnList: [String] = []
            var i = 0
            while i < valueData.count {
                let l = Int(valueData[i])
                i += 1
                if i + l <= valueData.count {
                    let s = String(decoding: Array(valueData[i..<(i + l)]), as: UTF8.self)
                    alpnList.append(s)
                    i += l
                } else { break }
            }
            return "alpn=\(alpnList.joined(separator: ","))"
            
        case 2: // no-default-alpn
            return "no-default-alpn"
            
        case 3: // port
            if valueData.count == 2 {
                let port = (UInt16(valueData[0]) << 8) | UInt16(valueData[1])
                return "port=\(port)"
            }
            return "port=unknown"
            
        case 4: // ipv4hint
            var ips: [String] = []
            for i in stride(from: 0, to: valueData.count, by: 4) {
                if i + 4 <= valueData.count {
                    ips.append("\(valueData[i]).\(valueData[i+1]).\(valueData[i+2]).\(valueData[i+3])")
                }
            }
            return "ipv4hint=\(ips.joined(separator: ","))"
            
        case 5: // ech
            return "ech=\(valueData.count)B"
            
        case 6: // ipv6hint
            var ips: [String] = []
            for i in stride(from: 0, to: valueData.count, by: 16) {
                if i + 16 <= valueData.count {
                    var parts: [String] = []
                    for j in stride(from: i, to: i + 16, by: 2) {
                        let word = (UInt16(valueData[j]) << 8) | UInt16(valueData[j+1])
                        parts.append(String(word, radix: 16))
                    }
                    ips.append(parts.joined(separator: ":"))
                }
            }
            return "ipv6hint=\(ips.joined(separator: ","))"
            
        default:
            return "key\(key)=\(valueData.count)B"
        }
    }
    
    private static func readUInt32(_ data: [UInt8], _ offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return (UInt32(data[offset]) << 24) | (UInt32(data[offset + 1]) << 16) | (UInt32(data[offset + 2]) << 8) | UInt32(data[offset + 3])
    }
}
