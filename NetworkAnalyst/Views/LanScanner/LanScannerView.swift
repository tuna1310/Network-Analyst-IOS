//
//  LanScannerView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// Màn hình Quét thiết bị mạng nội bộ (LAN Device Scanner)
public struct LanScannerView: View {
    @ObservedObject public var viewModel: LanScannerViewModel
    public let onSelectDeviceForPortScan: (String) -> Void
    
    public init(viewModel: LanScannerViewModel, onSelectDeviceForPortScan: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.onSelectDeviceForPortScan = onSelectDeviceForPortScan
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header điều khiển quét & tiến trình
                scanControlHeader
                
                // Bộ lọc danh mục thiết bị
                filterPillsBar
                
                // Danh sách thiết bị
                if viewModel.filteredDevices.isEmpty {
                    emptyStateView
                } else {
                    deviceListView
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Tìm theo IP, tên máy, nhà sản xuất...")
            .navigationTitle("Quét mạng LAN")
            .sheet(item: $viewModel.selectedDeviceForDetail) { device in
                DeviceDetailSheet(device: device) { ip in
                    onSelectDeviceForPortScan(ip)
                }
            }
        }
    }
    
    // MARK: - Scan Control Header
    private var scanControlHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.engine.isScanning ? "Đang quét mạng nội bộ..." : "Sẵn sàng quét")
                        .font(.headline)
                    Text(viewModel.engine.isScanning ? viewModel.engine.currentHost : "Tìm thấy \(viewModel.engine.discoveredDevices.count) thiết bị")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    if viewModel.engine.isScanning {
                        viewModel.stopScan()
                    } else {
                        viewModel.startScan()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.engine.isScanning ? "stop.fill" : "play.fill")
                        Text(viewModel.engine.isScanning ? "Dừng" : "Bắt đầu quét")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(viewModel.engine.isScanning ? Color.red : Color.blue)
                    .cornerRadius(20)
                }
            }
            
            if viewModel.engine.isScanning {
                ProgressView(value: viewModel.engine.progress)
                    .tint(.blue)
            }
            
            if let err = viewModel.engine.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    // MARK: - Filter Pills Bar
    private var filterPillsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    viewModel.selectedFilter = nil
                } label: {
                    Text("Tất cả (\(viewModel.engine.discoveredDevices.count))")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.selectedFilter == nil ? Color.blue : Color(uiColor: .tertiarySystemFill))
                        .foregroundColor(viewModel.selectedFilter == nil ? .white : .primary)
                        .cornerRadius(14)
                }
                
                ForEach(DeviceType.allCases, id: \.self) { type in
                    let count = viewModel.engine.discoveredDevices.filter { $0.deviceType == type }.count
                    if count > 0 {
                        Button {
                            viewModel.selectedFilter = type
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: type.iconName)
                                Text("\(type.rawValue) (\(count))")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedFilter == type ? Color.blue : Color(uiColor: .tertiarySystemFill))
                            .foregroundColor(viewModel.selectedFilter == type ? .white : .primary)
                            .cornerRadius(14)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Device List
    private var deviceListView: some View {
        List {
            ForEach(viewModel.filteredDevices) { device in
                Button {
                    viewModel.selectedDeviceForDetail = device
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: device.deviceType.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 40, height: 40)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(device.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if device.isGateway {
                                    Text("GATEWAY")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                                
                                if device.isSelf {
                                    Text("BẠN")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                Text(device.ipAddress)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                if let vendor = device.vendor {
                                    Text("• \(vendor)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if let rtt = device.rttMs {
                            Text(String(format: "%.1f ms", rtt))
                                .font(.caption.monospaced())
                                .foregroundColor(.green)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "network")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Chưa có thiết bị nào được quét")
                .font(.headline)
            
            Text("Nhấn 'Bắt đầu quét' để phát hiện các thiết bị kết nối trong mạng Wi-Fi cục bộ qua ICMP, TCP/UDP, NetBIOS, mDNS và Bonjour.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                viewModel.startScan()
            } label: {
                Text("Bắt đầu quét mạng")
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
}
