//
//  UnicastProber.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import NetworkCore

/// Kết quả thăm dò Unicast một IP
public struct HostProbeResult: Sendable {
    public let isAlive: Bool
    public let hostname: String?
    public let hostnameSource: HostnameSource?
    public let ipv6Address: String?
    public let ipv6StatusExplanation: String?
    public let macAddress: String?
    public let vendor: String?
    public let deviceType: DeviceType
    public let openPorts: [Int]
    public let rttMs: Double?
    public let methods: [DiscoveryMethod]
}

/// Actor chuyên thực hiện các truy vấn Unicast (NetBIOS, mDNS, LLMNR, SNMP, TCP, ICMP) tới từng IP
public actor UnicastProber {
    public init() {}
    
    /// Thăm dò toàn diện một IP đích bằng ICMP, TCP probe, NetBIOS, mDNS, LLMNR, SNMP và DNS PTR
    public func probe(
        ipAddress: String,
        isGateway: Bool = false,
        isSelf: Bool = false,
        gatewayIP: String? = nil,
        timeout: TimeInterval = 0.5
    ) async -> HostProbeResult? {
        // Nếu là chính máy này
        if isSelf {
            return HostProbeResult(
                isAlive: true,
                hostname: HostNameResolver.getDeviceName(),
                hostnameSource: .mDNS,
                ipv6Address: NetworkInterfaceProvider.getPrimaryWiFiInterface()?.ipv6Address,
                ipv6StatusExplanation: nil,
                macAddress: "iOS Sandbox (Protected)",
                vendor: "Apple Inc.",
                deviceType: .appleDevice,
                openPorts: [],
                rttMs: 0.1,
                methods: [.localInterface]
            )
        }
        
        var methods: [DiscoveryMethod] = []
        var openPorts: [Int] = []
        var netbiosName: String? = nil
        var mdnsName: String? = nil
        var llmnrName: String? = nil
        var ptrName: String? = nil
        var discoveredIpv6: String? = nil
        
        var discoveredMac: String? = nil
        var discoveredVendor: String? = nil
        var detectedType: DeviceType = isGateway ? .router : .unknown
        var bestRTT: Double? = nil
        
        // 1. Thăm dò NetBIOS Name Service (UDP 137)
        if let netbiosResult = await queryNetBIOS(ipAddress: ipAddress, timeout: timeout) {
            methods.append(.netbios)
            netbiosName = netbiosResult.name
            discoveredMac = netbiosResult.mac
            discoveredVendor = netbiosResult.vendor ?? "Windows / SMB Host"
            detectedType = netbiosResult.isNas ? .nas : .windows
        }
        
        // 2. Thăm dò mDNS Unicast (UDP 5353)
        let mdnsResult = await queryMDNSUnicast(ipAddress: ipAddress, timeout: timeout)
        if let name = mdnsResult.hostname {
            methods.append(.bonjour)
            mdnsName = name
            if name.lowercased().contains("apple") || name.lowercased().contains("iphone") || name.lowercased().contains("mac") {
                detectedType = .appleDevice
                discoveredVendor = "Apple Inc."
            }
        }
        if let v6 = mdnsResult.ipv6 {
            discoveredIpv6 = v6
        }
        
        // 3. Thăm dò LLMNR (UDP 5355)
        if let ll = await queryLLMNR(ipAddress: ipAddress, timeout: timeout) {
            methods.append(.llmnr)
            llmnrName = ll
        }
        
        // 4. Thăm dò DNS PTR cục bộ (UDP 53 gửi tới Gateway, timeout 500ms)
        if let ptr = await queryLocalDNSPTR(ipAddress: ipAddress, gatewayIP: gatewayIP, timeout: min(timeout, 0.5)) {
            methods.append(.ptr)
            ptrName = ptr
        }
        
        // 5. Thăm dò SNMP (UDP 161)
        if let snmpDesc = await querySNMP(ipAddress: ipAddress, timeout: timeout) {
            methods.append(.snmp)
            if discoveredVendor == nil {
                discoveredVendor = snmpDesc
            }
            if snmpDesc.lowercased().contains("router") || snmpDesc.lowercased().contains("gateway") {
                detectedType = .router
            } else if snmpDesc.lowercased().contains("printer") {
                detectedType = .printer
            }
        }
        
        // 6. Thử ICMP Ping (Datagram Socket)
        let icmpEngine = ICMPEngine()
        let pingResult = await icmpEngine.pingOnce(to: ipAddress, sequence: 1, timeout: timeout, payloadSize: 16)
        if pingResult.status == .success {
            methods.append(.icmp)
            if let rtt = pingResult.rttMs {
                bestRTT = rtt
            }
        }
        
        // 7. Thăm dò TCP Probe trên các cổng phổ biến
        let commonProbePorts = [80, 443, 22, 445, 8080, 5000, 62078]
        for port in commonProbePorts {
            let portResult = await probeTCPPort(ipAddress: ipAddress, port: port, timeout: 0.35)
            if portResult.isOpen {
                methods.append(.tcp)
                openPorts.append(port)
                if bestRTT == nil { bestRTT = portResult.rttMs }
                
                // Suy đoán loại thiết bị dựa trên port
                if port == 62078 {
                    detectedType = .appleDevice
                    discoveredVendor = "Apple Inc."
                } else if port == 5000 && detectedType == .unknown {
                    detectedType = .nas
                    discoveredVendor = "Synology / NAS"
                } else if port == 445 && detectedType == .unknown {
                    detectedType = .windows
                } else if port == 22 && detectedType == .unknown {
                    detectedType = .linuxServer
                }
            }
        }
        
        // Nếu không có bất kỳ phương thức nào phản hồi => host offline/không tồn tại
        if methods.isEmpty {
            return nil
        }
        
        // Chọn tên máy chủ theo phân cấp ưu tiên: mDNS > NetBIOS > LLMNR > PTR
        let bestHost = HostnameResolver.resolveBestHostname(
            mDNS: mdnsName,
            netBIOS: netbiosName,
            llmnr: llmnrName,
            ptr: ptrName
        )
        
        if isGateway && detectedType == .unknown {
            detectedType = .router
            discoveredVendor = discoveredVendor ?? "Network Gateway"
        }
        
        let v6Explanation = (discoveredIpv6 == nil) ? "Không có địa chỉ IPv6 (Router hoặc thiết bị không kích hoạt IPv6)" : nil
        
        return HostProbeResult(
            isAlive: true,
            hostname: bestHost?.name,
            hostnameSource: bestHost?.source,
            ipv6Address: discoveredIpv6,
            ipv6StatusExplanation: v6Explanation,
            macAddress: discoveredMac,
            vendor: discoveredVendor,
            deviceType: detectedType,
            openPorts: openPorts,
            rttMs: bestRTT,
            methods: Array(Set(methods))
        )
    }
    }
    
    // MARK: - NetBIOS Name Query (RFC 1002) qua UDP 137
    private func queryNetBIOS(ipAddress: String, timeout: TimeInterval) async -> (name: String?, mac: String?, vendor: String?, isNas: Bool)? {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        var tv = timeval(tv_sec: 0, tv_usec: Int32(timeout * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(137).bigEndian
        inet_pton(AF_INET, ipAddress, &dest.sin_addr)
        
        // NetBIOS Node Status Query packet
        // Header: Transaction ID (2B) + Flags 0x0000 + QDCOUNT 1 + ANCOUNT 0 + NSCOUNT 0 + ARCOUNT 0
        // Query Name: 32 bytes encoded wildcard "*" (0x20 + "CKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\0")
        // Type: 0x0021 (NBSTAT) + Class: 0x0001 (IN)
        var packet: [UInt8] = [
            0x80, 0x64, // Trans ID
            0x00, 0x00, // Flags
            0x00, 0x01, // QDCount: 1
            0x00, 0x00, // ANCount: 0
            0x00, 0x00, // NSCount: 0
            0x00, 0x00, // ARCount: 0
            0x20,       // Length of name (32)
            0x43, 0x4B, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x41, 0x41, 0x00, // End of name
            0x00, 0x21, // Type: NBSTAT
            0x00, 0x01  // Class: IN
        ]
        
        let sent = withUnsafePointer(to: &dest) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                packet.withUnsafeBytes { raw in
                    sendto(sock, raw.baseAddress, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }
        
        var buffer = [UInt8](repeating: 0, count: 1024)
        var srcAddr = sockaddr_in()
        var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let received = withUnsafeMutablePointer(to: &srcAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &buffer, buffer.count, 0, sa, &srcLen)
            }
        }
        
        guard received > 56 else { return nil }
        
        // Parse NetBIOS Response
        // Offset 56 chứa số lượng tên: numNames
        let numNames = Int(buffer[56])
        var computerName: String? = nil
        var isNas = false
        
        var offset = 57
        for _ in 0..<min(numNames, 20) {
            if offset + 18 > received { break }
            let nameBytes = Array(buffer[offset..<offset+15])
            let typeByte = buffer[offset + 15]
            
            if let str = String(bytes: nameBytes, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                if typeByte == 0x00 && computerName == nil {
                    computerName = str
                }
                if str.uppercased().contains("NAS") || str.uppercased().contains("SYNOLOGY") || str.uppercased().contains("QNAP") {
                    isNas = true
                }
            }
            offset += 18
        }
        
        // 6 bytes MAC address ở cuối cấu trúc thống kê Node
        var macStr: String? = nil
        if offset + 6 <= received {
            let macBytes = buffer[offset..<offset+6]
            macStr = macBytes.map { String(format: "%02X", $0) }.joined(separator: ":")
        }
        
        var determinedVendor = isNas ? "NAS Device" : "Windows/Samba"
        if let mac = macStr, let ouiVendor = OUIDatabase.shared.lookup(mac: mac) {
            determinedVendor = ouiVendor
        }
        
        return (name: computerName, mac: macStr, vendor: determinedVendor, isNas: isNas)
    }
    
    // MARK: - mDNS Unicast Probe (UDP 5353)
    private func queryMDNSUnicast(ipAddress: String, timeout: TimeInterval) async -> (hostname: String?, ipv6: String?) {
        guard let revDomain = HostnameResolver.ipv4ToReverseDomain(ipAddress) else { return (nil, nil) }
        
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return (nil, nil) }
        defer { close(sock) }
        
        var tv = timeval(tv_sec: 0, tv_usec: Int32(timeout * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(5353).bigEndian
        inet_pton(AF_INET, ipAddress, &dest.sin_addr)
        
        let queryData = DNSCodec.buildQuery(domain: revDomain, type: .PTR, useEDNS0: false)
        
        let sent = withUnsafePointer(to: &dest) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                queryData.withUnsafeBytes { raw in
                    sendto(sock, raw.baseAddress, queryData.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return (nil, nil) }
        
        var buffer = [UInt8](repeating: 0, count: 1024)
        var srcAddr = sockaddr_in()
        var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let readLen = withUnsafeMutablePointer(to: &srcAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &buffer, buffer.count, 0, sa, &srcLen)
            }
        }
        guard readLen > 12 else { return (nil, nil) }
        
        var foundName: String? = nil
        var foundIpv6: String? = nil
        
        if let (_, answers) = try? DNSCodec.parseResponse(bytes: Array(buffer[0..<readLen])) {
            for ans in answers {
                if ans.type == .PTR && foundName == nil {
                    foundName = ans.value
                } else if ans.type == .AAAA && foundIpv6 == nil {
                    foundIpv6 = ans.value
                }
            }
        }
        
        // Trích xuất fallback chuỗi ASCII nếu parser mDNS nén không trích hết
        if foundName == nil, let ascii = String(bytes: buffer[0..<readLen], encoding: .ascii) {
            let tokens = ascii.components(separatedBy: CharacterSet.alphanumerics.inverted)
            for token in tokens where token.count >= 3 && !token.contains("in-addr") && !token.contains("arpa") {
                foundName = token
                break
            }
        }
        
        return (foundName, foundIpv6)
    }
    
    // MARK: - LLMNR Query (RFC 4795) qua UDP 5355
    private func queryLLMNR(ipAddress: String, timeout: TimeInterval) async -> String? {
        guard let revDomain = HostnameResolver.ipv4ToReverseDomain(ipAddress) else { return nil }
        
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        var tv = timeval(tv_sec: 0, tv_usec: Int32(timeout * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(5355).bigEndian
        inet_pton(AF_INET, ipAddress, &dest.sin_addr)
        
        let queryData = DNSCodec.buildQuery(domain: revDomain, type: .PTR, useEDNS0: false)
        
        let sent = withUnsafePointer(to: &dest) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                queryData.withUnsafeBytes { raw in
                    sendto(sock, raw.baseAddress, queryData.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }
        
        var buffer = [UInt8](repeating: 0, count: 512)
        var srcAddr = sockaddr_in()
        var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let readLen = withUnsafeMutablePointer(to: &srcAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &buffer, buffer.count, 0, sa, &srcLen)
            }
        }
        guard readLen > 12 else { return nil }
        
        if let (_, answers) = try? DNSCodec.parseResponse(bytes: Array(buffer[0..<readLen])) {
            for ans in answers where ans.type == .PTR {
                return ans.value
            }
        }
        return nil
    }
    
    // MARK: - DNS PTR Query tới DNS Resolver cục bộ (Gateway) qua UDP 53
    private func queryLocalDNSPTR(ipAddress: String, gatewayIP: String?, timeout: TimeInterval) async -> String? {
        guard let gw = gatewayIP ?? NetworkInterfaceProvider.getDefaultGateway() else { return nil }
        guard let revDomain = HostnameResolver.ipv4ToReverseDomain(ipAddress) else { return nil }
        
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        var tv = timeval(tv_sec: 0, tv_usec: Int32(timeout * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(53).bigEndian
        inet_pton(AF_INET, gw, &dest.sin_addr)
        
        let queryData = DNSCodec.buildQuery(domain: revDomain, type: .PTR, useEDNS0: false)
        
        let sent = withUnsafePointer(to: &dest) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                queryData.withUnsafeBytes { raw in
                    sendto(sock, raw.baseAddress, queryData.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }
        
        var buffer = [UInt8](repeating: 0, count: 512)
        var srcAddr = sockaddr_in()
        var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let readLen = withUnsafeMutablePointer(to: &srcAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &buffer, buffer.count, 0, sa, &srcLen)
            }
        }
        guard readLen > 12 else { return nil }
        
        if let (_, answers) = try? DNSCodec.parseResponse(bytes: Array(buffer[0..<readLen])) {
            for ans in answers where ans.type == .PTR {
                return ans.value
            }
        }
        
        // Dùng getnameinfo làm phương án dự phòng chuẩn POSIX
        return HostNameResolver.reverseLookup(ipAddress: ipAddress)
    }
    
    // MARK: - SNMP v1/v2c GetRequest (UDP 161)
    private func querySNMP(ipAddress: String, timeout: TimeInterval) async -> String? {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        var tv = timeval(tv_sec: 0, tv_usec: Int32(timeout * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(161).bigEndian
        inet_pton(AF_INET, ipAddress, &dest.sin_addr)
        
        // SNMP v1 GetRequest cho sysDescr.0 (1.3.6.1.2.1.1.1.0) community "public"
        let snmpPacket: [UInt8] = [
            0x30, 0x29, 0x02, 0x01, 0x00, 0x04, 0x06, 0x70,
            0x75, 0x62, 0x6c, 0x69, 0x63, 0xa0, 0x1c, 0x02,
            0x04, 0x12, 0x34, 0x56, 0x78, 0x02, 0x01, 0x00,
            0x02, 0x01, 0x00, 0x30, 0x0e, 0x30, 0x0c, 0x06,
            0x08, 0x2b, 0x06, 0x01, 0x02, 0x01, 0x01, 0x01,
            0x00, 0x05, 0x00
        ]
        
        let sent = withUnsafePointer(to: &dest) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                snmpPacket.withUnsafeBytes { raw in
                    sendto(sock, raw.baseAddress, snmpPacket.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }
        
        var buffer = [UInt8](repeating: 0, count: 512)
        var srcAddr = sockaddr_in()
        var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let readLen = withUnsafeMutablePointer(to: &srcAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &buffer, buffer.count, 0, sa, &srcLen)
            }
        }
        guard readLen > 20 else { return nil }
        
        // Trích xuất chuỗi mô tả trả về
        if let ascii = String(bytes: buffer[20..<readLen], encoding: .ascii) {
            let cleaned = ascii.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0.isWhitespace || $0.isPunctuation) }
            if cleaned.count > 5 {
                return cleaned
            }
        }
        return nil
    }
    
    // MARK: - TCP Port Probe
    private func probeTCPPort(ipAddress: String, port: Int, timeout: TimeInterval) async -> (isOpen: Bool, rttMs: Double?) {
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return (false, nil)
        }
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ipAddress), port: nwPort)
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            let timer = DispatchSource.makeTimerSource()
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: (false, nil))
                }
            }
            timer.resume()
            
            connection.stateUpdateHandler = { state in
                guard !hasResumed else { return }
                switch state {
                case .ready:
                    hasResumed = true
                    timer.cancel()
                    let rtt = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    connection.cancel()
                    continuation.resume(returning: (true, rtt))
                case .failed:
                    // Connection refused = Host exists but port closed
                    hasResumed = true
                    timer.cancel()
                    connection.cancel()
                    continuation.resume(returning: (false, nil))
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }
}

/// Helper phân giải ngược DNS PTR và tên máy cục bộ
public enum HostNameResolver {
    public static func getDeviceName() -> String {
        return ProcessInfo.processInfo.hostName
    }
    
    public static func reverseLookup(ipAddress: String) -> String? {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        inet_pton(AF_INET, ipAddress, &addr.sin_addr)
        
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let res = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getnameinfo(sa, socklen_t(MemoryLayout<sockaddr_in>.size), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NAMEREQD)
            }
        }
        
        if res == 0 {
            let name = String(cString: hostBuffer)
            return name != ipAddress ? name : nil
        }
        return nil
    }
}
