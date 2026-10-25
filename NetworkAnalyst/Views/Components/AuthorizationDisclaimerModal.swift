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
            
            Text(LocalizedStringKey("disclaimer.title"))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(LocalizedStringKey("disclaimer.rule1"))
                        .font(.footnote)
                        .foregroundColor(.primary)
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.red)
                    Text(LocalizedStringKey("disclaimer.rule2"))
                        .font(.footnote)
                        .foregroundColor(.primary)
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.blue)
                    Text(LocalizedStringKey("disclaimer.rule3"))
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
                Text(LocalizedStringKey("disclaimer.agree"))
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
