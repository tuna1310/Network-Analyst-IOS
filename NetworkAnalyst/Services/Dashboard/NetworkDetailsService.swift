//
//  NetworkDetailsService.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import CoreLocation
import NetworkExtension
#if canImport(CoreTelephony)
import CoreTelephony
#endif
import Darwin
import NetworkCore

/// Thông tin toàn diện về mạng hiện tại phục vụ hiển thị chi tiết
public struct ComprehensiveNetworkDetails: Sendable {
    // Wi-Fi Info
    public var ssid: String?
    public var bssid: String?
    public var bssidVendor: String?
    public var wifiSecurity: String?
    public var isWiFiConnected: Bool = false
    
    // IP Configuration
    public var localIPv4: String?
    public var subnetMask: String?
    public var defaultGateway: String?
    public var dnsServers: [String] = []
    
    // Public IP (Độc lập IPv4 & IPv6)
    public var publicIPv4: String?
    public var publicIPv6: String?
    
    // Cellular Info
    public var carrierName: String?
    public var radioTechnology: String?
    
    // Interfaces List
    public var interfaces: [ClassifiedInterface] = []
    
    public init() {}
}

/// Actor chuyên thu thập tất cả các thông số mạng chi tiết
public actor NetworkDetailsService {
    public static let shared = NetworkDetailsService()
    
    private let urlSession: URLSession
    
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 5.0
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Thu thập toàn bộ thông tin chi tiết mạng
    public func fetchAllDetails() async -> ComprehensiveNetworkDetails {
        var details = ComprehensiveNetworkDetails()
        
        // 1. Phân loại và thu thập danh sách Interface từ kernel POSIX
        let classifiedInterfaces = fetchClassifiedInterfaces()
        details.interfaces = classifiedInterfaces
        
        // 2. Tìm interface Wi-Fi chính (en0)
        if let wifiIface = classifiedInterfaces.first(where: { $0.type == .wifi && $0.isUp }) {
            details.isWiFiConnected = true
            details.localIPv4 = wifiIface.ipv4Addresses.first
        }
        
        // 3. Subnet mask và Gateway từ NetworkInterfaceInfo
        if let primary = NetworkInterfaceInfo.getPrimaryWiFiInterface() {
            details.subnetMask = primary.netmask
            details.defaultGateway = primary.gateway ?? NetworkInterfaceInfo.getDefaultGateway()
        } else {
            details.defaultGateway = NetworkInterfaceInfo.getDefaultGateway()
        }
        
        // 4. Lấy danh sách DNS Resolvers hệ thống (kèm ghi chú deprecation)
        details.dnsServers = fetchSystemDNSServers(defaultGateway: details.defaultGateway)
        
        // 5. Thông tin Wi-Fi chuyên sâu (SSID, BSSID, Security)
        let wifi = await fetchWiFiNetworkExtensionInfo()
        details.ssid = wifi.ssid
        details.bssid = wifi.bssid
        details.wifiSecurity = wifi.security
        if let bssid = wifi.bssid {
            let vendorResult = OUIDatabase.shared.lookupDetail(mac: bssid)
            details.bssidVendor = vendorResult.displayName
        }
        
        // 6. Thông tin Cellular & Carrier
        let cellular = fetchCellularDetails()
        details.carrierName = cellular.carrier
        details.radioTechnology = cellular.radio
        
        // 7. Truy vấn Public IPv4 và IPv6 song song
        async let ipv4Task = fetchPublicIPv4()
        async let ipv6Task = fetchPublicIPv6()
        
        details.publicIPv4 = await ipv4Task
        details.publicIPv6 = await ipv6Task
        
        return details
    }
    
    // MARK: - Enumerate & Classify Interfaces
    private func fetchClassifiedInterfaces() -> [ClassifiedInterface] {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
            return []
        }
        defer { freeifaddrs(ifaddrPtr) }
        
        struct RawEntry {
            let flags: UInt32
            var ipv4: [String] = []
            var ipv6: [String] = []
        }
        
        var dict: [String: RawEntry] = [:]
        
        for current in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let name = String(cString: current.pointee.ifa_name)
            let flags = current.pointee.ifa_flags
            guard let addr = current.pointee.ifa_addr else { continue }
            
            var entry = dict[name] ?? RawEntry(flags: flags)
            let family = addr.pointee.sa_family
            
            if family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    if !entry.ipv4.contains(ip) {
                        entry.ipv4.append(ip)
                    }
                }
            } else if family == UInt8(AF_INET6) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let rawIPv6 = String(cString: hostname)
                    let clean = rawIPv6.components(separatedBy: "%").first ?? rawIPv6
                    // Bỏ qua link-local fe80:: nếu muốn hiển thị gọn
                    if !entry.ipv6.contains(clean) {
                        entry.ipv6.append(clean)
                    }
                }
            }
            
            dict[name] = entry
        }
        
        var results: [ClassifiedInterface] = []
        for (name, entry) in dict {
            let ifaceType = InterfaceClassifier.classify(
                name: name,
                flags: entry.flags,
                ipv4: entry.ipv4,
                ipv6: entry.ipv6
            )
            
            let isUp = (entry.flags & InterfaceClassifier.iffUp) != 0
            let isRunning = (entry.flags & InterfaceClassifier.iffRunning) != 0
            
            results.append(
                ClassifiedInterface(
                    name: name,
                    type: ifaceType,
                    isUp: isUp,
                    isRunning: isRunning,
                    ipv4Addresses: entry.ipv4,
                    ipv6Addresses: entry.ipv6
                )
            )
        }
        
        // Sắp xếp: Wi-Fi -> Cellular -> VPN -> Hotspot -> Ethernet -> Other -> Loopback
        return results.sorted { a, b in
            priority(for: a.type) < priority(for: b.type)
        }
    }
    
    private func priority(for type: NetworkInterfaceType) -> Int {
        switch type {
        case .wifi: return 0
        case .cellular: return 1
        case .vpn: return 2
        case .hotspot: return 3
        case .ethernet: return 4
        case .other: return 5
        case .loopback: return 6
        }
    }
    
    // MARK: - Wi-Fi via NEHotspotNetwork
    private func fetchWiFiNetworkExtensionInfo() async -> (ssid: String?, bssid: String?, security: String?) {
        guard let current = await NEHotspotNetwork.fetchCurrent() else {
            return (nil, nil, nil)
        }
        
        let ssid = current.ssid
        let bssid = current.bssid
        
        var secStr = "Unknown"
        if #available(iOS 15.0, *) {
            switch current.securityType {
            case .open: secStr = "Open (Không mật khẩu)"
            case .wep: secStr = "WEP"
            case .wpaPersonal: secStr = "WPA Personal"
            case .wpa2Personal: secStr = "WPA2 Personal"
            case .wpa3Personal: secStr = "WPA3 Personal"
            case .wpaEnterprise: secStr = "WPA Enterprise"
            case .wpa2Enterprise: secStr = "WPA2 Enterprise"
            case .wpa3Enterprise: secStr = "WPA3 Enterprise"
            case .unknown: secStr = "Không rõ"
            @unknown default: secStr = "Khác"
            }
        }
        
        return (ssid, bssid, secStr)
    }
    
    // MARK: - System DNS Resolvers
    /// Lấy danh sách DNS Resolvers hệ thống
    /// GHI CHÚ KỸ THUẬT QUAN TRỌNG:
    /// Trên iOS 16+, hàm `res_9_init` / `res_ninit` đã bị Apple đánh dấu Deprecated và có thể bị
    /// sandbox hạn chế không đọc được `/etc/resolv.conf`.
    /// Phương án triển khai: Thử đọc qua cấu trúc `res_state` POSIX Darwin; nếu không có kết quả,
    /// tự động dự phòng lấy IP Default Gateway (vốn là local DNS cache router trong 95% mô hình LAN).
    private func fetchSystemDNSServers(defaultGateway: String?) -> [String] {
        var servers: [String] = []
        
        #if !targetEnvironment(simulator)
        var state = __res_9_state()
        if res_9_ninit(&state) == 0 {
            let count = Int(state.nscount)
            for i in 0..<min(count, 3) {
                var addr = state.nsaddr_list.0
                if i == 1 { addr = state.nsaddr_list.1 }
                else if i == 2 { addr = state.nsaddr_list.2 }
                
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var sinAddr = addr.sin_addr
                if inet_ntop(AF_INET, &sinAddr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                    let ipStr = String(cString: buffer)
                    if !ipStr.isEmpty && ipStr != "0.0.0.0" && !servers.contains(ipStr) {
                        servers.append(ipStr)
                    }
                }
            }
            res_9_ndestroy(&state)
        }
        #endif
        
        // Nếu không đọc được từ POSIX state, dùng gateway làm DNS dự phòng
        if servers.isEmpty, let gw = defaultGateway, !gw.isEmpty {
            servers.append("\(gw) (Router DNS)")
        }
        
        return servers
    }
    
    // MARK: - Cellular Details
    private func fetchCellularDetails() -> (carrier: String?, radio: String?) {
        #if canImport(CoreTelephony)
        let networkInfo = CTTelephonyNetworkInfo()
        
        var carrierName: String? = nil
        var radioTech: String? = nil
        
        // Lưu ý: subscriberCellularProvider đã deprecate trên iOS 16, sử dụng serviceSubscriberCellularProviders
        if let providers = networkInfo.serviceSubscriberCellularProviders {
            for (_, provider) in providers {
                if let name = provider.carrierName, !name.isEmpty {
                    carrierName = name
                    break
                }
            }
        }
        
        if let radioDict = networkInfo.serviceCurrentRadioAccessTechnology {
            for (_, tech) in radioDict {
                switch tech {
                case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA:
                    radioTech = "5G (NR)"
                case CTRadioAccessTechnologyLTE:
                    radioTech = "4G (LTE)"
                case CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyWCDMA:
                    radioTech = "3G (HSPA/WCDMA)"
                case CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyGPRS:
                    radioTech = "2G (EDGE/GPRS)"
                default:
                    radioTech = tech.replacingOccurrences(of: "CTRadioAccessTechnology", with: "")
                }
                if radioTech != nil { break }
            }
        }
        
        return (carrierName, radioTech)
        #else
        return (nil, nil)
        #endif
    }
    
    // MARK: - Public IPv4 & IPv6 (Independent)
    private func fetchPublicIPv4() async -> String? {
        guard let url = URL(string: "https://api.ipify.org?format=text") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3.5
        do {
            let (data, resp) = try await urlSession.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let ip = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                if ip.split(separator: ".").count == 4 {
                    return ip
                }
            }
        } catch {}
        return nil
    }
    
    private func fetchPublicIPv6() async -> String? {
        guard let url = URL(string: "https://v6.ident.me") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3.5
        do {
            let (data, resp) = try await urlSession.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let ip = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                if ip.contains(":") {
                    return ip
                }
            }
        } catch {}
        return nil
    }
}
