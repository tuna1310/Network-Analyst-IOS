//
//  PingTracerouteView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// Màn hình Kiểm tra độ trễ mạng ICMP Ping (sử dụng ICMP Datagram Socket không đặc quyền)
public struct PingTracerouteView: View {
    @StateObject private var viewModel = PingViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Cấu hình máy chủ đích & thông số
                    configCard
                        .padding(.horizontal)
                    
                    // Thống kê tổng quan (Summary)
                    if let summary = viewModel.service.currentSummary {
                        statisticsCard(summary: summary)
                            .padding(.horizontal)
                    }
                    
                    // Biểu đồ độ trễ mini
                    if !viewModel.service.packets.isEmpty {
                        LatencyMiniChart(packets: viewModel.service.packets)
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                    
                    // Bảng chi tiết các gói tin đã gửi
                    if !viewModel.service.packets.isEmpty {
                        packetsTableCard
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Kiểm tra ICMP Ping")
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    // MARK: - Config Card
    private var configCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
                TextField("Nhập IP hoặc domain (vd: 1.1.1.1, google.com)", text: $viewModel.targetHost)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(10)
            
            // Chips chọn nhanh đích phổ biến
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.popularTargets, id: \.1) { name, host in
                        Button {
                            viewModel.targetHost = host
                        } label: {
                            Text(name)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(viewModel.targetHost == host ? Color.blue : Color(uiColor: .tertiarySystemFill))
                                .foregroundColor(viewModel.targetHost == host ? .white : .primary)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Tùy chọn số lượng gói tin
            HStack {
                Text("Số gói tin:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Số gói", selection: $viewModel.packetCount) {
                    Text("5 gói").tag(5)
                    Text("10 gói").tag(10)
                    Text("20 gói").tag(20)
                    Text("50 gói").tag(50)
                }
                .pickerStyle(.segmented)
            }
            
            // Nút Bắt đầu / Dừng Ping
            Button {
                if viewModel.service.isPinging {
                    viewModel.stopPing()
                } else {
                    viewModel.startPing()
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: viewModel.service.isPinging ? "stop.fill" : "play.fill")
                    Text(viewModel.service.isPinging ? "Dừng Ping" : "Bắt đầu Ping")
                        .bold()
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 11)
                .background(viewModel.service.isPinging ? Color.red : Color.blue)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Statistics Summary Card
    private func statisticsCard(summary: PingSessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KẾT QUẢ THỐNG KÊ")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                metricBox(title: "Đã gửi", value: "\(summary.packetsTransmitted)")
                metricBox(title: "Đã nhận", value: "\(summary.packetsReceived)")
                metricBox(
                    title: "Mất gói",
                    value: String(format: "%.0f%%", summary.packetLossPercent),
                    color: summary.packetLossPercent > 0 ? .red : .green
                )
                
                metricBox(title: "Min RTT", value: summary.minRTT != nil ? String(format: "%.1f ms", summary.minRTT!) : "--")
                metricBox(title: "Avg RTT", value: summary.avgRTT != nil ? String(format: "%.1f ms", summary.avgRTT!) : "--")
                metricBox(title: "Max RTT", value: summary.maxRTT != nil ? String(format: "%.1f ms", summary.maxRTT!) : "--")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    private func metricBox(title: String, value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold().monospaced())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Packets Table Card
    private var packetsTableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NHẬT KÝ GÓI TIN (ICMP PACKETS)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                ForEach(viewModel.service.packets.reversed()) { packet in
                    HStack {
                        Text("#\(packet.sequence)")
                            .font(.caption.monospaced().bold())
                            .frame(width: 36, alignment: .leading)
                        
                        Text(packet.ipAddress)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let rtt = packet.rttMs {
                            Text(String(format: "%.1f ms", rtt))
                                .font(.caption.monospaced().bold())
                                .foregroundColor(.blue)
                        } else {
                            Text(packet.status == .timeout ? "Timeout" : "Lỗi")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                        }
                        
                        if let ttl = packet.ttl {
                            Text("TTL \(ttl)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}
