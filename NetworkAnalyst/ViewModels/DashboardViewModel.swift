//
//  DashboardViewModel.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine
import CoreLocation

/// ViewModel quản lý dữ liệu bảng tin mạng tổng quan Dashboard
@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public var primaryInterface: NetworkInterfaceDetails?
    @Published public var allInterfaces: [NetworkInterfaceDetails] = []
    @Published public var wifiSSID: String?
    @Published public var wifiBSSID: String?
    @Published public var wifiStatus: WiFiStatus = .idle
    @Published public var publicIPDetails: PublicIPDetails?
    @Published public var isLoadingPublicIP: Bool = false
    @Published public var isRefreshing: Bool = false
    @Published public var gatewayPingRTT: Double?
    @Published public var internetPingRTT: Double?
    @Published public var localNetworkPermissionStatus: LocalNetworkAuthorizationStatus = .notDetermined
    
    public let networkMonitor = NetworkMonitor.shared
    public let wifiManager = LocationAndWiFiManager.shared
    public let localPermissionManager = LocalNetworkPermissionManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupBindings()
    }
    
    private func setupBindings() {
        wifiManager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.wifiStatus = status
                if case .connected(let ssid, let bssid, _) = status {
                    self?.wifiSSID = ssid
                    self?.wifiBSSID = bssid
                }
            }
            .store(in: &cancellables)
        
        localPermissionManager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.localNetworkPermissionStatus = status
            }
            .store(in: &cancellables)
    }
    
    /// Làm mới toàn bộ thông tin hệ thống mạng
    public func refresh() async {
        isRefreshing = true
        
        // 1. Giao diện mạng POSIX
        self.allInterfaces = NetworkInterfaceProvider.getAllInterfaces()
        self.primaryInterface = NetworkInterfaceProvider.getPrimaryWiFiInterface()
        
        // 2. Wi-Fi SSID / BSSID
        await wifiManager.refreshWiFiInfo()
        
        // 3. Public IP & ISP qua URLSession
        await fetchPublicIP()
        
        // 4. Quick Latency Check (Gateway & 1.1.1.1)
        await testQuickLatencies()
        
        isRefreshing = false
    }
    
    public func fetchPublicIP() async {
        isLoadingPublicIP = true
        do {
            let details = try await PublicIPService.shared.fetchPublicIP()
            self.publicIPDetails = details
        } catch {
            self.publicIPDetails = nil
        }
        isLoadingPublicIP = false
    }
    
    private func testQuickLatencies() async {
        let icmp = ICMPEngine()
        
        // Ping Gateway
        if let gw = primaryInterface?.gateway ?? NetworkInterfaceProvider.getDefaultGateway() {
            let res = await icmp.pingOnce(to: gw, sequence: 1, timeout: 0.6)
            self.gatewayPingRTT = res.rttMs
        }
        
        // Ping Cloudflare DNS
        let inetRes = await icmp.pingOnce(to: "1.1.1.1", sequence: 1, timeout: 0.8)
        self.internetPingRTT = inetRes.rttMs
    }
    
    public func requestLocationPermission() {
        wifiManager.requestLocationAuthorization()
    }
    
    public func requestLocalNetworkPermission() {
        localPermissionManager.requestAuthorization()
    }
}
