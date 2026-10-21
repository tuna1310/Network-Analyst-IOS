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
    case notDetermined = "Chưa xác định"
    case granted = "Đã cấp quyền"
    case denied = "Bị từ chối"
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
                case .failed(let error):
                    // Mã lỗi -65565 là kDNSServiceErr_PolicyDenied khi người dùng từ chối quyền Local Network
                    if error.errorCode == -65565 || error.errorCode == 1 {
                        self.status = .denied
                    }
                    self.browser?.cancel()
                    self.browser = nil
                case .cancelled:
                    break
                default:
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
}
