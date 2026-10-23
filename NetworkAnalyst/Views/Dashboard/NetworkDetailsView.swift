//
//  NetworkDetailsView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI
import NetworkCore

/// Màn hình chi tiết toàn diện về thông số mạng, Wi-Fi, IP, Interface và Cellular
public struct NetworkDetailsView: View {
    @StateObject private var viewModel = NetworkDetailsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. Thẻ Thông tin Wi-Fi
                        wifiCard
                            .padding(.horizontal)
                        
                        // 2. Thẻ Cấu hình IP cục bộ
                        ipConfigCard
                            .padding(.horizontal)
                        
                        // 3. Thẻ IP Internet công khai (IPv4 & IPv6 độc lập)
                        publicIPCard
                            .padding(.horizontal)
                        
                        // 4. Thẻ Mạng di động (Cellular & Carrier)
                        cellularCard
                            .padding(.horizontal)
                        
                        // 5. Bảng danh sách các giao diện mạng (Interfaces)
                        interfacesTableCard
                            .padding(.horizontal)
                        
                        // 6. Cảnh báo dữ liệu mẫu OUI
                        ouiSampleNoticeCard
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.loadDetails()
                }
                
                // Toast phản hồi sao chép
                if viewModel.showToast {
                    toastBanner
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.showToast)
            .navigationTitle(LocalizedStringKey("details.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.loadDetails() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                            .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .task {
                await viewModel.loadDetails()
            }
        }
    }
    
    // MARK: - 1. Wi-Fi Card
    private var wifiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: LocalizedStringKey("details.wifi_section"), icon: "wifi", color: .blue)
            
            VStack(spacing: 8) {
                copyableRow(
                    label: LocalizedStringKey("details.ssid"),
                    value: viewModel.details.ssid ?? "Chưa kết nối Wi-Fi / Cần cấp quyền Vị trí",
                    isPlaceholder: viewModel.details.ssid == nil
                )
                
                copyableRow(
                    label: LocalizedStringKey("details.bssid"),
                    value: viewModel.details.bssid ?? "--",
                    isPlaceholder: viewModel.details.bssid == nil
                )
                
                if let vendor = viewModel.details.bssidVendor {
                    copyableRow(
                        label: LocalizedStringKey("details.bssid_vendor"),
                        value: vendor
                    )
                }
                
                copyableRow(
                    label: LocalizedStringKey("details.security"),
                    value: viewModel.details.wifiSecurity ?? "--"
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - 2. IP Config Card
    private var ipConfigCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: LocalizedStringKey("details.ip_section"), icon: "laptopcomputer.and.arrow.down", color: .green)
            
            VStack(spacing: 8) {
                copyableRow(
                    label: LocalizedStringKey("details.ipv4_local"),
                    value: viewModel.details.localIPv4 ?? "--"
                )
                
                copyableRow(
                    label: LocalizedStringKey("details.subnet_mask"),
                    value: viewModel.details.subnetMask ?? "--"
                )
                
                copyableRow(
                    label: LocalizedStringKey("details.gateway"),
                    value: viewModel.details.defaultGateway ?? "--"
                )
                
                copyableRow(
                    label: LocalizedStringKey("details.dns_servers"),
                    value: viewModel.details.dnsServers.isEmpty ? "--" : viewModel.details.dnsServers.joined(separator: ", ")
                )
            }
            
            Text(LocalizedStringKey("details.dns_deprecation_note"))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - 3. Public IP Card
    private var publicIPCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: LocalizedStringKey("details.public_section"), icon: "globe", color: .indigo)
            
            VStack(spacing: 8) {
                copyableRow(
                    label: LocalizedStringKey("details.public_ipv4"),
                    value: viewModel.details.publicIPv4 ?? "Đang kiểm tra...",
                    isPlaceholder: viewModel.details.publicIPv4 == nil
                )
                
                copyableRow(
                    label: LocalizedStringKey("details.public_ipv6"),
                    value: viewModel.details.publicIPv6 ?? "Không có kết nối IPv6",
                    isPlaceholder: viewModel.details.publicIPv6 == nil
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - 4. Cellular Card
    private var cellularCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: LocalizedStringKey("details.cellular_section"), icon: "antenna.radiowaves.left.and.right", color: .orange)
            
            VStack(spacing: 8) {
                copyableRow(
                    label: LocalizedStringKey("details.carrier"),
                    value: viewModel.details.carrierName ?? "Không phát hiện SIM / e-SIM",
                    isPlaceholder: viewModel.details.carrierName == nil
                )
                
                copyableRow(
                    label: LocalizedStringKey("details.radio_tech"),
                    value: viewModel.details.radioTechnology ?? "--"
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - 5. Interfaces Table Card
    private var interfacesTableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: LocalizedStringKey("details.interfaces_section"), icon: "list.bullet.rectangle.portrait", color: .purple)
            
            VStack(spacing: 0) {
                ForEach(viewModel.details.interfaces) { iface in
                    Button {
                        let text = "\(iface.name) (\(iface.type.displayName)): \(iface.allAddresses.joined(separator: ", "))"
                        viewModel.copyToClipboard(value: text, label: iface.name)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: iface.type.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(colorForType(iface.type))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(iface.name)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.primary)
                                    
                                    typeBadge(for: iface.type)
                                    
                                    if iface.isUp {
                                        Text("UP")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.15))
                                            .foregroundColor(.green)
                                            .cornerRadius(3)
                                    }
                                }
                                
                                if !iface.allAddresses.isEmpty {
                                    Text(iface.allAddresses.joined(separator: "\n"))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    Text("Chưa gán địa chỉ IP")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - 6. OUI Notice Card
    private var ouiSampleNoticeCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            Text(LocalizedStringKey("details.oui_sample_warning"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helpers
    private func cardHeader(title: LocalizedStringKey, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline.bold())
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func copyableRow(label: LocalizedStringKey, value: String, isPlaceholder: Bool = false) -> some View {
        Button {
            viewModel.copyToClipboard(value: value, label: value)
        } label: {
            HStack(alignment: .top) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 140, alignment: .leading)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(value)
                        .font(.caption.bold().monospaced())
                        .foregroundColor(isPlaceholder ? .secondary : .primary)
                        .multilineTextAlignment(.trailing)
                    
                    if !isPlaceholder && value != "--" {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
    
    private func typeBadge(for type: NetworkInterfaceType) -> some View {
        Text(type.displayName)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(colorForType(type).opacity(0.15))
            .foregroundColor(colorForType(type))
            .cornerRadius(4)
    }
    
    private func colorForType(_ type: NetworkInterfaceType) -> Color {
        switch type {
        case .wifi: return .blue
        case .cellular: return .orange
        case .vpn: return .green
        case .hotspot: return .pink
        case .ethernet: return .purple
        case .loopback: return .gray
        case .other: return .secondary
        }
    }
    
    private var toastBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(viewModel.toastMessage)
                .font(.caption.bold())
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}
