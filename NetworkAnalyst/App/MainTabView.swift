//
//  MainTabView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// Main 4-tab layout matching Techet Network Analyzer (Info, LAN, Tools, History)
public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var selectedToolTab: Int = 0
    @StateObject private var lanViewModel = LanScannerViewModel()
    @StateObject private var portViewModel = PortScannerViewModel()
    @ObservedObject public var adService: MockAdService
    
    public init(adService: MockAdService = .shared) {
        self.adService = adService
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Info", systemImage: "info.circle.fill")
                }
                .tag(0)
            
            LanScannerView(viewModel: lanViewModel) { targetIP in
                portViewModel.targetHost = targetIP
                selectedToolTab = 1
                selectedTab = 2
            }
            .tabItem {
                Label("LAN", systemImage: "network")
            }
            .tag(1)
            
            ToolsHubView(selectedToolTab: $selectedToolTab, portViewModel: portViewModel)
                .tabItem {
                    Label("Tools", systemImage: "wrench.and.screwdriver.fill")
                }
                .tag(2)
            
            NavigationStack {
                ScanHistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(3)
        }
    }
}

private struct ToolsHubView: View {
    @Binding var selectedToolTab: Int
    @ObservedObject var portViewModel: PortScannerViewModel

    private let toolTabs = [
        (0, "Ping / Trace"),
        (1, "Port Scan"),
        (2, "DNS"),
        (3, "Whois")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tool", selection: $selectedToolTab) {
                ForEach(toolTabs, id: \.0) { index, title in
                    Text(title).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemBackground))

            Divider()

            Group {
                switch selectedToolTab {
                case 0:
                    PingTracerouteView()
                case 1:
                    PortScannerView(viewModel: portViewModel)
                case 2:
                    DNSLookupView()
                default:
                    RDAPLookupView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
