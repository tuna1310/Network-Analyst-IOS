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
            return WhoisResult(query: domainOrIP, error: "Tên miền hoặc IP không hợp lệ")
        }
        
        var currentServer = initialServer
        var referralChain: [String] = [currentServer]
        var latestText = ""
        
        for hop in 0...maxReferralHops {
            do {
                let responseText = try await performSingleTCPQuery(server: currentServer, query: cleanQuery)
                latestText = responseText
                
                // Nếu đây là hop cuối cùng của giới hạn, dừng lại
                if hop == maxReferralHops {
                    break
                }
                
                // Trích xuất máy chủ referral tiếp theo (nếu có)
                if let nextServer = WhoisReferralParser.extractReferralServer(from: responseText) {
                    let sanitizedNext = nextServer.lowercased()
                    if sanitizedNext != currentServer.lowercased() && !referralChain.contains(sanitizedNext) {
                        // RÀNG BUỘC BẢO MẬT: Bắt buộc phân giải DNS máy chủ referral và từ chối nếu ra IP private / loopback / link-local
                        guard resolveAndValidatePublicHost(sanitizedNext) else {
                            // Phát hiện referral trỏ về mạng nội bộ -> Ngắt chuỗi chuyển tiếp ngay lập tức
                            break
                        }
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
                    return WhoisResult(
                        query: cleanQuery,
                        referralChain: referralChain,
                        rawText: latestText,
                        error: "Cảnh báo chuyển tiếp: \(error.localizedDescription)"
                    )
                } else {
                    return WhoisResult(
                        query: cleanQuery,
                        referralChain: referralChain,
                        rawText: "",
                        error: "Lỗi kết nối máy chủ \(currentServer): \(error.localizedDescription)"
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
    private func performSingleTCPQuery(server: String, query: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let endpoint = NWEndpoint.Host(server)
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
                continuation.resume(throwing: NSError(domain: "WhoisTCPClient", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Hết thời gian chờ phản hồi từ \(server) (5s)"]))
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
                        self.readLoop(connection: connection, accumulated: &accumulatedData, completion: finishWithResult)
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
    
    private func readLoop(
        connection: NWConnection,
        accumulated: inout Data,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let content = content {
                accumulated.append(content)
            }
            
            // Kiểm tra giới hạn 64KB hoặc kết nối đã hoàn tất
            if isComplete || accumulated.count >= self.maxResponseBytes {
                let text = String(data: accumulated, encoding: .utf8)
                    ?? String(data: accumulated, encoding: .ascii)
                    ?? String(decoding: accumulated, as: UTF8.self)
                completion(.success(text))
                return
            }
            
            // Tiếp tục nhận thêm
            var nextAcc = accumulated
            self.readLoop(connection: connection, accumulated: &nextAcc, completion: completion)
        }
    }
    
    // MARK: - DNS SSRF Validation
    /// Phân giải DNS của máy chủ referral và từ chối nếu bất kỳ IP phân giải nào là private / loopback / link-local / ULA
    private func resolveAndValidatePublicHost(_ hostname: String) -> Bool {
        guard WhoisReferralParser.isValidPublicWhoisHost(hostname) else {
            return false
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
            return false
        }
        defer { freeaddrinfo(res) }
        
        var ptr: UnsafeMutablePointer<addrinfo>? = first
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
                if !WhoisReferralParser.isValidPublicWhoisHost(ipString) {
                    return false
                }
            }
            ptr = current.pointee.ai_next
        }
        return true
        #else
        return WhoisReferralParser.isValidPublicWhoisHost(hostname)
        #endif
    }
}
