//
//  DashboardView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI
import NetworkCore

/// Màn hình Tổng quan mạng (Dashboard)
public struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Cảnh báo nếu quyền Local Network bị từ chối
                    if viewModel.localNetworkPermissionStatus == .denied {
                        PermissionAlertBanner(
                            icon: "hand.raised.slash.fill",
                            title: "Quyền Mạng Cục Bộ Bị Chặn",
                            message: "iOS yêu cầu cấp quyền Mạng cục bộ (Local Network) để tìm thấy các thiết bị khác trong Wi-Fi và đo đạc cổng.",
                            actionTitle: "Mở Cài đặt hệ thống",
                            action: { viewModel.localPermissionManager.openSettings() }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Card Kết nối Wi-Fi & Trạng thái chính
                    wifiStatusCard
                        .padding(.horizontal)
                    
                    // Card Thông số mạng cục bộ (LAN Parameters)
                    localNetworkCard
                        .padding(.horizontal)
                    
                    // Card IP công khai & ISP
                    publicNetworkCard
                        .padding(.horizontal)
                    
                    // Card Độ trễ tức thời (Quick Latencies)
                    latencyGaugeCard
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Tổng quan mạng")
            .background(Color(uiColor: .systemGroupedBackground))
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.refresh()
            }
        }
    }
    
    // MARK: - Wi-Fi Status Card
    private var wifiStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: viewModel.networkMonitor.isWiFi ? "wifi" : (viewModel.networkMonitor.isCellular ? "antenna.radiowaves.left.and.right" : "network"))
                    .font(.system(size: 24))
                    .foregroundColor(viewModel.networkMonitor.isConnected ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.networkMonitor.statusDescription)
                        .font(.headline)
                    Text(viewModel.networkMonitor.isConnected ? "Trạng thái: Hoạt động bình thường" : "Chưa kết nối Internet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                        .animation(viewModel.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                }
            }
            
            Divider()
            
            // Chi tiết SSID / BSSID
            if viewModel.networkMonitor.isWiFi {
                if let ssid = viewModel.wifiSSID, !ssid.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tên mạng (SSID)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ssid)
                                .font(.subheadline.bold())
                        }
                        Spacer()
                        if let bssid = viewModel.wifiBSSID {
                            VStack(alignment: .trailing, spacing: 4) {
                                let vendor = OUIDatabase.shared.lookup(mac: bssid)
                                Text(vendor != nil ? "\(vendor!) (BSSID)" : "BSSID (MAC Router)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Text(bssid)
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                } else {
                    // Giải thích nguyên nhân không lấy được SSID trên iOS
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Thông tin SSID/BSSID được iOS bảo vệ:")
                                .font(.footnote.bold())
                        }
                        
                        switch viewModel.wifiStatus {
                        case .locationPermissionNeeded, .locationPermissionDenied:
                            Text("iOS yêu cầu quyền 'Vị trí khi dùng' để hiển thị tên Wi-Fi (SSID).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button {
                                viewModel.requestLocationPermission()
                            } label: {
                                Text("Cấp quyền Vị trí")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                            }
                            
                        case .restrictedOrUnavailable(let reason):
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        default:
                            Text("Đang kiểm tra thông tin điểm truy cập Wi-Fi...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Local Network Card
    private var localNetworkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CẤU HÌNH MẠNG CỤC BỘ (LAN)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            let iface = viewModel.primaryInterface
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricItemCard(
                    icon: "iphone",
                    iconColor: .blue,
                    title: "IP Thiết bị",
                    value: iface?.ipv4Address ?? "Đang tải...",
                    subtitle: iface != nil ? "Giao diện \(iface!.name)" : nil
                )
                
                MetricItemCard(
                    icon: "wifi.router",
                    iconColor: .green,
                    title: "Gateway (Router)",
                    value: iface?.gateway ?? "192.168.1.1",
                    subtitle: "Cổng mặc định"
                )
                
                MetricItemCard(
                    icon: "square.grid.3x3.fill",
                    iconColor: .purple,
                    title: "Subnet Mask",
                    value: iface?.netmask ?? "255.255.255.0",
                    subtitle: iface?.cidrPrefix != nil ? "Prefix: /\(iface!.cidrPrefix!)" : nil
                )
                
                MetricItemCard(
                    icon: "antenna.radiowaves.left.and.right",
                    iconColor: .orange,
                    title: "Broadcast IP",
                    value: iface?.broadcastAddress ?? "--",
                    subtitle: "Quảng bá cục bộ"
                )
            }
            
            if let ipv6 = iface?.ipv6Address, !ipv6.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Địa chỉ IPv6 nội bộ:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ipv6)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Public Network Card
    private var publicNetworkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INTERNET & IP CÔNG KHAI")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.isLoadingPublicIP {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let pub = viewModel.publicIPDetails {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Địa chỉ IP Công khai (Public IP)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(pub.ip)
                                .font(.title3.bold().monospaced())
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        if let cc = pub.countryCode {
                            Text(cc)
                                .font(.headline.bold())
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    Divider()
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nhà mạng (ISP / ASN)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(pub.org ?? "Không rõ")
                                .font(.caption.bold())
                                .lineLimit(2)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vị trí địa lý")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(pub.city ?? ""), \(pub.country ?? "")")
                                .font(.caption.bold())
                                .lineLimit(2)
                        }
                    }
                }
            } else {
                HStack {
                    Text("Đang tra cứu thông tin địa chỉ IP công khai...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Quick Latency Card
    private var latencyGaugeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KIỂM TRA ĐỘ TRỄ NHANH (ICMP)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "wifi.router")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("Router Gateway")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.gatewayPingRTT != nil ? String(format: "%.1f ms", viewModel.gatewayPingRTT!) : "--")
                            .font(.subheadline.bold().monospaced())
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)
                
                HStack {
                    Image(systemName: "globe.asia.australia.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Cloudflare (1.1.1.1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.internetPingRTT != nil ? String(format: "%.1f ms", viewModel.internetPingRTT!) : "--")
                            .font(.subheadline.bold().monospaced())
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}
