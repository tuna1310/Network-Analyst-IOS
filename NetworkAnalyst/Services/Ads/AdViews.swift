//
//  AdViews.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// View hiển thị Banner quảng cáo tại chân trang (Mặc định dùng MockAd, sẵn sàng đổi sang GADBannerView)
public struct AdBannerContainerView: View {
    @ObservedObject public var adService: MockAdService
    
    public init(adService: MockAdService = .shared) {
        self.adService = adService
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(String(localized: "ads.badge", defaultValue: "QUẢNG CÁO"))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                        
                        Text("Google Mobile Ads Mock")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    Text(String(localized: "ads.mock_banner_subtitle", defaultValue: "Banner 320x50 giả lập • Xem README để tích hợp SDK thật"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "megaphone.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18))
                    .padding(.trailing, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(uiColor: .secondarySystemBackground))
        }
    }
}

/// Modal hiển thị Interstitial Ad giả lập với bộ đếm ngược
public struct MockInterstitialView: View {
    @ObservedObject public var adService: MockAdService
    @State private var countdown: Int = 3
    @State private var canDismiss: Bool = false
    
    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    if canDismiss {
                        Button {
                            adService.dismissInterstitial()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    } else {
                        let countdownFormat = String(localized: "ads.close_countdown", defaultValue: "Đóng sau %ds")
                        Text(String(format: countdownFormat, countdown))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
                .padding()
                
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "sparkles.tv.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.yellow)
                    
                    Text(String(localized: "ads.interstitial_title", defaultValue: "Quảng cáo Toàn Màn Hình"))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(String(localized: "ads.interstitial_desc", defaultValue: "Đây là quảng cáo xen kẽ Interstitial giả lập.\nKhi tích hợp Google Mobile Ads SDK thật, view này sẽ được thay thế bởi GADInterstitialAd."))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
                
                Button {
                    if canDismiss {
                        adService.dismissInterstitial()
                    }
                } label: {
                    Text(canDismiss ? String(localized: "ads.skip_button", defaultValue: "Bỏ qua & Tiếp tục") : String(localized: "ads.loading", defaultValue: "Đang tải..."))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canDismiss ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!canDismiss)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            startTimer()
        }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 1 {
                countdown -= 1
            } else {
                canDismiss = true
                timer.invalidate()
            }
        }
    }
}
