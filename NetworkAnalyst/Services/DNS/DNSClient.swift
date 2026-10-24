//
//  DNSClient.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import NetworkCore

/// Client phân giải DNS nâng cao hỗ trợ DoH (RFC 8484), Raw UDP DNS (RFC 1035) kèm EDNS0 (RFC 6891)
/// và tự động thử lại qua TCP (RFC 7766) khi gặp cờ Truncated (TC = 1)
public actor DNSClient {
    public static let shared = DNSClient()
    
    private let urlSession: URLSession
    
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 6.0
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Truy vấn bản ghi DNS với cơ chế tự động chuyển đổi giao thức (DoH -> UDP -> TCP fallback khi bị TC)
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
        
        // 1. Thử qua DoH nếu nhà cung cấp hỗ trợ
        if let dohURL = provider.dohURL {
            if let dohResult = await queryDoHWire(domain: cleanDomain, type: type, urlString: dohURL) {
                let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return DNSQueryResult(
                    domain: cleanDomain,
                    recordType: type,
                    provider: provider,
                    records: dohResult,
                    responseTimeMs: elapsed,
                    isTruncated: false,
                    retriedOverTCP: false,
                    error: dohResult.isEmpty ? "Không tìm thấy bản ghi nào" : nil
                )
            }
        }
        
        // 2. Truy vấn UDP Wire-format (với EDNS0 4096 bytes)
        let udpResult = await queryUDPWire(domain: cleanDomain, type: type, serverIP: provider.udpIP)
        
        // Nếu gói tin UDP bị cắt ngắn (Truncated bit TC = 1), tự động thử lại qua TCP (RFC 7766)
        if udpResult.isTruncated {
            if let tcpResult = await queryTCPWire(domain: cleanDomain, type: type, serverIP: provider.udpIP) {
                let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return DNSQueryResult(
                    domain: cleanDomain,
                    recordType: type,
                    provider: provider,
                    records: tcpResult,
                    responseTimeMs: elapsed,
                    isTruncated: false,
                    retriedOverTCP: true,
                    error: tcpResult.isEmpty ? "Không tìm thấy bản ghi nào qua TCP" : nil
                )
            }
        }
        
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        if !udpResult.records.isEmpty {
            return DNSQueryResult(
                domain: cleanDomain,
                recordType: type,
                provider: provider,
                records: udpResult.records,
                responseTimeMs: elapsed,
                isTruncated: udpResult.isTruncated,
                retriedOverTCP: false,
                error: nil
            )
        }
        
        var finalError = udpResult.error ?? "Không nhận được phản hồi từ \(provider.rawValue)"
        if case .system(let gw) = provider {
            let gwDesc = (gw != nil && !gw!.isEmpty) ? "Gateway: \(gw!)" : "DHCP Gateway"
            if type == .HTTPS || type == .SVCB || type == .SRV || type == .CAA {
                finalError = "Máy chủ DNS cục bộ (\(gwDesc)) không phản hồi loại bản ghi \(type.rawValue). Router thông thường chỉ hỗ trợ hoặc chuyển tiếp A/AAAA, và không trả lời các bản ghi đặc biệt như HTTPS, SVCB, SRV, CAA. Gợi ý: Hãy chuyển sang Cloudflare (1.1.1.1) hoặc Google (8.8.8.8) qua DoH."
            }
        }
        
        return DNSQueryResult(
            domain: cleanDomain,
            recordType: type,
            provider: provider,
            records: [],
            responseTimeMs: elapsed,
            isTruncated: udpResult.isTruncated,
            retriedOverTCP: false,
            error: finalError
        )
    }
    
    // MARK: - DoH Wire-Format (RFC 8484 application/dns-message)
    private func queryDoHWire(domain: String, type: DNSRecordType, urlString: String) async -> [DNSRecordItem]? {
        guard let url = URL(string: urlString) else { return nil }
        
        let queryData = DNSCodec.buildQuery(domain: domain, type: type.toCoreType, useEDNS0: true)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        request.httpBody = queryData
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            
            let (_, answers) = try DNSCodec.parseResponse(bytes: Array(data))
            return answers.map {
                DNSRecordItem(
                    name: $0.name,
                    type: DNSRecordType.fromCode($0.type.rawValue),
                    ttl: Int($0.ttl),
                    value: $0.displayValue,
                    priority: $0.priority
                )
            }
        } catch {
            return nil
        }
    }
    
    // MARK: - UDP Wire-Format Query (cổng 53 với EDNS0)
    private func queryUDPWire(
        domain: String,
        type: DNSRecordType,
        serverIP: String
    ) async -> (records: [DNSRecordItem], isTruncated: Bool, error: String?) {
        let queryData = DNSCodec.buildQuery(domain: domain, type: type.toCoreType, useEDNS0: true)
        
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.Host(serverIP)
            let port = NWEndpoint.Port(integerLiteral: 53)
            let params = NWParameters.udp
            
            let connection = NWConnection(host: endpoint, port: port, using: params)
            var hasResumed = false
            let lock = NSLock()
            
            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + 2.5)
            timer.setEventHandler {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: ([], false, "Hết thời gian chờ phản hồi UDP"))
            }
            timer.resume()
            
            let finish = { (records: [DNSRecordItem], isTruncated: Bool, error: String?) in
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                timer.cancel()
                connection.cancel()
                continuation.resume(returning: (records, isTruncated, error))
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: queryData, completion: .contentProcessed { sendErr in
                        if let sendErr = sendErr {
                            finish([], false, sendErr.localizedDescription)
                            return
                        }
                        
                        connection.receiveMessage { content, _, _, recvErr in
                            if let recvErr = recvErr {
                                finish([], false, recvErr.localizedDescription)
                                return
                            }
                            
                            guard let data = content else {
                                finish([], false, "Phản hồi UDP rỗng")
                                return
                            }
                            
                            do {
                                let (header, answers) = try DNSCodec.parseResponse(bytes: Array(data))
                                let items = answers.map {
                                    DNSRecordItem(
                                        name: $0.name,
                                        type: DNSRecordType.fromCode($0.type.rawValue),
                                        ttl: Int($0.ttl),
                                        value: $0.displayValue,
                                        priority: $0.priority
                                    )
                                }
                                finish(items, header.isTruncated, nil)
                            } catch {
                                finish([], false, error.localizedDescription)
                            }
                        }
                    })
                case .failed(let err):
                    finish([], false, err.localizedDescription)
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
    
    // MARK: - TCP Wire-Format Query (RFC 7766 - Tự động dự phòng khi TC=1)
    private func queryTCPWire(
        domain: String,
        type: DNSRecordType,
        serverIP: String
    ) async -> [DNSRecordItem]? {
        let queryPayload = DNSCodec.buildQuery(domain: domain, type: type.toCoreType, useEDNS0: true)
        
        // Theo chuẩn RFC 1035 section 4.2.2: Gói tin DNS qua TCP bắt buộc có tiền tố 2 byte độ dài (Big Endian)
        var tcpPacket = Data()
        let lengthPrefix = UInt16(queryPayload.count).bigEndian
        withUnsafeBytes(of: lengthPrefix) { tcpPacket.append(contentsOf: $0) }
        tcpPacket.append(queryPayload)
        
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.Host(serverIP)
            let port = NWEndpoint.Port(integerLiteral: 53)
            let params = NWParameters.tcp
            
            let connection = NWConnection(host: endpoint, port: port, using: params)
            var hasResumed = false
            let lock = NSLock()
            
            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + 3.5)
            timer.setEventHandler {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: nil)
            }
            timer.resume()
            
            let finish = { (records: [DNSRecordItem]?) in
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                timer.cancel()
                connection.cancel()
                continuation.resume(returning: records)
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: tcpPacket, completion: .contentProcessed { sendErr in
                        if sendErr != nil {
                            finish(nil)
                            return
                        }
                        
                        // Đọc 2 byte đầu tiên để xác định độ dài phản hồi
                        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { lenData, _, _, lenErr in
                            guard lenErr == nil, let lenBytes = lenData, lenBytes.count == 2 else {
                                finish(nil)
                                return
                            }
                            
                            let expectedLen = Int((UInt16(lenBytes[0]) << 8) | UInt16(lenBytes[1]))
                            guard expectedLen > 0 && expectedLen <= 65535 else {
                                finish(nil)
                                return
                            }
                            
                            // Đọc toàn bộ nội dung gói DNS phản hồi
                            connection.receive(minimumIncompleteLength: expectedLen, maximumLength: expectedLen) { bodyData, _, _, bodyErr in
                                guard bodyErr == nil, let data = bodyData, data.count == expectedLen else {
                                    finish(nil)
                                    return
                                }
                                
                                do {
                                    let (_, answers) = try DNSCodec.parseResponse(bytes: Array(data))
                                    let items = answers.map {
                                        DNSRecordItem(
                                            name: $0.name,
                                            type: DNSRecordType.fromCode($0.type.rawValue),
                                            ttl: Int($0.ttl),
                                            value: $0.displayValue,
                                            priority: $0.priority
                                        )
                                    }
                                    finish(items)
                                } catch {
                                    finish(nil)
                                }
                            }
                        }
                    })
                case .failed:
                    finish(nil)
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
}
