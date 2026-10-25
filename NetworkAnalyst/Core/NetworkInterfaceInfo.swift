//
//  NetworkInterfaceInfo.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
#if canImport(Darwin)
import Darwin
#endif

/// Đại diện cho thông tin cấu hình giao diện mạng (IPv4, IPv6, Subnet, Gateway)
public struct NetworkInterfaceDetails: Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let ipv4Address: String?
    public let netmask: String?
    public var subnetMask: String? { netmask }
    public let broadcastAddress: String?
    public let ipv6Address: String?
    public let gateway: String?
    public let isWiFi: Bool
    public let isCellular: Bool
    public let isLoopback: Bool
    public let isUp: Bool
    public let isRunning: Bool
    
    public init(
        name: String,
        ipv4Address: String? = nil,
        netmask: String? = nil,
        broadcastAddress: String? = nil,
        ipv6Address: String? = nil,
        gateway: String? = nil,
        isWiFi: Bool = false,
        isCellular: Bool = false,
        isLoopback: Bool = false,
        isUp: Bool = true,
        isRunning: Bool = true
    ) {
        self.name = name
        self.ipv4Address = ipv4Address
        self.netmask = netmask
        self.broadcastAddress = broadcastAddress
        self.ipv6Address = ipv6Address
        self.gateway = gateway
        self.isWiFi = isWiFi
        self.isCellular = isCellular
        self.isLoopback = isLoopback
        self.isUp = isUp
        self.isRunning = isRunning
    }
    
    /// Tính toán prefix length (CIDR ví dụ: /24) từ subnet mask
    public var cidrPrefix: Int? {
        guard let netmask = netmask else { return nil }
        let parts = netmask.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return nil }
        var count = 0
        for byte in parts {
            var b = byte
            while b > 0 {
                if b & 1 == 1 { count += 1 }
                b >>= 1
            }
        }
        return count
    }
    
    /// Dải địa chỉ IP có thể quét trong mạng cục bộ (ví dụ: 192.168.1.1 ... 192.168.1.254)
    public var subnetHostRange: [String] {
        guard let ipStr = ipv4Address, let maskStr = netmask else { return [] }
        guard let ip = IPv4Address(ipStr), let mask = IPv4Address(maskStr) else { return [] }
        
        let ipUint = ip.toUInt32()
        let maskUint = mask.toUInt32()
        let networkUint = ipUint & maskUint
        let broadcastUint = networkUint | (~maskUint)
        
        guard broadcastUint > networkUint + 1 else { return [] }
        
        // Giới hạn an toàn tối đa 512 hosts để tránh tràn bộ nhớ nếu subnet lớn hơn /24
        let firstHost = networkUint + 1
        let lastHost = broadcastUint - 1
        let count = min(lastHost - firstHost + 1, 512)
        
        var hosts: [String] = []
        hosts.reserveCapacity(Int(count))
        for i in 0..<count {
            let hostUint = firstHost + i
            hosts.append(IPv4Address.fromUInt32(hostUint))
        }
        return hosts
    }
}

/// Helper biểu diễn IPv4 số học
public struct IPv4Address: Sendable {
    public let octets: (UInt8, UInt8, UInt8, UInt8)
    
    public init?(_ string: String) {
        let parts = string.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return nil }
        self.octets = (parts[0], parts[1], parts[2], parts[3])
    }
    
    public init(octets: (UInt8, UInt8, UInt8, UInt8)) {
        self.octets = octets
    }
    
    public func toUInt32() -> UInt32 {
        return (UInt32(octets.0) << 24) |
               (UInt32(octets.1) << 16) |
               (UInt32(octets.2) << 8) |
               UInt32(octets.3)
    }
    
    public static func fromUInt32(_ value: UInt32) -> String {
        let o1 = UInt8((value >> 24) & 0xFF)
        let o2 = UInt8((value >> 16) & 0xFF)
        let o3 = UInt8((value >> 8) & 0xFF)
        let o4 = UInt8(value & 0xFF)
        return "\(o1).\(o2).\(o3).\(o4)"
    }
}

