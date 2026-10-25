//
//  LocationAndWiFiManager.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import CoreLocation
import NetworkExtension
import Combine

/// Trạng thái thu thập thông tin Wi-Fi (SSID, BSSID)
public enum WiFiStatus: Equatable, Sendable {
    case idle
    case loading
    case connected(ssid: String, bssid: String, signalStrength: Double?)
    case notConnectedToWiFi
    case locationPermissionNeeded
    case locationPermissionDenied
    case restrictedOrUnavailable(reason: String)
}

/// Quản lý quyền Vị trí và truy xuất SSID/BSSID thông qua NEHotspotNetwork
@MainActor
public final class LocationAndWiFiManager: NSObject, ObservableObject {
    public static let shared = LocationAndWiFiManager()
    
    @Published public private(set) var status: WiFiStatus = .idle
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public private(set) var currentSSID: String? = nil
    @Published public private(set) var currentBSSID: String? = nil
    @Published public private(set) var isLocationAuthorized: Bool = false
    
    private let locationManager = CLLocationManager()
    
    public override init() {
        super.init()
        self.locationManager.delegate = self
        self.authorizationStatus = locationManager.authorizationStatus
        self.updateAuthorizationFlags()
    }
    
    /// Yêu cầu quyền vị trí khi sử dụng ứng dụng (bắt buộc để đọc SSID/BSSID trên iOS)
    public func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Làm mới thông tin mạng Wi-Fi hiện tại
    public func refreshWiFiInfo() async {
        status = .loading
        
        // Kiểm tra xem máy có đang kết nối Wi-Fi hay không
        let wifiInterface = NetworkInterfaceProvider.getPrimaryWiFiInterface()
        guard wifiInterface?.ipv4Address != nil else {
            status = .notConnectedToWiFi
            currentSSID = nil
            currentBSSID = nil
            return
        }
        
        // Kiểm tra quyền vị trí
        let auth = locationManager.authorizationStatus
        guard auth == .authorizedWhenInUse || auth == .authorizedAlways else {
            if auth == .notDetermined {
                status = .locationPermissionNeeded
            } else {
                status = .locationPermissionDenied
            }
            return
        }
        
        // Gọi NEHotspotNetwork.fetchCurrent
        let network = await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { currentNetwork in
                continuation.resume(returning: currentNetwork)
            }
        }
        
        if let network = network {
            let ssid = network.ssid
            let bssid = network.bssid
            let signal = network.signalStrength > 0 ? network.signalStrength : nil
            
            self.currentSSID = ssid
            self.currentBSSID = bssid
            self.status = .connected(ssid: ssid, bssid: bssid, signalStrength: signal)
        } else {
            // Trường hợp fetchCurrent trả về nil dù đang trên Wi-Fi và đã có quyền vị trí:
            // Nguyên nhân: App chưa được cấp Entitlement "Access Wi-Fi Information"
            // hoặc chạy trên Simulator không hỗ trợ phần cứng Wi-Fi thật.
            self.currentSSID = nil
            self.currentBSSID = nil
            self.status = .restrictedOrUnavailable(
                reason: String(localized: "wifi.restricted_ssid_reason", defaultValue: "iOS giới hạn truy cập SSID: Cần bật Entitlement 'Access Wi-Fi Information' trong Apple Developer Portal hoặc đang chạy trên Simulator.")
            )
        }
    }
    
    private func updateAuthorizationFlags() {
        let auth = locationManager.authorizationStatus
        self.authorizationStatus = auth
        self.isLocationAuthorized = (auth == .authorizedWhenInUse || auth == .authorizedAlways)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationAndWiFiManager: CLLocationManagerDelegate {
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.updateAuthorizationFlags()
            await self.refreshWiFiInfo()
        }
    }
}
