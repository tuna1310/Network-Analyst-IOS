//
//  PortScannerView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// Màn hình Quét cổng mạng (Port Scanner) sử dụng NWConnection và TaskGroup giới hạn đồng thời
public struct PortScannerView: View {
    @ObservedObject public var viewModel: PortScannerViewModel
    
    public init(viewModel: PortScannerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header cấu hình mục tiêu & chế độ quét
                targetConfigCard
                
                // Thanh tiến trình & chỉ số quét thời gian thực
                if viewModel.engine.isScanning || viewModel.engine.scannedCount > 0 {
                    scanStatusBar
                }
                
                // Danh sách kết quả cổng
                portResultsList
            }
            .navigationTitle("Quét cổng TCP")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.engine.openPorts.isEmpty {
                        ShareLink(item: viewModel.exportSummary()) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Target Configuration Card
    private var targetConfigCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                TextField("Nhập IP hoặc tên miền (vd: 192.168.1.1, google.com)", text: $viewModel.targetHost)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !viewModel.targetHost.isEmpty {
                    Button {
                        viewModel.targetHost = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(10)
            
            // Picker Preset
            Picker("Chế độ quét", selection: $viewModel.selectedPreset) {
                Text(PortScanPreset.top20.title).tag(PortScanPreset.top20)
                Text(PortScanPreset.top100.title).tag(PortScanPreset.top100)
                Text("Tùy chỉnh").tag(PortScanPreset.custom(start: 1, end: 1024))
            }
            .pickerStyle(.segmented)
            
            // Nếu chọn tùy chỉnh dải cổng
            if case .custom = viewModel.selectedPreset {
                HStack(spacing: 12) {
                    Text("Từ cổng:")
                        .font(.caption)
                    TextField("1", text: $viewModel.customStartPort)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Text("Đến:")
                        .font(.caption)
                    TextField("1024", text: $viewModel.customEndPort)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Spacer()
                }
            }
            
            // Nút bắt đầu quét
            Button {
                if viewModel.engine.isScanning {
                    viewModel.stopScan()
                } else {
                    viewModel.startScan()
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: viewModel.engine.isScanning ? "stop.fill" : "bolt.horizontal.fill")
                    Text(viewModel.engine.isScanning ? "Dừng quét" : "Bắt đầu quét cổng")
                        .bold()
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 11)
                .background(viewModel.engine.isScanning ? Color.red : Color.blue)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
    
    // MARK: - Scan Status Bar
    private var scanStatusBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text(viewModel.engine.statusMessage)
                    .font(.caption.bold())
                Spacer()
                Text("\(viewModel.engine.scannedCount) / \(viewModel.engine.totalCount) cổng")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: viewModel.engine.progress)
                .tint(.blue)
            
            HStack {
                Text("Cổng đang mở: ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                + Text("\(viewModel.engine.openPorts.count)")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
                
                Spacer()
                
                Text(String(format: "Tốc độ: %.0f cổng/giây", viewModel.engine.scanRate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    // MARK: - Port Results List
    private var portResultsList: some View {
        List {
            Section {
                Toggle("Chỉ hiển thị các cổng đang Mở (Open)", isOn: $viewModel.onlyShowOpenPorts)
                    .font(.footnote)
            }
            
            if viewModel.displayedPorts.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(viewModel.engine.isScanning ? "Đang dò tìm cổng..." : "Chưa phát hiện cổng mở")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(viewModel.displayedPorts) { item in
                    HStack(spacing: 12) {
                        Text("\(item.port)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .frame(width: 60, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.serviceName)
                                .font(.subheadline.bold())
                            Text(item.serviceDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let rtt = item.rttMs {
                            Text(String(format: "%.0f ms", rtt))
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                        }
                        
                        Text(item.status == .open ? "MỞ" : (item.status == .closed ? "ĐÓNG" : "LỌC"))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                item.status == .open ? Color.green.opacity(0.15) :
                                (item.status == .closed ? Color.red.opacity(0.15) : Color.orange.opacity(0.15))
                            )
                            .foregroundColor(
                                item.status == .open ? .green :
                                (item.status == .closed ? .red : .orange)
                            )
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
