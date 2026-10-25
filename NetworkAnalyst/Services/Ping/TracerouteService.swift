//
//  TracerouteService.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine

/// Service điều phối phiên Traceroute, quản lý trạng thái và bắn cập nhật về SwiftUI
@MainActor
public final class TracerouteService: ObservableObject {
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var hops: [TracerouteHop] = []
    @Published public private(set) var statusMessage: String = String(localized: "traceroute.status.ready", defaultValue: "Sẵn sàng")
    @Published public var isGeoIPEnabled: Bool = false
    
    private var traceTask: Task<Void, Never>?
    private var engine: TracerouteEngineProtocol
    private let geoProvider: GeoIPProvider
    
    public init(
        engine: TracerouteEngineProtocol = TracerouteEngine(),
        geoProvider: GeoIPProvider = HTTPSGeoIPProvider.shared
    ) {
        self.engine = engine
        self.geoProvider = geoProvider
    }
    
    /// Bắt đầu dò tuyến đường tới máy chủ mục tiêu
    public func startTraceroute(
        host: String,
        maxHops: Int = 30,
        timeout: TimeInterval = 1.0,
        probesPerHop: Int = 3
    ) {
        stopTraceroute()
        
        guard AppConfigManager.shared.config.hasAcceptedScanDisclaimer else {
            statusMessage = String(localized: "traceroute.status.disclaimer_required", defaultValue: "Yêu cầu cam kết chỉ quét mạng được ủy quyền trước khi thực hiện.")
            return
        }
        
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else {
            statusMessage = String(localized: "traceroute.status.empty_target", defaultValue: "Địa chỉ mục tiêu trống")
            return
        }
        
        isRunning = true
        hops.removeAll()
        let resolvingFormat = String(localized: "traceroute.status.resolving", defaultValue: "Đang phân giải địa chỉ %@...")
        statusMessage = String(format: resolvingFormat, cleanHost)
        
        let engine = self.engine
        let enableGeo = self.isGeoIPEnabled
        let geo = self.geoProvider
        
        traceTask = Task {
            // Phân giải host thành IP
            let icmp = ICMPEngine()
            guard let resolved = await icmp.resolveHost(cleanHost) else {
                let cannotResolveFormat = String(localized: "traceroute.status.cannot_resolve", defaultValue: "Không thể phân giải địa chỉ IP cho %@")
                self.statusMessage = String(format: cannotResolveFormat, cleanHost)
                self.isRunning = false
                return
            }
            let targetIP = resolved.ipAddress
            
            let probingMsg = String(localized: "traceroute.probing")
            self.statusMessage = String(format: probingMsg, cleanHost, targetIP)
            
            for hopIndex in 1...maxHops {
                guard !Task.isCancelled else { break }
                
                // Thêm hop tạm thời vào bảng
                let placeholder = TracerouteHop(hop: hopIndex, status: .timeout)
                self.hops.append(placeholder)
                
                let result = await engine.probeHop(
                    host: cleanHost,
                    targetIP: targetIP,
                    hop: hopIndex,
                    timeout: timeout,
                    probesPerHop: probesPerHop,
                    resolveGeoIP: enableGeo,
                    geoProvider: geo
                )
                
                guard !Task.isCancelled else { break }
                
                if let idx = self.hops.firstIndex(where: { $0.hop == hopIndex }) {
                    self.hops[idx] = result
                }
                
                if result.status == .destinationReached {
                    let reachedFormat = String(localized: "traceroute.reached_destination")
                    self.statusMessage = String(format: reachedFormat, hopIndex)
                    break
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            
            if !Task.isCancelled && self.isRunning {
                let compFormat = String(localized: "traceroute.completed")
                self.statusMessage = String(format: compFormat, self.hops.count)
                
                // Ghi nhận vào lịch sử
                ScanHistoryManager.shared.addEntry(
                    type: .traceroute,
                    target: "\(cleanHost) (\(targetIP))",
                    summary: String(format: String(localized: "traceroute.history.summary_format", defaultValue: "Dò được %d hop tới đích"), self.hops.count),
                    details: self.hops.map { h in
                        "Hop \(h.hop): \(h.ipAddress ?? "*") (\(h.hostname ?? "No PTR")) - \(h.formattedRTT)"
                    }.joined(separator: "\n")
                )
            }
            self.isRunning = false
        }
    }
    
    /// Dừng phiên Traceroute
    public func stopTraceroute() {
        traceTask?.cancel()
        traceTask = nil
        Task {
            await engine.cancel()
        }
        isRunning = false
        self.statusMessage = String(localized: "traceroute.stopped")
    }
}
