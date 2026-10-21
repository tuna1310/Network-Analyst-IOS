//
//  UIComponents.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// Banner cảnh báo và hướng dẫn quyền truy cập (Local Network hoặc Location cho Wi-Fi)
public struct PermissionAlertBanner: View {
    public let icon: String
    public let title: String
    public let message: String
    public let actionTitle: String
    public let action: () -> Void
    
    public init(
        icon: String = "exclamationmark.triangle.fill",
        title: String,
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .font(.system(size: 18, weight: .bold))
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: action) {
                HStack {
                    Text(actionTitle)
                        .font(.footnote.bold())
                    Image(systemName: "arrow.right.circle.fill")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

/// Thẻ hiển thị một chỉ số mạng cơ bản (Metric Card)
public struct MetricItemCard: View {
    public let icon: String
    public let iconColor: Color
    public let title: String
    public let value: String
    public let subtitle: String?
    
    public init(
        icon: String,
        iconColor: Color = .blue,
        title: String,
        value: String,
        subtitle: String? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

/// Biểu đồ trực quan hóa độ trễ Ping theo thời gian thực (SwiftUI Canvas)
public struct LatencyMiniChart: View {
    public let packets: [PingPacketResult]
    
    public init(packets: [PingPacketResult]) {
        self.packets = packets
    }
    
    public var body: some View {
        let rtts = packets.compactMap { $0.rttMs }
        let maxRTT = max(rtts.max() ?? 100.0, 50.0)
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Biểu đồ Độ trễ RTT (ms)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if let latest = rtts.last {
                    Text(String(format: "%.1f ms", latest))
                        .font(.caption.monospaced().bold())
                        .foregroundColor(.blue)
                }
            }
            
            Canvas { context, size in
                guard !rtts.isEmpty else { return }
                
                let width = size.width
                let height = size.height
                let stepX = width / CGFloat(max(rtts.count - 1, 1))
                
                var path = Path()
                for (index, rtt) in rtts.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = CGFloat(rtt / maxRTT)
                    let y = height - (normalizedY * (height - 8))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                context.stroke(path, with: .color(.blue), lineWidth: 2)
                
                // Draw dots
                for (index, rtt) in rtts.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = CGFloat(rtt / maxRTT)
                    let y = height - (normalizedY * (height - 8))
                    let dotRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: dotRect), with: .color(.blue))
                }
            }
            .frame(height: 70)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
    }
}
