//
//  TracerouteEngine.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import Darwin
import NetworkCore

/// Engine thực hiện Traceroute tăng dần TTL (IP_TTL) với 3 lần probe mỗi hop.
/// Tuân thủ TracerouteEngineProtocol, hỗ trợ thử nghiệm socket ICMP datagram và dự phòng UDP probe.
/// CẢNH BÁO DARWIN / IOS KERNEL:
/// Trên iOS/Darwin, socket UDP không có cờ IP_RECVERR (như trên Linux), và socket ICMP không đặc quyền
/// (SOCK_DGRAM) thường KHÔNG nhận được gói ICMP Time Exceeded (Type 11) do kernel lọc bỏ.
/// Vì vậy cả hai cơ chế này là thử nghiệm, chưa chắc chắn hoạt động được trên thiết bị thương mại
/// và bắt buộc phải kiểm chứng trên iPhone thật. Nếu cả hai cách đều không nhận được phản hồi từ
/// router trung gian, các hop sẽ timeout (* * *), UI sẽ hiển thị giải thích rõ cho người dùng.
public actor TracerouteEngine: TracerouteEngineProtocol {
    private var isCancelled = false
    private let identifier: UInt16
    
    public init() {
        self.identifier = UInt16.random(in: 1000...65000)
    }
    
    public func cancel() {
        self.isCancelled = true
    }
    
    /// Thăm dò một hop với số lần probe (mặc định 3 lần giống công cụ traceroute tiêu chuẩn)
    public func probeHop(
        host: String,
        targetIP: String,
        hop: Int,
        timeout: TimeInterval = 1.0,
        probesPerHop: Int = 3,
        resolveGeoIP: Bool = false,
        geoProvider: GeoIPProvider = HTTPSGeoIPProvider.shared
    ) async -> TracerouteHop {
        guard !isCancelled else {
            return TracerouteHop(hop: hop, status: .timeout)
        }
        
        var probeResults: [Double?] = []
        var respondingIP: String? = nil
        var isDestinationReached = false
        
        for probeIndex in 0..<probesPerHop {
            guard !isCancelled else { break }
            
            let seq = UInt16((hop * 10) + probeIndex)
            let result = await singleProbe(targetIP: targetIP, hop: hop, sequence: seq, timeout: timeout)
            
            if let rtt = result.rttMs {
                probeResults.append(rtt)
                if respondingIP == nil, let ip = result.routerIP {
                    respondingIP = ip
                }
                if result.isDestination {
                    isDestinationReached = true
                }
            } else {
                probeResults.append(nil)
            }
            
            // Giãn cách ngắn giữa các lần probe trong cùng hop
            if probeIndex < probesPerHop - 1 {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        
        guard let routerIP = respondingIP else {
            return TracerouteHop(
                hop: hop,
                probesRTT: probeResults,
                status: .timeout
            )
        }
        
        // Phân giải Reverse DNS PTR
        let hostname = resolveHostname(ip: routerIP)
        
        // Tra cứu vị trí địa lý nếu người dùng yêu cầu
        var geo: HopGeoIPInfo? = nil
        if resolveGeoIP {
            geo = await geoProvider.lookup(ip: routerIP)
        }
        
        let finalStatus: HopStatus = (routerIP == targetIP || isDestinationReached) ? .destinationReached : .responding
        
        return TracerouteHop(
            hop: hop,
            ipAddress: routerIP,
            hostname: hostname,
            probesRTT: probeResults,
            geoInfo: geo,
            status: finalStatus
        )
    }
    
    // MARK: - Single Probe (ICMP with UDP fallback / ICMPv6)
    private func singleProbe(targetIP: String, hop: Int, sequence: UInt16, timeout: TimeInterval) async -> (rttMs: Double?, routerIP: String?, isDestination: Bool) {
        // Trường hợp mục tiêu là IPv6
        if targetIP.contains(":") {
            let startTime = MonotonicClock.now()
            if let v6Result = await sendICMPv6Probe(targetIP: targetIP, hop: hop, sequence: sequence, timeout: timeout) {
                let rtt = MonotonicClock.elapsedMs(since: startTime)
                return (rtt, v6Result.routerIP, v6Result.isDestinationReached)
            }
            return (nil, nil, false)
        }
        
        // 1. Thử gửi probe ICMP IPv4 với IP_TTL
        let startTime = MonotonicClock.now()
        if let icmpResult = await sendICMPProbe(targetIP: targetIP, hop: hop, sequence: sequence, timeout: timeout) {
            let rtt = MonotonicClock.elapsedMs(since: startTime)
            return (rtt, icmpResult.routerIP, icmpResult.isDestinationReached)
        }
        
        // 2. Phương án dự phòng IPv4: Gửi gói UDP tới cổng cao với IP_TTL
        if !isCancelled {
            let udpStart = MonotonicClock.now()
            if let udpResult = await sendUDPProbe(targetIP: targetIP, hop: hop, sequence: sequence, timeout: timeout) {
                let rtt = MonotonicClock.elapsedMs(since: udpStart)
                return (rtt, udpResult.routerIP, udpResult.isDestinationReached)
            }
        }
        
        return (nil, nil, false)
    }
    
    // MARK: - ICMPv6 Socket Probe (Hop Limit)
    private func sendICMPv6Probe(targetIP: String, hop: Int, sequence: UInt16, timeout: TimeInterval) async -> (routerIP: String?, isDestinationReached: Bool)? {
        let sock = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        // Thiết lập Hop Limit cho IPv6 bằng IPV6_UNICAST_HOPS
        var hops = Int32(hop)
        setsockopt(sock, IPPROTO_IPV6, IPV6_UNICAST_HOPS, &hops, socklen_t(MemoryLayout<Int32>.size))
        
        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var destinationAddr = sockaddr_in6()
        destinationAddr.sin6_family = sa_family_t(AF_INET6)
        destinationAddr.sin6_len = __uint8_t(MemoryLayout<sockaddr_in6>.size)
        inet_pton(AF_INET6, targetIP, &destinationAddr.sin6_addr)
        
        let packet = ICMPv6Codec.buildEchoRequest(identifier: self.identifier, sequence: sequence, payloadSize: 24)
        
        let sent = packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &destinationAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, raw.baseAddress, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in6>.size))
                }
            }
        }
        guard sent > 0 else { return nil }
        
        var buffer = [UInt8](repeating: 0, count: 1024)
        var senderAddr = sockaddr_in6()
        var senderLen = socklen_t(MemoryLayout<sockaddr_in6>.size)
        
        let received = withUnsafeMutablePointer(to: &senderAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &buffer, buffer.count, 0, sa, &senderLen)
            }
        }
        guard received > 0 else { return nil }
        
        var senderIPBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(AF_INET6, &senderAddr.sin6_addr, &senderIPBuffer, socklen_t(INET6_ADDRSTRLEN))
        let senderIP = String(cString: senderIPBuffer)
        
        if let parsed = ICMPv6Codec.parseResponse(bytes: Array(buffer[0..<received]), senderIP: senderIP) {
            return (senderIP, parsed.isDestinationReached)
        }
        
        return (senderIP, false)
    }
    
    // MARK: - ICMP Socket Probe
    private func sendICMPProbe(targetIP: String, hop: Int, sequence: UInt16, timeout: TimeInterval) async -> ParsedTraceroutePacket? {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        // Thiết lập IP_TTL trên Datagram socket
        var ttlVal = Int32(hop)
        setsockopt(sock, IPPROTO_IP, IP_TTL, &ttlVal, socklen_t(MemoryLayout<Int32>.size))
        
        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var destinationAddr = sockaddr_in()
        destinationAddr.sin_family = sa_family_t(AF_INET)
        destinationAddr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        inet_pton(AF_INET, targetIP, &destinationAddr.sin_addr)
        
        let packetData = createICMPRequestData(identifier: self.identifier, sequence: sequence)
        
        let sent = packetData.withUnsafeBytes { rawBuffer -> Int in
            guard let base = rawBuffer.baseAddress else { return -1 }
            return withUnsafePointer(to: &destinationAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, base, packetData.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }
        
        var recvBuffer = [UInt8](repeating: 0, count: 512)
        var senderAddr = sockaddr_in()
        var senderLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let bytesRead = withUnsafeMutablePointer(to: &senderAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &recvBuffer, recvBuffer.count, 0, sa, &senderLen)
            }
        }
        guard bytesRead > 0 else { return nil }
        
        var senderIPBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &senderAddr.sin_addr, &senderIPBuffer, socklen_t(INET_ADDRSTRLEN))
        let senderIP = String(cString: senderIPBuffer)
        
        return TracerouteParser.parse(bytes: Array(recvBuffer[0..<bytesRead]), senderIP: senderIP)
    }
    
    // MARK: - UDP Socket Probe Fallback
    private func sendUDPProbe(targetIP: String, hop: Int, sequence: UInt16, timeout: TimeInterval) async -> ParsedTraceroutePacket? {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        var ttlVal = Int32(hop)
        setsockopt(sock, IPPROTO_IP, IP_TTL, &ttlVal, socklen_t(MemoryLayout<Int32>.size))
        
        let destPort = UInt16(33434 + (Int(sequence) % 500))
        var destinationAddr = sockaddr_in()
        destinationAddr.sin_family = sa_family_t(AF_INET)
        destinationAddr.sin_port = destPort.bigEndian
        inet_pton(AF_INET, targetIP, &destinationAddr.sin_addr)
        
        let payload = [UInt8](repeating: 0x58, count: 32)
        
        let sent = payload.withUnsafeBytes { rawBuffer -> Int in
            guard let base = rawBuffer.baseAddress else { return -1 }
            return withUnsafePointer(to: &destinationAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, base, payload.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }
        
        // Mở socket ICMP để đón phản hồi lỗi từ router
        let icmpSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard icmpSock >= 0 else { return nil }
        defer { close(icmpSock) }
        
        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000))
        setsockopt(icmpSock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var recvBuffer = [UInt8](repeating: 0, count: 512)
        var senderAddr = sockaddr_in()
        var senderLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let bytesRead = withUnsafeMutablePointer(to: &senderAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(icmpSock, &recvBuffer, recvBuffer.count, 0, sa, &senderLen)
            }
        }
        guard bytesRead > 0 else { return nil }
        
        var senderIPBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &senderAddr.sin_addr, &senderIPBuffer, socklen_t(INET_ADDRSTRLEN))
        let senderIP = String(cString: senderIPBuffer)
        
        return TracerouteParser.parse(bytes: Array(recvBuffer[0..<bytesRead]), senderIP: senderIP)
    }
    
    // MARK: - Helpers
    private func createICMPRequestData(identifier: UInt16, sequence: UInt16) -> [UInt8] {
        var packet = [UInt8]()
        packet.reserveCapacity(40)
        packet.append(8) // Type: Echo Request
        packet.append(0) // Code: 0
        packet.append(0); packet.append(0) // Checksum placeholder
        packet.append(UInt8((identifier >> 8) & 0xFF))
        packet.append(UInt8(identifier & 0xFF))
        packet.append(UInt8((sequence >> 8) & 0xFF))
        packet.append(UInt8(sequence & 0xFF))
        
        for i in 0..<32 {
            packet.append(UInt8(65 + (i % 26)))
        }
        
        let checksum = InternetChecksum.compute(packet)
        packet[2] = UInt8((checksum >> 8) & 0xFF)
        packet[3] = UInt8(checksum & 0xFF)
        return packet
    }
    
    private func resolveHostname(ip: String) -> String? {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        inet_pton(AF_INET, ip, &addr.sin_addr)
        
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let res = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getnameinfo(sa, socklen_t(MemoryLayout<sockaddr_in>.size), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NAMEREQD)
            }
        }
        
        if res == 0 {
            let name = String(cString: hostBuffer)
            return name != ip ? name : nil
        }
        return nil
    }
}
