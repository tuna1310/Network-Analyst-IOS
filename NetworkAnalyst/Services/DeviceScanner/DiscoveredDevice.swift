//
//  DiscoveredDevice.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Phân loại loại thiết bị trong mạng
public enum DeviceType: String, Sendable, CaseIterable {
    case router = "Router / Gateway"
    case appleDevice = "Apple Device"
    case windows = "Windows PC"
    case linuxServer = "Linux / Server"
    case nas = "NAS Storage"
    case printer = "Máy in mạng"
    case smartTV = "Smart TV / Media"
    case iot = "Thiết bị IoT / Smarthome"
    case mobile = "Điện thoại / Tablet"
    case unknown = "Thiết bị mạng"
    
    public var iconName: String {
        switch self {
        case .router: return "wifi.router"
        case .appleDevice: return "apple.logo"
        case .windows: return "desktopcomputer"
        case .linuxServer: return "server.rack"
        case .nas: return "internaldrive"
        case .printer: return "printer"
        case .smartTV: return "tv"
        case .iot: return "homekit"
        case .mobile: return "iphone"
        case .unknown: return "network"
        }
    }
}

/// Phương thức phát hiện thiết bị
public enum DiscoveryMethod: String, Sendable, CaseIterable {
    case icmp = "ICMP Ping"
    case tcp = "TCP Probe"
    case bonjour = "Bonjour / mDNS"
    case netbios = "NetBIOS (Port 137)"
    case llmnr = "LLMNR (Port 5355)"
    case snmp = "SNMP (Port 161)"
    case localInterface = "Thiết bị này"
}

/// Đại diện cho một thiết bị phát hiện được trên mạng LAN
public struct DiscoveredDevice: Identifiable, Sendable, Equatable {
    public var id: String { ipAddress }
    public let ipAddress: String
    public var hostname: String?
    public var macAddress: String?
    public var vendor: String?
    public var deviceType: DeviceType
    public var openPorts: [Int]
    public var bonjourServices: [String]
    public var rttMs: Double?
    public var isGateway: Bool
    public var isSelf: Bool
    public var discoveryMethods: [DiscoveryMethod]
    public var lastSeen: Date
    
    public init(
        ipAddress: String,
        hostname: String? = nil,
        macAddress: String? = nil,
        vendor: String? = nil,
        deviceType: DeviceType = .unknown,
        openPorts: [Int] = [],
        bonjourServices: [String] = [],
        rttMs: Double? = nil,
        isGateway: Bool = false,
        isSelf: Bool = false,
        discoveryMethods: [DiscoveryMethod] = [],
        lastSeen: Date = Date()
    ) {
        self.ipAddress = ipAddress
        self.hostname = hostname
        self.macAddress = macAddress
        self.vendor = vendor
        self.deviceType = deviceType
        self.openPorts = openPorts
        self.bonjourServices = bonjourServices
        self.rttMs = rttMs
        self.isGateway = isGateway
        self.isSelf = isSelf
        self.discoveryMethods = discoveryMethods
        self.lastSeen = lastSeen
    }
    
    public var displayName: String {
        if let host = hostname, !host.isEmpty {
            return host
        }
        if isGateway {
            return "Gateway / Router (\(ipAddress))"
        }
        if isSelf {
            return "Thiết bị này (\(ipAddress))"
        }
        return ipAddress
    }
}
