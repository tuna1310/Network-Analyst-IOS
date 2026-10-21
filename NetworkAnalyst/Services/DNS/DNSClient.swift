//
//  DNSClient.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network

/// Client phân giải DNS nâng cao hỗ trợ DoH (RFC 8484, RFC 8427) và Raw UDP DNS
/// Hỗ trợ đầy đủ các bản ghi: A, AAAA, MX, TXT, NS, CNAME, SOA, SRV, PTR, CAA.
public actor DNSClient {
    public static let shared = DNSClient()
    
    private let urlSession: URLSession
    
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5.0
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Truy vấn bản ghi DNS qua DNS-over-HTTPS (DoH)
    public func resolve(
        domain: String,
        type: DNSRecordType = .A,
        provider: DNSProvider = .cloudflare
    ) async -> DNSQueryResult {
        let cleanDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanDomain.isEmpty else {
            return DNSQueryResult(domain: domain, recordType: type, provider: provider, error: "Tên miền không hợp lệ")
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Thử qua giao thức DoH JSON (Cloudflare / Google)
        if let jsonResult = await queryDoHJSON(domain: cleanDomain, type: type, provider: provider) {
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return DNSQueryResult(
                domain: cleanDomain,
                recordType: type,
                provider: provider,
                records: jsonResult,
                responseTimeMs: elapsed,
                error: nil
            )
        }
        
        // 2. Dự phòng truy vấn DoH Binary Wire-Format (RFC 8484)
        if let wireResult = await queryDoHWire(domain: cleanDomain, type: type, provider: provider) {
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return DNSQueryResult(
                domain: cleanDomain,
                recordType: type,
                provider: provider,
                records: wireResult,
                responseTimeMs: elapsed,
                error: nil
            )
        }
        
        // 3. Dự phòng gửi gói tin UDP trực tiếp qua NWConnection
        if let udpResult = await queryUDPWire(domain: cleanDomain, type: type, provider: provider) {
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return DNSQueryResult(
                domain: cleanDomain,
                recordType: type,
                provider: provider,
                records: udpResult,
                responseTimeMs: elapsed,
                error: nil
            )
        }
        
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        return DNSQueryResult(
            domain: cleanDomain,
            recordType: type,
            provider: provider,
            records: [],
            responseTimeMs: elapsed,
            error: "Không nhận được phản hồi từ máy chủ DNS (\(provider.rawValue))"
        )
    }
    
    // MARK: - DoH JSON Format (RFC 8427 / Cloudflare & Google)
    private func queryDoHJSON(domain: String, type: DNSRecordType, provider: DNSProvider) async -> [DNSRecordItem]? {
        var components = URLComponents(string: provider.dohURL)
        components?.queryItems = [
            URLQueryItem(name: "name", value: domain),
            URLQueryItem(name: "type", value: type.rawValue)
        ]
        
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            
            struct DoHResponse: Decodable {
                struct Answer: Decodable {
                    let name: String
                    let type: Int
                    let TTL: Int
                    let data: String
                }
                let Status: Int
                let Answer: [Answer]?
            }
            
            let decoded = try JSONDecoder().decode(DoHResponse.self, from: data)
            guard let answers = decoded.Answer, !answers.isEmpty else {
                return []
            }
            
            return answers.map { ans in
                let rType = DNSRecordType.fromCode(UInt16(ans.type))
                var val = ans.data
                var prio: Int? = nil
                
                // Chuẩn hóa MX format (e.g. "10 mail.example.com")
                if rType == .MX {
                    let parts = ans.data.split(separator: " ")
                    if parts.count >= 2, let p = Int(parts[0]) {
                        prio = p
                        val = String(parts[1])
                    }
                }
                
                // Bỏ ngoặc kép bao quanh TXT record nếu có
                if rType == .TXT && val.hasPrefix("\"") && val.hasSuffix("\"") {
                    val = String(val.dropFirst().dropLast())
                }
                
                return DNSRecordItem(
                    name: ans.name,
                    type: rType,
                    ttl: ans.TTL,
                    value: val,
                    priority: prio
                )
            }
        } catch {
            return nil
        }
    }
    
    // MARK: - DoH RFC 8484 Binary Wire Query
    private func queryDoHWire(domain: String, type: DNSRecordType, provider: DNSProvider) async -> [DNSRecordItem]? {
        let wireQuery = DNSWireCodec.buildQuery(domain: domain, type: type.code)
        guard let url = URL(string: provider.dohURL) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        request.httpBody = wireQuery
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            return DNSWireCodec.parseResponse(data: data)
        } catch {
            return nil
        }
    }
    
    // MARK: - UDP Wire Query qua NWConnection
    private func queryUDPWire(domain: String, type: DNSRecordType, provider: DNSProvider) async -> [DNSRecordItem]? {
        let queryData = DNSWireCodec.buildQuery(domain: domain, type: type.code)
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(provider.udpIP), port: 53)
        let connection = NWConnection(to: endpoint, using: .udp)
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            let timer = DispatchSource.makeTimerSource()
            timer.schedule(deadline: .now() + 2.0)
            timer.setEventHandler {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
            timer.resume()
            
            connection.stateUpdateHandler = { state in
                guard !hasResumed else { return }
                switch state {
                case .ready:
                    connection.send(content: queryData, completion: .contentProcessed { error in
                        if error != nil {
                            if !hasResumed {
                                hasResumed = true
                                timer.cancel()
                                connection.cancel()
                                continuation.resume(returning: nil)
                            }
                            return
                        }
                        
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { data, _, _, recvError in
                            guard !hasResumed else { return }
                            hasResumed = true
                            timer.cancel()
                            connection.cancel()
                            
                            if let data = data, recvError == nil {
                                let records = DNSWireCodec.parseResponse(data: data)
                                continuation.resume(returning: records)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        }
                    })
                case .failed:
                    if !hasResumed {
                        hasResumed = true
                        timer.cancel()
                        connection.cancel()
                        continuation.resume(returning: nil)
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
}

// MARK: - DNS Binary Wire Codec (RFC 1035)
public enum DNSWireCodec {
    /// Đóng gói gói tin truy vấn DNS tiêu chuẩn RFC 1035
    public static func buildQuery(domain: String, type: UInt16) -> Data {
        var data = Data()
        
        // 1. Transaction ID
        let txId = UInt16.random(in: 1...65535)
        data.append(UInt8((txId >> 8) & 0xFF))
        data.append(UInt8(txId & 0xFF))
        
        // 2. Flags: Standard query (0x0100 -> Recursion Desired)
        data.append(0x01)
        data.append(0x00)
        
        // 3. QDCOUNT: 1
        data.append(0x00)
        data.append(0x01)
        
        // 4. ANCOUNT, NSCOUNT, ARCOUNT = 0
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        // 5. QNAME (Length-prefixed labels)
        for label in domain.split(separator: ".") {
            let labelBytes = Array(label.utf8)
            data.append(UInt8(labelBytes.count))
            data.append(contentsOf: labelBytes)
        }
        data.append(0x00) // End of domain
        
        // 6. QTYPE
        data.append(UInt8((type >> 8) & 0xFF))
        data.append(UInt8(type & 0xFF))
        
        // 7. QCLASS: 0x0001 (IN)
        data.append(0x00)
        data.append(0x01)
        
        return data
    }
    
    /// Giải mã gói tin phản hồi DNS RFC 1035
    public static func parseResponse(data: Data) -> [DNSRecordItem] {
        guard data.count >= 12 else { return [] }
        
        let bytes = [UInt8](data)
        let anCount = (Int(bytes[6]) << 8) | Int(bytes[7])
        guard anCount > 0 else { return [] }
        
        var offset = 12
        
        // Bỏ qua phần Question
        _ = readDomainName(bytes: bytes, offset: &offset)
        offset += 4 // QTYPE + QCLASS
        
        var records: [DNSRecordItem] = []
        
        // Đọc các bản ghi trong Answer section
        for _ in 0..<anCount {
            guard offset < bytes.count else { break }
            let name = readDomainName(bytes: bytes, offset: &offset)
            guard offset + 10 <= bytes.count else { break }
            
            let typeCode = (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
            let ttl = (Int(bytes[offset + 4]) << 24) |
                      (Int(bytes[offset + 5]) << 16) |
                      (Int(bytes[offset + 6]) << 8) |
                      Int(bytes[offset + 7])
            let rdLength = (Int(bytes[offset + 8]) << 8) | Int(bytes[offset + 9])
            offset += 10
            
            guard offset + rdLength <= bytes.count else { break }
            let rdataBytes = Array(bytes[offset..<offset + rdLength])
            
            let recordType = DNSRecordType.fromCode(typeCode)
            var recordVal = ""
            var priority: Int? = nil
            
            switch recordType {
            case .A:
                if rdLength == 4 {
                    recordVal = "\(rdataBytes[0]).\(rdataBytes[1]).\(rdataBytes[2]).\(rdataBytes[3])"
                }
            case .AAAA:
                if rdLength == 16 {
                    var parts: [String] = []
                    for i in stride(from: 0, to: 16, by: 2) {
                        let word = (UInt16(rdataBytes[i]) << 8) | UInt16(rdataBytes[i + 1])
                        parts.append(String(format: "%x", word))
                    }
                    recordVal = parts.joined(separator: ":")
                }
            case .CNAME, .NS, .PTR:
                var rOffset = offset
                recordVal = readDomainName(bytes: bytes, offset: &rOffset)
            case .MX:
                if rdLength >= 3 {
                    let pref = (Int(rdataBytes[0]) << 8) | Int(rdataBytes[1])
                    priority = pref
                    var rOffset = offset + 2
                    let ex = readDomainName(bytes: bytes, offset: &rOffset)
                    recordVal = ex
                }
            case .TXT:
                var tOffset = 0
                var txts: [String] = []
                while tOffset < rdLength {
                    let len = Int(rdataBytes[tOffset])
                    tOffset += 1
                    if tOffset + len <= rdLength {
                        let chunk = Array(rdataBytes[tOffset..<tOffset + len])
                        if let s = String(bytes: chunk, encoding: .utf8) {
                            txts.append(s)
                        }
                        tOffset += len
                    } else { break }
                }
                recordVal = txts.joined(separator: " ")
            case .SOA:
                var rOffset = offset
                let mname = readDomainName(bytes: bytes, offset: &rOffset)
                let rname = readDomainName(bytes: bytes, offset: &rOffset)
                recordVal = "Primary NS: \(mname), Mail: \(rname)"
            case .SRV:
                if rdLength >= 6 {
                    let prio = (Int(rdataBytes[0]) << 8) | Int(rdataBytes[1])
                    let weight = (Int(rdataBytes[2]) << 8) | Int(rdataBytes[3])
                    let port = (Int(rdataBytes[4]) << 8) | Int(rdataBytes[5])
                    var rOffset = offset + 6
                    let target = readDomainName(bytes: bytes, offset: &rOffset)
                    priority = prio
                    recordVal = "\(target):\(port) (Weight: \(weight))"
                }
            default:
                recordVal = rdataBytes.map { String(format: "%02x", $0) }.joined()
            }
            
            offset += rdLength
            
            records.append(
                DNSRecordItem(
                    name: name,
                    type: recordType,
                    ttl: ttl,
                    value: recordVal,
                    priority: priority
                )
            )
        }
        
        return records
    }
    
    /// Đọc tên miền có nén (Pointers 0xC0) theo RFC 1035
    private static func readDomainName(bytes: [UInt8], offset: inout Int) -> String {
        var labels: [String] = []
        var jumped = false
        var jumpOffset = offset
        var loopCount = 0
        
        while offset < bytes.count && loopCount < 50 {
            loopCount += 1
            let length = Int(bytes[offset])
            
            if length == 0 {
                offset += 1
                break
            }
            
            // Pointer (2 high bits are 11 -> 0xC0)
            if (length & 0xC0) == 0xC0 {
                guard offset + 1 < bytes.count else { break }
                let pointer = ((length & 0x3F) << 8) | Int(bytes[offset + 1])
                if !jumped {
                    jumpOffset = offset + 2
                    jumped = true
                }
                offset = pointer
                continue
            }
            
            offset += 1
            guard offset + length <= bytes.count else { break }
            let labelBytes = Array(bytes[offset..<offset + length])
            if let label = String(bytes: labelBytes, encoding: .utf8) {
                labels.append(label)
            }
            offset += length
        }
        
        if jumped {
            offset = jumpOffset
        }
        
        return labels.joined(separator: ".")
    }
}
