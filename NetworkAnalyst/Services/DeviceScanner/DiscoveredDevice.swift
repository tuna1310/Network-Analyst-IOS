//
//  DiscoveredDevice.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import NetworkCore

/// Phân loại loại thiết bị trong mạng
public enum DeviceType: String, Sendable, CaseIterable {
    case router = "router"
    case appleDevice = "appleDevice"
    case windows = "windows"
    case linuxServer = "linuxServer"
    case nas = "nas"
    case printer = "printer"
    case smartTV = "smartTV"
    case iot = "iot"
    case mobile = "mobile"
    case unknown = "unknown"
    
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
    
    public var displayName: String {
        switch self {
        case .router: return String(localized: "device.type.router", defaultValue: "Router / Gateway")
        case .appleDevice: return String(localized: "device.type.apple", defaultValue: "Apple Device")
        case .windows: return String(localized: "device.type.windows", defaultValue: "Windows PC")
        case .linuxServer: return String(localized: "device.type.linux", defaultValue: "Linux / Server")
        case .nas: return String(localized: "device.type.nas", defaultValue: "NAS Storage")
        case .printer: return String(localized: "device.type.printer", defaultValue: "Máy in mạng")
        case .smartTV: return String(localized: "device.type.tv", defaultValue: "Smart TV / Media")
        case .iot: return String(localized: "device.type.iot", defaultValue: "Thiết bị IoT / Smarthome")
        case .mobile: return String(localized: "device.type.mobile", defaultValue: "Điện thoại / Tablet")
        case .unknown: return String(localized: "device.type.unknown", defaultValue: "Thiết bị mạng")
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
    case ptr = "DNS PTR"
    case localInterface
    
    public var displayName: String {
        switch self {
        case .icmp: return "ICMP Ping"
        case .tcp: return "TCP Probe"
        case .bonjour: return "Bonjour / mDNS"
        case .netbios: return "NetBIOS"
        case .llmnr: return "LLMNR"
        case .snmp: return "SNMP"
        case .ptr: return "DNS PTR"
        case .localInterface: return String(localized: "lan.device_self", defaultValue: "Thiết bị này")
        }
    }
}

/// Đại diện cho một thiết bị phát hiện được trên mạng LAN
public struct DiscoveredDevice: Identifiable, Sendable, Equatable {
    public var id: String { ipAddress }
    public let ipAddress: String
    public var ipv6Address: String?
    public var ipv6StatusExplanation: String?
    public var hostname: String?
    public var hostnameSource: HostnameSource?
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
        ipv6Address: String? = nil,
        ipv6StatusExplanation: String? = nil,
        hostname: String? = nil,
        hostnameSource: HostnameSource? = nil,
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
        self.ipv6Address = ipv6Address
        self.ipv6StatusExplanation = ipv6StatusExplanation ?? (ipv6Address == nil ? String(localized: "lan.no_ipv6_explanation", defaultValue: "Không có địa chỉ IPv6 (Router hoặc thiết bị không kích hoạt IPv6)") : nil)
        self.hostname = hostname
        self.hostnameSource = hostnameSource
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
            let format = String(localized: "lan.device_gateway_format", defaultValue: "Gateway / Router (%@)")
            return String(format: format, ipAddress)
        }
        if isSelf {
            let format = String(localized: "lan.device_self_format", defaultValue: "Thiết bị này (%@)")
            return String(format: format, ipAddress)
        }
        return ipAddress
    }
}
