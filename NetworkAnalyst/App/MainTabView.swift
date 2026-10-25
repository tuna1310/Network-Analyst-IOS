//
//  MainTabView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// TabView chính chứa 5 chức năng cốt lõi và thanh Banner quảng cáo cố định ở chân trang
public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @StateObject private var lanViewModel = LanScannerViewModel()
    @StateObject private var portViewModel = PortScannerViewModel()
    @ObservedObject public var adService: MockAdService
    
    public init(adService: MockAdService = .shared) {
        self.adService = adService
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label(String(localized: "tab.dashboard", defaultValue: "Tổng quan"), systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(0)
                
                LanScannerView(viewModel: lanViewModel) { targetIP in
                    // Chuyển sang Tab Quét cổng với IP được chọn
                    portViewModel.targetHost = targetIP
                    selectedTab = 2
                }
                .tabItem {
                    Label(String(localized: "tab.lan_scanner", defaultValue: "Quét LAN"), systemImage: "network")
                }
                .tag(1)
                
                PortScannerView(viewModel: portViewModel)
                    .tabItem {
                        Label(String(localized: "tab.port_scanner", defaultValue: "Quét cổng"), systemImage: "lock.open.trianglebadge.exclamationmark")
                    }
                    .tag(2)
                
                PingTracerouteView()
                    .tabItem {
                        Label(String(localized: "tab.ping_traceroute", defaultValue: "Ping ICMP"), systemImage: "waveform.path.ecg")
                    }
                    .tag(3)
                
                DNSLookupView()
                    .tabItem {
                        Label(String(localized: "tab.dns_rdap", defaultValue: "DNS & RDAP"), systemImage: "globe")
                    }
                    .tag(4)
            }
            
            // Khung Banner quảng cáo ở chân trang (MockAdView hoặc Google Mobile Ads Banner)
            AdBannerContainerView(adService: adService)
        }
        .fullScreenCover(isPresented: $adService.showInterstitialModal) {
            MockInterstitialView(adService: adService)
        }
    }
}
