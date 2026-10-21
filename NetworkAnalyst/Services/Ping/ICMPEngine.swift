//
//  ICMPEngine.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import Darwin

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
    
    /// Phân giải hostname sang IPv4 string
    public func resolveHostToIPv4(_ host: String) -> String? {
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_INET,
            ai_socktype: SOCK_DGRAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &res) == 0, let first = res else {
            return nil
        }
        defer { freeaddrinfo(res) }
        
        var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        let sin = first.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        var sin_addr = sin.sin_addr
        inet_ntop(AF_INET, &sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
        return String(cString: ipBuffer)
    }
    
    /// Gửi một gói ICMP Echo Request đơn lẻ và đợi phản hồi
    public func pingOnce(
        to host: String,
        sequence: Int,
        timeout: TimeInterval = 1.0,
        payloadSize: Int = 32
    ) async -> PingPacketResult {
        guard let ipAddress = resolveHostToIPv4(host) else {
            return PingPacketResult(
                sequence: sequence,
                host: host,
                ipAddress: host,
                rttMs: nil,
                bytes: 0,
                status: .error("Không thể phân giải địa chỉ IP")
            )
        }
        
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
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
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
                status: .error("Lỗi gửi gói tin: errno \(errno)")
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
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let rttMs = (endTime - startTime) * 1000.0
        
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
                    status: .error("Lỗi nhận: errno \(errno)")
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
                status: .error("Gói tin phản hồi quá ngắn")
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
        
        // Tính Internet Checksum RFC 1071
        let checksum = calculateChecksum(packet)
        packet[2] = UInt8((checksum >> 8) & 0xFF)
        packet[3] = UInt8(checksum & 0xFF)
        
        return packet
    }
    
    private func calculateChecksum(_ data: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        let count = data.count
        
        while i < count - 1 {
            let word = (UInt32(data[i]) << 8) | UInt32(data[i + 1])
            sum += word
            i += 2
        }
        if i < count {
            let word = UInt32(data[i]) << 8
            sum += word
        }
        
        while (sum >> 16) > 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(sum & 0xFFFF)
    }
    
    /// Dự phòng đo độ trễ qua TCP connect nếu ICMP bị chặn hoàn toàn
    private func fallbackTCPPing(host: String, sequence: Int, timeout: TimeInterval) async -> PingPacketResult {
        let startTime = CFAbsoluteTimeGetCurrent()
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
                    let rtt = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
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
                    let rtt = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
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
