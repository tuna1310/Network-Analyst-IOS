//
//  WhoisTCPClient.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import NetworkCore
#if canImport(Darwin)
import Darwin
#endif

/// Kết quả truy vấn WHOIS qua cổng TCP 43
public struct WhoisResult: Sendable {
    public let query: String
    public let referralChain: [String]
    public let rawText: String
    public let error: String?
    
    public init(query: String, referralChain: [String] = [], rawText: String = "", error: String? = nil) {
        self.query = query
        self.referralChain = referralChain
        self.rawText = rawText
        self.error = error
    }
}

/// Client thực hiện truy vấn WHOIS trực tiếp qua giao thức TCP Port 43 (RFC 3912)
/// Hỗ trợ tự động chuyển tiếp (Referral Chasing) tối đa 3 hop và giới hạn bộ đệm 64KB
public actor WhoisTCPClient {
    public static let shared = WhoisTCPClient()
    
    private let maxReferralHops = 3
    private let maxResponseBytes = 65536 // 64KB
    private let requestTimeoutSeconds: Double = 5.0
    
    public init() {}
    
    /// Thực hiện truy vấn WHOIS bắt đầu từ máy chủ mặc định (whois.iana.org)
    public func query(domainOrIP: String, initialServer: String = "whois.iana.org") async -> WhoisResult {
        let cleanQuery = domainOrIP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return WhoisResult(query: domainOrIP, error: String(localized: "whois.error.invalid_query", defaultValue: "Tên miền hoặc IP không hợp lệ"))
        }
        
        var currentServer = initialServer
        var currentConnectTarget = initialServer
        var referralChain: [String] = [currentServer]
        var latestText = ""
        
        // Kiểm tra an toàn cho máy chủ ban đầu
        if let initialValidIP = resolveAndValidatePublicHost(initialServer) {
            currentConnectTarget = initialValidIP
        }
        
        for hop in 0...maxReferralHops {
            do {
                // Kết nối thẳng tới IP đã xác thực (ngăn chặn tấn công DNS Rebinding)
                let responseText = try await performSingleTCPQuery(connectTarget: currentConnectTarget, query: cleanQuery)
                latestText = responseText
                
                // Nếu đây là hop cuối cùng của giới hạn, dừng lại
                if hop == maxReferralHops {
                    break
                }
                
                // Trích xuất máy chủ referral tiếp theo (nếu có)
                if let nextServer = WhoisReferralParser.extractReferralServer(from: responseText) {
                    let sanitizedNext = nextServer.lowercased()
                    if sanitizedNext != currentServer.lowercased() && !referralChain.contains(sanitizedNext) {
                        // RÀNG BUỘC BẢO MẬT: Bắt buộc phân giải DNS máy chủ referral và từ chối nếu ra IP private / loopback / link-local / ULA
                        guard let validatedIP = resolveAndValidatePublicHost(sanitizedNext) else {
                            // Phát hiện referral trỏ về mạng nội bộ hoặc không phân giải được -> Ngắt referral
                            break
                        }
                        // Kết nối thẳng tới IP đã xác thực để ngăn chặn DNS Rebinding
                        currentConnectTarget = validatedIP
                        currentServer = sanitizedNext
                        referralChain.append(sanitizedNext)
                        continue
                    }
                }
                
                // Không có referral tiếp theo, đã tới máy chủ chứa hồ sơ cuối cùng
                break
            } catch {
                if !latestText.isEmpty {
                    // Nếu đã có phản hồi ở hop trước, giữ lại kết quả và ghi nhận lỗi
                    let referralWarningFormat = String(localized: "whois.error.referral_warning", defaultValue: "Cảnh báo chuyển tiếp: %@")
                    return WhoisResult(
                        query: cleanQuery,
                        referralChain: referralChain,
                        rawText: latestText,
                        error: String(format: referralWarningFormat, error.localizedDescription)
                    )
                } else {
                    let connectionFailedFormat = String(localized: "whois.error.connection_failed", defaultValue: "Lỗi kết nối máy chủ %@ (%@): %@")
                    return WhoisResult(
                        query: cleanQuery,
                        referralChain: referralChain,
                        rawText: "",
                        error: String(format: connectionFailedFormat, currentServer, currentConnectTarget, error.localizedDescription)
                    )
                }
            }
        }
        
        return WhoisResult(
            query: cleanQuery,
            referralChain: referralChain,
            rawText: latestText,
            error: nil
        )
    }
    
    // MARK: - Single TCP Query qua NWConnection
    private func performSingleTCPQuery(connectTarget: String, query: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let endpoint = NWEndpoint.Host(connectTarget)
            let port = NWEndpoint.Port(integerLiteral: 43)
            
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.connectionTimeout = Int(self.requestTimeoutSeconds)
            
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            let connection = NWConnection(host: endpoint, port: port, using: params)
            
            var accumulatedData = Data()
            var isResumed = false
            let lock = NSLock()
            
            // Timeout Watchdog
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + self.requestTimeoutSeconds)
            timer.setEventHandler {
                lock.lock()
                defer { lock.unlock() }
                guard !isResumed else { return }
                isResumed = true
                connection.cancel()
                let timeoutFormat = String(localized: "whois.error.timeout", defaultValue: "Hết thời gian chờ phản hồi từ %@ (5s)")
                continuation.resume(throwing: NSError(domain: "WhoisTCPClient", code: -1001, userInfo: [NSLocalizedDescriptionKey: String(format: timeoutFormat, connectTarget)]))
            }
            timer.resume()
            
            let finishWithResult = { (result: Result<String, Error>) in
                lock.lock()
                defer { lock.unlock() }
                guard !isResumed else { return }
                isResumed = true
                timer.cancel()
                connection.cancel()
                switch result {
                case .success(let text):
                    continuation.resume(returning: text)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Gửi chuỗi query kèm CRLF theo chuẩn RFC 3912
                    let queryPayload = "\(query)\r\n".data(using: .utf8) ?? Data()
                    connection.send(content: queryPayload, completion: .contentProcessed { sendError in
                        if let sendError = sendError {
                            finishWithResult(.failure(sendError))
                            return
                        }
                        
                        // Đọc dữ liệu phản hồi liên tục cho đến khi EOF hoặc đủ 64KB
                        Self.readLoop(connection: connection, accumulated: Data(), maxBytes: self.maxResponseBytes, completion: finishWithResult)
                    })
                    
                case .failed(let err):
                    finishWithResult(.failure(err))
                case .cancelled:
                    break
                default:
                    break
                }
            }
            
            connection.start(queue: DispatchQueue.global())
        }
    }
    
    private nonisolated static func readLoop(
        connection: NWConnection,
        accumulated: Data,
        maxBytes: Int,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { content, _, isComplete, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            var newAcc = accumulated
            if let content = content {
                newAcc.append(content)
            }
            
            // Kiểm tra giới hạn 64KB hoặc kết nối đã hoàn tất
            if isComplete || newAcc.count >= maxBytes {
                let text = String(data: newAcc, encoding: .utf8)
                    ?? String(data: newAcc, encoding: .ascii)
                    ?? String(decoding: newAcc, as: UTF8.self)
                completion(.success(text))
                return
            }
            
            // Tiếp tục nhận thêm
            readLoop(connection: connection, accumulated: newAcc, maxBytes: maxBytes, completion: completion)
        }
    }
    
    // MARK: - DNS SSRF & Rebinding Validation
    /// Phân giải DNS của máy chủ referral, từ chối nếu bất kỳ IP nào là private / loopback / link-local / ULA
    /// và trả về IP công cộng hợp lệ đầu tiên để kết nối trực tiếp (chống DNS Rebinding).
    private func resolveAndValidatePublicHost(_ hostname: String) -> String? {
        guard WhoisReferralParser.isValidPublicWhoisHost(hostname) else {
            return nil
        }
        
        #if canImport(Darwin)
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(hostname, nil, &hints, &res)
        guard status == 0, let first = res else {
            return nil
        }
        defer { freeaddrinfo(res) }
        
        var ptr: UnsafeMutablePointer<addrinfo>? = first
        var firstValidIP: String? = nil
        
        while let current = ptr {
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let nameInfoStatus = getnameinfo(
                current.pointee.ai_addr,
                current.pointee.ai_addrlen,
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if nameInfoStatus == 0 {
                let ipString = String(cString: hostBuffer)
                // Nếu bất kỳ IP nào trỏ về dải nội bộ/riêng tư -> Từ chối toàn bộ máy chủ referral này
                if !WhoisReferralParser.isValidPublicWhoisHost(ipString) {
                    return nil
                }
                if firstValidIP == nil {
                    firstValidIP = ipString
                }
            }
            ptr = current.pointee.ai_next
        }
        return firstValidIP
        #else
        return WhoisReferralParser.isValidPublicWhoisHost(hostname) ? hostname : nil
        #endif
    }
}
