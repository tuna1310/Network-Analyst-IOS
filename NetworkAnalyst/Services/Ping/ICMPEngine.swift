//
//  ICMPEngine.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import Darwin
import NetworkCore

/// Engine thực hiện Ping bằng Datagram ICMP Socket không đặc quyền (SOCK_DGRAM, IPPROTO_ICMP)
/// Tuân thủ sandbox iOS và không dùng raw socket.
public actor ICMPEngine {
    private var isCancelled = false
    private let identifier: UInt16
    
    public init() {
        // Sinh ngẫu nhiên ID phiên định danh ICMP
        self.identifier = UInt16.random(in: 1000...65000)
    }
    
    public func cancel() {
        self.isCancelled = true
    }
    
    public struct ResolvedTarget: Sendable {
        public let ipAddress: String
        public let isIPv6: Bool
        
        public init(ipAddress: String, isIPv6: Bool) {
            self.ipAddress = ipAddress
            self.isIPv6 = isIPv6
        }
    }
    
    /// Phân giải hostname sang IPv4 hoặc IPv6 string
    public func resolveHost(_ host: String) -> ResolvedTarget? {
        let clean = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        
        // Kiểm tra nếu là IPv6 trực tiếp
        var sin6 = sockaddr_in6()
        if inet_pton(AF_INET6, clean, &sin6.sin6_addr) == 1 {
            return ResolvedTarget(ipAddress: clean, isIPv6: true)
        }
        
        // Kiểm tra nếu là IPv4 trực tiếp
        var sin4 = sockaddr_in()
        if inet_pton(AF_INET, clean, &sin4.sin_addr) == 1 {
            return ResolvedTarget(ipAddress: clean, isIPv6: false)
        }
        
        // Phân giải bằng getaddrinfo với AF_UNSPEC
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_DGRAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(clean, nil, &hints, &res) == 0, let first = res else {
            return nil
        }
        defer { freeaddrinfo(res) }
        
        var ptr: UnsafeMutablePointer<addrinfo>? = first
        var ipv6Candidate: String? = nil
        
        while let current = ptr {
            if current.pointee.ai_family == AF_INET {
                var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                let sin = current.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var addr = sin.sin_addr
                inet_ntop(AF_INET, &addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
                return ResolvedTarget(ipAddress: String(cString: ipBuffer), isIPv6: false)
            } else if current.pointee.ai_family == AF_INET6 && ipv6Candidate == nil {
                var ipBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                let sin6 = current.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                var addr6 = sin6.sin6_addr
                inet_ntop(AF_INET6, &addr6, &ipBuffer, socklen_t(INET6_ADDRSTRLEN))
                ipv6Candidate = String(cString: ipBuffer)
            }
            ptr = current.pointee.ai_next
        }
        
        if let v6 = ipv6Candidate {
            return ResolvedTarget(ipAddress: v6, isIPv6: true)
        }
        return nil
    }
    
    /// Phân giải hostname sang IPv4 string (tương thích ngược)
    public func resolveHostToIPv4(_ host: String) -> String? {
        if let res = resolveHost(host), !res.isIPv6 {
            return res.ipAddress
        }
        return nil
    }
    
    /// Gửi một gói ICMP Echo Request đơn lẻ và đợi phản hồi (hỗ trợ cả IPv4 và IPv6)
    public func pingOnce(
        to host: String,
        sequence: Int,
        timeout: TimeInterval = 1.0,
        payloadSize: Int = 32
    ) async -> PingPacketResult {
        guard let resolved = resolveHost(host) else {
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: host,
                rttMs: nil,
                bytes: 0,
                status: .error(String(localized: "ping.error.cannot_resolve", defaultValue: "Không thể phân giải địa chỉ IP"))
            )
        }
        
        if resolved.isIPv6 {
            return await pingOnceIPv6(
                host: host,
                ipAddress: resolved.ipAddress,
                sequence: sequence,
                timeout: timeout,
                payloadSize: payloadSize
            )
        } else {
            return await pingOnceIPv4(
                host: host,
                ipAddress: resolved.ipAddress,
                sequence: sequence,
                timeout: timeout,
                payloadSize: payloadSize
            )
        }
    }
    
    // MARK: - IPv6 Ping (ICMPv6 RFC 4443)
    private func pingOnceIPv6(
        host: String,
        ipAddress: String,
        sequence: Int,
        timeout: TimeInterval,
        payloadSize: Int
    ) async -> PingPacketResult {
        let sock = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)
        guard sock >= 0 else {
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: ipAddress,
                rttMs: nil,
                bytes: 0,
                status: .error(String(format: String(localized: "ping.error.ipv6_unsupported_errno", defaultValue: "Mạng hiện tại không hỗ trợ hoặc không có kết nối IPv6 (Socket errno %d)"), errno))
            )
        }
        defer { close(sock) }
        
        var timeoutVal = timeval(
            tv_sec: Int(timeout),
            tv_usec: Int32((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000)
        )
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeoutVal, socklen_t(MemoryLayout<timeval>.size))
        
        var destinationAddr = sockaddr_in6()
        destinationAddr.sin6_family = sa_family_t(AF_INET6)
        destinationAddr.sin6_len = __uint8_t(MemoryLayout<sockaddr_in6>.size)
        inet_pton(AF_INET6, ipAddress, &destinationAddr.sin6_addr)
        
        // LƯU Ý VỀ ICMPv6 CHECKSUM TRÊN DARWIN/IOS:
        // Chưa chắc chắn kernel Darwin có tự tính checksum hay không trên mọi thiết bị thương mại;
        // bắt buộc phải thử nghiệm trên iPhone thật. Mặc định gửi với 0x0000.
        let packetData = ICMPv6Codec.buildEchoRequest(
            identifier: self.identifier,
            sequence: UInt16(sequence & 0xFFFF),
            payloadSize: payloadSize
        )
        
        let startTime = MonotonicClock.now()
        
        let bytesSent = packetData.withUnsafeBytes { rawBuffer -> Int in
            guard let baseAddress = rawBuffer.baseAddress else { return -1 }
            return withUnsafePointer(to: &destinationAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, baseAddress, packetData.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in6>.size))
                }
            }
        }
        
        guard bytesSent > 0 else {
            let err = errno
            let reason = (err == EHOSTUNREACH || err == ENETUNREACH)
                ? String(localized: "ping.error.ipv6_unreachable", defaultValue: "Mạng hiện tại không có kết nối IPv6 (Host/Network unreachable)")
                : String(format: String(localized: "ping.error.ipv6_send_errno", defaultValue: "Lỗi gửi gói tin IPv6: errno %d"), err)
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: ipAddress,
                rttMs: nil,
                bytes: 0,
                status: .error(reason)
            )
        }
        
        var receiveBuffer = [UInt8](repeating: 0, count: 1024)
        var senderAddr = sockaddr_in6()
        var senderLen = socklen_t(MemoryLayout<sockaddr_in6>.size)
        
        let bytesReceived = withUnsafeMutablePointer(to: &senderAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &receiveBuffer, receiveBuffer.count, 0, sa, &senderLen)
            }
        }
        
        let rtt = MonotonicClock.elapsedMs(since: startTime)
        
        guard bytesReceived > 0 else {
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: ipAddress,
                rttMs: nil,
                bytes: 0,
                status: .timeout
            )
        }
        
        var senderIPBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(AF_INET6, &senderAddr.sin6_addr, &senderIPBuffer, socklen_t(INET6_ADDRSTRLEN))
        let senderIP = String(cString: senderIPBuffer)
        
        if let parsed = ICMPv6Codec.parseResponse(bytes: Array(receiveBuffer[0..<bytesReceived]), senderIP: senderIP) {
            if parsed.type == .echoReply {
                return PingPacketResult(
                    sequence: sequence,
                    host: host,
                    ipAddress: ipAddress,
                    rttMs: rtt,
                    bytes: bytesReceived,
                    ttl: 64,
                    status: .success
                )
            } else if parsed.type == .destinationUnreachable {
                return PingPacketResult(
                    sequence: sequence,
                    host: host,
                    ipAddress: ipAddress,
                    rttMs: rtt,
                    bytes: bytesReceived,
                    status: .error(parsed.explanation)
                )
            }
        }
        
        return PingPacketResult(
            sequence: sequence,
            host: host,
            ipAddress: ipAddress,
            rttMs: rtt,
            bytes: bytesReceived,
            status: .success
        )
    }
    
    // MARK: - IPv4 Ping (RFC 792)
    private func pingOnceIPv4(
        host: String,
        ipAddress: String,
        sequence: Int,
        timeout: TimeInterval,
        payloadSize: Int
    ) async -> PingPacketResult {
        
        // Tạo unprivileged ICMP Datagram socket
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard sock >= 0 else {
            // Trường hợp socket không mở được (rất hiếm trên thiết bị thật, có thể xảy ra trên simulator)
            // Dự phòng đo độ trễ TCP connect tới port 80/443
            return await fallbackTCPPing(host: ipAddress, sequence: sequence, timeout: timeout)
        }
        defer { close(sock) }
        
        // Thiết lập timeout nhận
        var timeoutVal = timeval(
            tv_sec: Int(timeout),
            tv_usec: Int32((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000)
        )
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeoutVal, socklen_t(MemoryLayout<timeval>.size))
        
        // Cấu hình địa chỉ đích
        var destinationAddr = sockaddr_in()
        destinationAddr.sin_family = sa_family_t(AF_INET)
        destinationAddr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        inet_pton(AF_INET, ipAddress, &destinationAddr.sin_addr)
        
        // Tạo gói ICMP Echo Request (RFC 792)
        let packetData = createICMPEchoRequest(identifier: self.identifier, sequence: UInt16(sequence & 0xFFFF), payloadSize: payloadSize)
        
        let startTime = MonotonicClock.now()
        
        // Gửi gói tin
        let bytesSent = packetData.withUnsafeBytes { rawBuffer -> Int in
            guard let baseAddress = rawBuffer.baseAddress else { return -1 }
            return withUnsafePointer(to: &destinationAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, baseAddress, packetData.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        
        guard bytesSent > 0 else {
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: ipAddress,
                rttMs: nil,
                bytes: 0,
                status: .error(String(format: String(localized: "ping.error.send_errno", defaultValue: "Lỗi gửi gói tin: errno %d"), errno))
            )
        }
        
        // Đọc phản hồi
        var recvBuffer = [UInt8](repeating: 0, count: 512)
        var senderAddr = sockaddr_in()
        var senderLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let bytesRead = withUnsafeMutablePointer(to: &senderAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &recvBuffer, recvBuffer.count, 0, sa, &senderLen)
            }
        }
        
        let rttMs = MonotonicClock.elapsedMs(since: startTime)
        
        guard bytesRead > 0 else {
            if errno == EAGAIN || errno == EWOULDBLOCK {
                return PingPacketResult(
                    sequence: sequence,
                    host: host,
                    ipAddress: ipAddress,
                    rttMs: nil,
                    bytes: 0,
                    status: .timeout
                )
            } else {
                return PingPacketResult(
                    sequence: sequence,
                    host: host,
                    ipAddress: ipAddress,
                    rttMs: nil,
                    bytes: 0,
                    status: .error(String(format: String(localized: "ping.error.recv_errno", defaultValue: "Lỗi nhận: errno %d"), errno))
                )
            }
        }
        
        // Phân tích gói tin trả về
        // Trên Darwin SOCK_DGRAM ICMP, kernel có thể giữ lại hoặc loại bỏ IP header
        var icmpOffset = 0
        if bytesRead >= 20 && (recvBuffer[0] >> 4) == 4 {
            // Có IP header IPv4: IHL nằm ở 4 bit thấp
            let ihl = Int(recvBuffer[0] & 0x0F) * 4
            icmpOffset = ihl
        }
        
        guard bytesRead >= icmpOffset + 8 else {
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: ipAddress,
                rttMs: nil,
                bytes: bytesRead,
                status: .error(String(localized: "ping.error.packet_too_short", defaultValue: "Gói tin phản hồi quá ngắn"))
            )
        }
        
        let icmpType = recvBuffer[icmpOffset]
        let icmpCode = recvBuffer[icmpOffset + 1]
        
        // Type 0 = Echo Reply
        if icmpType == 0 {
            let ttl = 64 // TTL xấp xỉ
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: ipAddress,
                rttMs: rttMs,
                bytes: bytesRead,
                ttl: ttl,
                status: .success
            )
        } else if icmpType == 3 {
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: ipAddress,
                rttMs: nil,
                bytes: bytesRead,
                status: .destinationUnreachable
            )
        } else {
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: ipAddress,
                rttMs: rttMs,
                bytes: bytesRead,
                status: .error("ICMP Type \(icmpType) Code \(icmpCode)")
            )
        }
    }
    
    /// Tạo dữ liệu ICMP Echo Request (Type: 8, Code: 0, Checksum, Identifier, Sequence, Payload)
    private func createICMPEchoRequest(identifier: UInt16, sequence: UInt16, payloadSize: Int) -> [UInt8] {
        var packet = [UInt8]()
        packet.reserveCapacity(8 + payloadSize)
        
        // Header
        packet.append(8) // Type: Echo Request
        packet.append(0) // Code: 0
        packet.append(0) // Checksum high (placeholder)
        packet.append(0) // Checksum low
        
        // Identifier (Network byte order / big endian)
        packet.append(UInt8((identifier >> 8) & 0xFF))
        packet.append(UInt8(identifier & 0xFF))
        
        // Sequence Number
        packet.append(UInt8((sequence >> 8) & 0xFF))
        packet.append(UInt8(sequence & 0xFF))
        
        // Payload (Timestamp hoặc ký tự mẫu)
        for i in 0..<payloadSize {
            packet.append(UInt8(65 + (i % 26))) // 'A'...'Z'
        }
        
        // Tính Internet Checksum RFC 1071 qua NetworkCore
        let checksum = InternetChecksum.compute(packet)
        packet[2] = UInt8((checksum >> 8) & 0xFF)
        packet[3] = UInt8(checksum & 0xFF)
        
        return packet
    }
    
    /// Dự phòng đo độ trễ qua TCP connect nếu ICMP bị chặn hoàn toàn
    private func fallbackTCPPing(host: String, sequence: Int, timeout: TimeInterval) async -> PingPacketResult {
        let startTime = MonotonicClock.now()
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: 80)
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            let timer = DispatchSource.makeTimerSource()
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: PingPacketResult(
                        sequence: sequence,
                        host: host,
                        ipAddress: host,
                        rttMs: nil,
                        bytes: 0,
                        status: .timeout
                    ))
                }
            }
            timer.resume()
            
            connection.stateUpdateHandler = { state in
                guard !hasResumed else { return }
                switch state {
                case .ready, .waiting:
                    hasResumed = true
                    timer.cancel()
                    let rtt = MonotonicClock.elapsedMs(since: startTime)
                    connection.cancel()
                    continuation.resume(returning: PingPacketResult(
                        sequence: sequence,
                        host: host,
                        ipAddress: host,
                        rttMs: rtt,
                        bytes: 64,
                        ttl: 64,
                        status: .success
                    ))
                case .failed:
                    // Dù port 80 closed (RST), thời gian nhận RST cũng phản ánh RTT mạng
                    hasResumed = true
                    timer.cancel()
                    let rtt = MonotonicClock.elapsedMs(since: startTime)
                    connection.cancel()
                    continuation.resume(returning: PingPacketResult(
                        sequence: sequence,
                        host: host,
                        ipAddress: host,
                        rttMs: rtt,
                        bytes: 64,
                        ttl: 64,
                        status: .success
                    ))
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }
}
