//
//  PortScannerView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI
import NetworkCore

/// Màn hình Quét cổng mạng (Port Scanner) hỗ trợ 3 chế độ (Phổ biến, Tùy chọn, Toàn dải 1-65535),
/// 4 trạng thái cổng (Open, Closed, Filtered, Error), Tạm dừng/Tiếp tục/Hủy, và Thăm dò Banner
public struct PortScannerView: View {
    @ObservedObject public var viewModel: PortScannerViewModel
    
    public init(viewModel: PortScannerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header cấu hình mục tiêu & 3 chế độ quét
                targetConfigCard
                
                // Thanh tiến trình & chỉ số quét thời gian thực
                if viewModel.engine.isScanning || viewModel.engine.scannedCount > 0 {
                    scanStatusBar
                }
                
                // Bộ lọc trạng thái hiển thị (Chỉ mở, Tất cả, Đóng, Bị chặn)
                filterPickerBar
                
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
            .alert("Xác nhận quét toàn dải 1 - 65535", isPresented: $viewModel.showFullScanAlert) {
                Button("Hủy", role: .cancel) {}
                Button("Bắt đầu quét", role: .destructive) {
                    viewModel.confirmAndStartFullScan()
                }
            } message: {
                Text("Quét toàn bộ 65,535 cổng có thể mất \(viewModel.estimatedDurationText) và tiêu tốn pin cũng như băng thông mạng. Bạn có chắc chắn muốn tiếp tục?")
            }
        }
    }
    
    // MARK: - Target Configuration Card
    private var targetConfigCard: some View {
        VStack(spacing: 12) {
            // Ô nhập IP / Hostname
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                TextField("Nhập IP hoặc tên miền (vd: 192.168.1.1, apple.com)", text: $viewModel.targetHost)
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
            
            // Bộ chọn 3 chế độ quét
            Picker("Chế độ quét", selection: $viewModel.scanMode) {
                ForEach(PortScanMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            // Cấu hình con tùy theo chế độ đã chọn
            switch viewModel.scanMode {
            case .popular:
                Picker("Preset phổ biến", selection: $viewModel.selectedPreset) {
                    Text(PortScanPreset.top20.title).tag(PortScanPreset.top20)
                    Text(PortScanPreset.top100.title).tag(PortScanPreset.top100)
                }
                .pickerStyle(.segmented)
                
            case .custom:
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.secondary)
                        TextField("Cú pháp: 80, 443, 8000-8100", text: $viewModel.customRangeInput)
                            .font(.system(.subheadline, design: .monospaced))
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                    
                    if let err = viewModel.customRangeError {
                        Text(err)
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else {
                        Text("Nhập các cổng cách nhau bằng dấu phẩy hoặc dấu gạch nối cho dải (1-65535).")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
            case .full:
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Chế độ quét toàn bộ cổng (1 đến 65535). Yêu cầu xác nhận trước khi quét.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Công tắc Banner Grabbing
            Toggle(isOn: $viewModel.engine.enableBannerGrabbing) {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .foregroundColor(.purple)
                    Text("Thăm dò banner dịch vụ (Banner Grabbing)")
                        .font(.caption)
                }
            }
            .tint(.purple)
            
            // Nhóm nút điều khiển quét (Bắt đầu / Tạm dừng / Tiếp tục / Hủy)
            HStack(spacing: 10) {
                if viewModel.engine.isScanning {
                    // Nút Tạm dừng / Tiếp tục
                    Button {
                        if viewModel.engine.isPaused {
                            viewModel.resumeScan()
                        } else {
                            viewModel.pauseScan()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: viewModel.engine.isPaused ? "play.fill" : "pause.fill")
                            Text(viewModel.engine.isPaused ? "Tiếp tục" : "Tạm dừng")
                                .bold()
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .background(viewModel.engine.isPaused ? Color.green : Color.orange)
                        .cornerRadius(10)
                    }
                    
                    // Nút Hủy / Dừng
                    Button {
                        viewModel.stopScan()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "stop.fill")
                            Text("Dừng")
                                .bold()
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                } else {
                    // Nút Bắt đầu
                    Button {
                        viewModel.startScan()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                            Text("Bắt đầu quét cổng")
                                .bold()
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 11)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
    
    // MARK: - Scan Status Bar
    private var scanStatusBar: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.engine.progress)
                .tint(viewModel.engine.isPaused ? .orange : .blue)
            
            HStack {
                Text(viewModel.engine.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f cổng/giây", viewModel.engine.scanRate))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    // MARK: - Filter Picker Bar
    private var filterPickerBar: some View {
        HStack {
            Text("Hiển thị:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker("Bộ lọc", selection: $viewModel.filterOption) {
                ForEach(PortFilterOption.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    // MARK: - Port Results List
    private var portResultsList: some View {
        List {
            if viewModel.displayedPorts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(viewModel.engine.isScanning ? "Đang quét các cổng..." : "Chưa có cổng nào phù hợp bộ lọc.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.displayedPorts) { item in
                    portRow(item: item)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Port Row
    private func portRow(item: ScannedPort) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                // Số hiệu cổng
                Text("\(item.port)")
                    .font(.system(.headline, design: .monospaced).bold())
                    .frame(width: 60, alignment: .leading)
                
                // Tên dịch vụ & mô tả
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.serviceName)
                        .font(.subheadline.bold())
                    Text(item.serviceDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Badge trạng thái (Open: xanh, Closed: xám, Filtered: cam, Error: đỏ)
                statusBadge(item.status)
                
                if let rtt = item.rttMs {
                    Text(String(format: "%.0f ms", rtt))
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }
            }
            
            // Banner Grabbing (nếu có)
            if let banner = item.banner, !banner.isEmpty {
                Text(banner)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(4)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func statusBadge(_ status: PortStatus) -> some View {
        switch status {
        case .open:
            Text("MỞ")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .cornerRadius(4)
        case .closed:
            Text("ĐÓNG")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .foregroundColor(.gray)
                .cornerRadius(4)
        case .filtered:
            Text("BỊ CHẶN")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)
                .cornerRadius(4)
        case .error(let reason):
            Text("LỖI: \(reason)")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .cornerRadius(4)
                .lineLimit(1)
        }
    }
}
