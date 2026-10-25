//
//  LocalNetworkPermissionManager.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network
import UIKit
import Combine

/// Trạng thái quyền truy cập Mạng cục bộ (Local Network Privacy)
public enum LocalNetworkAuthorizationStatus: String, Sendable {
    case notDetermined
    case granted
    case denied
    
    public var title: String {
        switch self {
        case .notDetermined:
            return String(localized: "permission.status.not_determined", defaultValue: "Chưa xác định")
        case .granted:
            return String(localized: "permission.status.granted", defaultValue: "Đã cấp quyền")
        case .denied:
            return String(localized: "permission.status.denied", defaultValue: "Bị từ chối")
        }
    }
}

/// Trình quản lý kiểm tra và hướng dẫn quyền Mạng Cục Bộ của iOS
@MainActor
public final class LocalNetworkPermissionManager: ObservableObject {
    public static let shared = LocalNetworkPermissionManager()
    
    @Published public private(set) var status: LocalNetworkAuthorizationStatus = .notDetermined
    @Published public var showPermissionAlert: Bool = false
    
    private var browser: NWBrowser?
    
    public init() {
        // Trạng thái ban đầu
    }
    
    /// Thử kích hoạt hộp thoại xin quyền Mạng cục bộ bằng NWBrowser
    public func requestAuthorization() {
        guard status != .granted else { return }
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: nil)
        let parameters = NWParameters()
        let browser = NWBrowser(for: descriptor, using: parameters)
        self.browser = browser
        
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.status = .granted
                    self.browser?.cancel()
                    self.browser = nil
                case .waiting(let error):
                    // Trên iOS 14+, khi người dùng chưa cấp quyền hoặc từ chối,
                    // NWBrowser thường chuyển sang trạng thái .waiting kèm lỗi chính sách (policy denied / EPERM).
                    if self.isPolicyDenied(error: error) {
                        self.status = .denied
                    }
                case .failed(let error):
                    // kDNSServiceErr_PolicyDenied (-65570) hoặc POSIX EPERM (1) khi từ chối quyền Local Network
                    if self.isPolicyDenied(error: error) {
                        self.status = .denied
                    }
                    self.browser?.cancel()
                    self.browser = nil
                case .cancelled:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        browser.start(queue: .main)
    }
    
    /// Mở Cài đặt hệ thống để người dùng bật lại quyền Mạng cục bộ
    public func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    /// Đánh dấu khi phát hiện lỗi từ chối quyền từ bất kỳ kết nối LAN nào
    public func markAsDenied() {
        self.status = .denied
        self.showPermissionAlert = true
    }
    
    public func markAsGranted() {
        self.status = .granted
        self.showPermissionAlert = false
    }
    
    /// Kiểm tra xem lỗi trả về từ Network.framework có phải do chính sách Local Network bị từ chối hay không
    private func isPolicyDenied(error: NWError) -> Bool {
        switch error {
        case .posix(let posixCode):
            // POSIX EPERM (1): Operation not permitted
            return posixCode == .EPERM
        case .dns(let dnsCode):
            // kDNSServiceErr_PolicyDenied = -65570
            // kDNSServiceErr_DefunctConnection = -65565
            return dnsCode == -65570 || dnsCode == -65565
        case .tls:
            return false
        @unknown default:
            return error.errorCode == -65570 || error.errorCode == 1
        }
    }
}
