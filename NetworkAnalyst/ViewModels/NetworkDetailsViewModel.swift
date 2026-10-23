//
//  NetworkDetailsViewModel.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import SwiftUI
import NetworkCore

@MainActor
public final class NetworkDetailsViewModel: ObservableObject {
    @Published public var details = ComprehensiveNetworkDetails()
    @Published public var isLoading: Bool = false
    
    // Toast notification
    @Published public var showToast: Bool = false
    @Published public var toastMessage: String = ""
    
    public init() {}
    
    /// Nạp và làm mới toàn bộ thông số mạng chi tiết
    public func loadDetails() async {
        isLoading = true
        let fetched = await NetworkDetailsService.shared.fetchAllDetails()
        self.details = fetched
        isLoading = false
    }
    
    /// Sao chép giá trị và kích hoạt Toast thông báo
    public func copyToClipboard(value: String, label: String) {
        guard !value.isEmpty, value != "--" else { return }
        UIPasteboard.general.string = value
        
        let format = String(localized: "details.copied_toast", defaultValue: "Đã sao chép: %@")
        toastMessage = String(format: format, value)
        showToast = true
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showToast = false
        }
    }
}
