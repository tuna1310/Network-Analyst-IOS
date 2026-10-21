//
//  NetworkAnalystApp.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

@main
struct NetworkAnalystApp: App {
    @StateObject private var adService = MockAdService.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView(adService: adService)
                .onAppear {
                    // Kích hoạt quan sát kết nối mạng
                    NetworkMonitor.shared.start()
                    
                    // Khởi tạo dịch vụ quảng cáo
                    adService.initialize()
                }
        }
    }
}
