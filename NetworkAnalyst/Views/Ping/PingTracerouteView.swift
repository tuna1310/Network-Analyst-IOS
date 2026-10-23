//
//  PingTracerouteView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// Chế độ kiểm tra mạng: Ping hoặc Traceroute
public enum DiagnosticToolMode: String, CaseIterable, Identifiable {
    case ping = "Kiểm tra Ping"
    case traceroute = "Dò tuyến Traceroute"
    public var id: String { rawValue }
    
    public var localizedTitle: LocalizedStringKey {
        switch self {
        case .ping: return "traceroute.mode_ping"
        case .traceroute: return "traceroute.mode_traceroute"
        }
    }
}

/// Màn hình kết hợp Kiểm tra ICMP Ping và Dò tuyến đường Traceroute
public struct PingTracerouteView: View {
    @State private var selectedTool: DiagnosticToolMode = .ping
    @StateObject private var pingViewModel = PingViewModel()
    @StateObject private var tracerouteService = TracerouteService()
    
    @State private var tracerouteMaxHops: Int = 30
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segment chuyển đổi Ping / Traceroute
                    Picker("Chế độ công cụ", selection: $selectedTool) {
                        ForEach(DiagnosticToolMode.allCases) { tool in
                            Text(tool.localizedTitle).tag(tool)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if selectedTool == .ping {
                        pingSection
                    } else {
                        tracerouteSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(selectedTool == .ping ? "ICMP Ping" : "Traceroute (IP_TTL)")
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    // MARK: - PING SECTION
    private var pingSection: some View {
        VStack(spacing: 16) {
            pingConfigCard
                .padding(.horizontal)
            
            if let summary = pingViewModel.service.currentSummary {
                pingStatisticsCard(summary: summary)
                    .padding(.horizontal)
            }
            
            if !pingViewModel.service.packets.isEmpty {
                LatencyMiniChart(packets: pingViewModel.service.packets)
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                pingPacketsTableCard
                    .padding(.horizontal)
            }
        }
    }
    
    private var pingConfigCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
                TextField(String(localized: "traceroute.target_placeholder"), text: $pingViewModel.targetHost)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(10)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pingViewModel.popularTargets, id: \.1) { name, host in
                        Button {
                            pingViewModel.targetHost = host
                        } label: {
                            Text(name)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(pingViewModel.targetHost == host ? Color.blue : Color(uiColor: .tertiarySystemFill))
                                .foregroundColor(pingViewModel.targetHost == host ? .white : .primary)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            HStack {
                Text("Số gói:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("Số gói", selection: $pingViewModel.packetCount) {
                    Text("5 gói").tag(5)
                    Text("10 gói").tag(10)
                    Text("20 gói").tag(20)
                    Text("50 gói").tag(50)
                }
                .pickerStyle(.segmented)
            }
            
            Button {
                if pingViewModel.service.isPinging {
                    pingViewModel.stopPing()
                } else {
                    pingViewModel.startPing()
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: pingViewModel.service.isPinging ? "stop.fill" : "play.fill")
                    Text(pingViewModel.service.isPinging ? "Dừng Ping" : "Bắt đầu Ping")
                        .bold()
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 11)
                .background(pingViewModel.service.isPinging ? Color.red : Color.blue)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    private func pingStatisticsCard(summary: PingSessionSummary) -> some View {
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
    
    private var pingPacketsTableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NHẬT KÝ GÓI TIN (ICMP PACKETS)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                ForEach(pingViewModel.service.packets.reversed()) { packet in
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
    
    // MARK: - TRACEROUTE SECTION
    private var tracerouteSection: some View {
        VStack(spacing: 16) {
            tracerouteConfigCard
                .padding(.horizontal)
            
            if !tracerouteService.hops.isEmpty {
                tracerouteHopsListCard
                    .padding(.horizontal)
            }
        }
    }
    
    private var tracerouteConfigCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "point.filled.topleft.down.curvedto.point.bottomright.up")
                    .foregroundColor(.blue)
                TextField(String(localized: "traceroute.target_placeholder"), text: $pingViewModel.targetHost)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(10)
            
            HStack {
                Text(LocalizedStringKey("traceroute.max_hops"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("Max Hops", selection: $tracerouteMaxHops) {
                    Text("15").tag(15)
                    Text("30").tag(30)
                }
                .pickerStyle(.segmented)
            }
            
            // Công tắc Tra cứu GeoIP kèm giải thích quyền riêng tư
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $tracerouteService.isGeoIPEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe.badge.chevron.backward")
                            .foregroundColor(.blue)
                        Text(LocalizedStringKey("traceroute.geoip_toggle"))
                            .font(.subheadline.bold())
                    }
                }
                
                Text(LocalizedStringKey("traceroute.geoip_disclaimer"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Nguồn: \(HTTPSGeoIPProvider.sourceName)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)
            
            Button {
                if tracerouteService.isRunning {
                    tracerouteService.stopTraceroute()
                } else {
                    tracerouteService.startTraceroute(
                        host: pingViewModel.targetHost,
                        maxHops: tracerouteMaxHops,
                        timeout: 1.0,
                        probesPerHop: 3
                    )
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: tracerouteService.isRunning ? "stop.fill" : "arrow.triangle.branch")
                    Text(tracerouteService.isRunning ? LocalizedStringKey("traceroute.stop") : LocalizedStringKey("traceroute.start"))
                        .bold()
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 11)
                .background(tracerouteService.isRunning ? Color.red : Color.blue)
                .cornerRadius(10)
            }
            
            if tracerouteService.isRunning || !tracerouteService.hops.isEmpty {
                HStack {
                    Text(tracerouteService.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    private var tracerouteHopsListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("traceroute.hops_title"))
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                ForEach(tracerouteService.hops) { hop in
                    HStack(spacing: 10) {
                        Text("\(hop.hop)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .frame(width: 28, height: 28)
                            .background(hop.status == .destinationReached ? Color.green.opacity(0.2) : Color.blue.opacity(0.1))
                            .foregroundColor(hop.status == .destinationReached ? .green : .blue)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if let ip = hop.ipAddress {
                                Text(ip)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                
                                if let host = hop.hostname {
                                    Text(host)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            } else {
                                Text("* * *")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Hiển thị RTT của từng probe (3 probes)
                            Text(hop.probesDisplayString)
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                            
                            if let geo = hop.geoInfo {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 9))
                                    Text("\(geo.city ?? ""), \(geo.country ?? "")")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.purple)
                            }
                        }
                        
                        Spacer()
                        
                        if let avg = hop.avgRTT {
                            Text(String(format: "%.1f ms", avg))
                                .font(.caption.monospaced().bold())
                                .foregroundColor(.primary)
                        } else {
                            Text(LocalizedStringKey("traceroute.timeout"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if hop.status == .destinationReached {
                            Image(systemName: "flag.checkered")
                                .foregroundColor(.green)
                                .font(.caption)
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
