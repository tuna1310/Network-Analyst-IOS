//
//  InterfaceClassifier.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Phân loại giao diện mạng trên hệ điều hành Darwin/iOS
public enum NetworkInterfaceType: Sendable, Codable, Equatable {
    case wifi
    case cellular
    case vpn
    case hotspot
    case ethernet
    case loopback
    case other(String)
    
    public var displayName: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .vpn: return "VPN"
        case .hotspot: return "Hotspot / Bridge"
        case .ethernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other(let name): return name
        }
    }
    
    public var iconName: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .vpn: return "lock.shield.fill"
        case .hotspot: return "personalhotspot"
        case .ethernet: return "cable.connector"
        case .loopback: return "arrow.triangle.2.circlepath"
        case .other: return "network"
        }
    }
}

/// Mô hình biểu diễn giao diện mạng đã được phân loại
public struct ClassifiedInterface: Sendable, Codable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let type: NetworkInterfaceType
    public let isUp: Bool
    public let isRunning: Bool
    public let ipv4Addresses: [String]
    public let ipv6Addresses: [String]
    
    public init(
        name: String,
        type: NetworkInterfaceType,
        isUp: Bool,
        isRunning: Bool,
        ipv4Addresses: [String] = [],
        ipv6Addresses: [String] = []
    ) {
        self.name = name
        self.type = type
        self.isUp = isUp
        self.isRunning = isRunning
        self.ipv4Addresses = ipv4Addresses
        self.ipv6Addresses = ipv6Addresses
    }
    
    public var allAddresses: [String] {
        ipv4Addresses + ipv6Addresses
    }
}

/// Bộ phân loại logic giao diện mạng theo quy ước kernel Darwin (iOS)
public enum InterfaceClassifier {
    
    // POSIX net/if.h flags bitmasks
    public static let iffUp: UInt32 = 0x1
    public static let iffBroadcast: UInt32 = 0x2
    public static let iffLoopback: UInt32 = 0x8
    public static let iffRunning: UInt32 = 0x40
    
    /// Phân loại loại giao diện dựa trên tên giao diện, flags POSIX và danh sách IP được gán
    /// Quy tắc:
    /// - en0: Wi-Fi
    /// - pdp_ip*: Cellular
    /// - utun*, ipsec*, ppp*, tun*: CHỈ coi là VPN nếu giao diện đang UP và CÓ ÍT NHẤT một IP được gán
    /// - bridge*, ap*: Hotspot / Bridge
    /// - en* (khác en0): Ethernet adapter (cắm qua cổng Lightning/USB-C)
    /// - lo0 / IFF_LOOPBACK: Loopback
    public static func classify(
        name: String,
        flags: UInt32,
        ipv4: [String] = [],
        ipv6: [String] = []
    ) -> NetworkInterfaceType {
        let isLoopback = (flags & iffLoopback) != 0 || name.hasPrefix("lo")
        if isLoopback {
            return .loopback
        }
        
        let isUp = (flags & iffUp) != 0
        let hasAssignedIP = !ipv4.isEmpty || !ipv6.isEmpty
        
        // 1. Wi-Fi: trên iOS luôn là en0
        if name == "en0" {
            return .wifi
        }
        
        // 2. Cellular: pdp_ip0, pdp_ip1, ...
        if name.hasPrefix("pdp_ip") {
            return .cellular
        }
        
        // 3. VPN: utun*, ipsec*, ppp*, tun*
        // RÀNG BUỘC NGHIÊM NGẶT: Chỉ gắn nhãn VPN khi giao diện đang UP và CÓ IP được gán thực tế
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") || name.hasPrefix("tun") {
            if isUp && hasAssignedIP {
                return .vpn
            } else {
                return .other(name)
            }
        }
        
        // 4. Hotspot / Bridge: bridge*, ap*
        if name.hasPrefix("bridge") || name.hasPrefix("ap") {
            return .hotspot
        }
        
        // 5. Ethernet: en1, en2, ... (các adapter gắn ngoài qua cổng USB-C / Lightning)
        if name.hasPrefix("en") && name != "en0" {
            return .ethernet
        }
        
        return .other(name)
    }
}
