//
//  MonotonicClock.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Bộ đo thời gian đơn điệu (Monotonic Clock) sử dụng ContinuousClock chuẩn Swift 5.7+ / iOS 16+
/// Đảm bảo tính đơn điệu, không trôi lệch khi người dùng chỉnh giờ máy hoặc NTP đồng bộ lại giờ.
public enum MonotonicClock {
    private static let clock = ContinuousClock()
    
    /// Đánh dấu thời điểm hiện tại
    public static func now() -> ContinuousClock.Instant {
        return clock.now
    }
    
    /// Tính khoảng thời gian đã trôi qua (milliseconds) từ mốc `start`
    public static func elapsedMs(since start: ContinuousClock.Instant) -> Double {
        let duration = clock.now - start
        return Double(duration.components.seconds) * 1000.0 + Double(duration.components.attoseconds) / 1e15
    }
}
