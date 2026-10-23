//
//  TracerouteEngineProtocol.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Protocol cho Engine thực hiện dò tuyến đường Traceroute
/// Cho phép linh hoạt hoán đổi hoặc mở rộng cơ chế thu thập phản hồi mạng trên iOS
public protocol TracerouteEngineProtocol: Sendable {
    
    /// Thăm dò một chặng (Hop) xác định với số lần probe (mặc định 3 lần)
    func probeHop(
        host: String,
        targetIP: String,
        hop: Int,
        timeout: TimeInterval,
        probesPerHop: Int,
        resolveGeoIP: Bool,
        geoProvider: GeoIPProvider
    ) async -> TracerouteHop
    
    /// Hủy phiên dò tuyến hiện tại và đóng các socket
    func cancel() async
}
