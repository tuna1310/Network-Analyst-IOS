//
//  AuthorizationDisclaimerModal.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// Cửa sổ bật lên cảnh báo pháp lý và bảo mật: người dùng chỉ được phép quét mạng được ủy quyền
public struct AuthorizationDisclaimerModal: View {
    @ObservedObject private var configManager = AppConfigManager.shared
    @Environment(\.dismiss) private var dismiss
    
    public let onProceed: () -> Void
    
    public init(onProceed: @escaping () -> Void = {}) {
        self.onProceed = onProceed
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.top, 24)
            
            Text("Cam kết quét mạng được ủy quyền")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Bạn chỉ được phép quét cổng, phân tích mạng và thăm dò dịch vụ trên những thiết bị hoặc mạng mà bạn sở hữu hoặc đã được ủy quyền hợp pháp.")
                        .font(.footnote)
                        .foregroundColor(.primary)
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.red)
                    Text("Hành vi quét mạng không có thẩm quyền có thể kích hoạt hệ thống phát hiện xâm nhập (IDS/IPS), bị chặn kết nối, hoặc vi phạm pháp luật an toàn thông tin.")
                        .font(.footnote)
                        .foregroundColor(.primary)
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.blue)
                    Text("Toàn bộ tiến trình quét được xử lý trực tiếp trên thiết bị (On-Device), bảo mật và không truyền dữ liệu nội bộ tới bất kỳ máy chủ nào.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                configManager.acceptScanDisclaimer()
                dismiss()
                onProceed()
            } label: {
                Text("Tôi đã hiểu và cam kết tuân thủ")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