/// Utility lấy thông tin mạng POSIX (getifaddrs) và Default Gateway
public typealias NetworkInterfaceInfo = NetworkInterfaceProvider

public enum NetworkInterfaceProvider {
    
    /// Lấy danh sách toàn bộ các interface đang hoạt động
    public static func getAllInterfaces() -> [NetworkInterfaceDetails] {
        var interfacesDict: [String: (ipv4: String?, mask: String?, bcast: String?, ipv6: String?, flags: UInt32)] = [:]
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return []
        }
        defer { freeifaddrs(ifaddr) }
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            
            guard let addr = current.pointee.ifa_addr else { continue }
            let name = String(cString: current.pointee.ifa_name)
            let flags = current.pointee.ifa_flags
            
            var entry = interfacesDict[name] ?? (ipv4: nil, mask: nil, bcast: nil, ipv6: nil, flags: flags)
            entry.flags = flags
            
            let family = addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    entry.ipv4 = String(cString: hostname)
                }
                
                if let netmask = current.pointee.ifa_netmask {
                    var maskname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(netmask, socklen_t(netmask.pointee.sa_len), &maskname, socklen_t(maskname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        entry.mask = String(cString: maskname)
                    }
                }
                
                if let dstaddr = current.pointee.ifa_dstaddr {
                    var bcastname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(dstaddr, socklen_t(dstaddr.pointee.sa_len), &bcastname, socklen_t(bcastname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        entry.bcast = String(cString: bcastname)
                    }
                }
            } else if family == UInt8(AF_INET6) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let fullIPv6 = String(cString: hostname)
                    // Bỏ tiền tố scope ID %en0 nếu có
                    entry.ipv6 = fullIPv6.components(separatedBy: "%").first
                }
            }
            interfacesDict[name] = entry
        }
        
        // Heuristic default gateway derived directly from Wi-Fi entry in interfacesDict
        var defaultGateway: String? = nil
        for (name, data) in interfacesDict {
            let isLoopback = (data.flags & UInt32(IFF_LOOPBACK)) != 0
            if name.hasPrefix("en") && !isLoopback, let ip = data.ipv4 {
                let parts = ip.split(separator: ".")
                if parts.count == 4 {
                    defaultGateway = "\(parts[0]).\(parts[1]).\(parts[2]).1"
                    break
                }
            }
        }
        
        var result: [NetworkInterfaceDetails] = []
        for (name, data) in interfacesDict {
            let isUp = (data.flags & UInt32(IFF_UP)) != 0
            let isRunning = (data.flags & UInt32(IFF_RUNNING)) != 0
            let isLoopback = (data.flags & UInt32(IFF_LOOPBACK)) != 0
            let isWiFi = name.hasPrefix("en") && !isLoopback
            let isCellular = name.hasPrefix("pdp_ip")
            
            let gateway = isWiFi ? defaultGateway : nil
            
            result.append(
                NetworkInterfaceDetails(
                    name: name,
                    ipv4Address: data.ipv4,
                    netmask: data.mask,
                    broadcastAddress: data.bcast,
                    ipv6Address: data.ipv6,
                    gateway: gateway,
                    isWiFi: isWiFi,
                    isCellular: isCellular,
                    isLoopback: isLoopback,
                    isUp: isUp,
                    isRunning: isRunning
                )
            )
        }
        
        // Sắp xếp: ưu tiên Wi-Fi (en0), rồi Cellular, rồi các interface khác
        return result.sorted {
            if $0.isWiFi && !$1.isWiFi { return true }
            if !$0.isWiFi && $1.isWiFi { return false }
            return $0.name < $1.name
        }
    }
    
    /// Lấy thông tin giao diện Wi-Fi chính (thường là en0)
    public static func getPrimaryWiFiInterface() -> NetworkInterfaceDetails? {
        let all = getAllInterfaces()
        return all.first { $0.isWiFi && $0.ipv4Address != nil && $0.isUp } ?? all.first { $0.isWiFi }
    }
    
    /// Tìm Default Gateway IP bằng heuristic từ Wi-Fi subnet
    public static func getDefaultGateway() -> String? {
        return getPrimaryWiFiInterface()?.gateway
    }
}
