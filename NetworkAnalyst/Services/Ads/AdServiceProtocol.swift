//
//  AdServiceProtocol.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import UIKit
import Combine

/// Giao diện chuẩn cho dịch vụ Quảng cáo (Banner, Interstitial, Rewarded)
@MainActor
public protocol AdServiceProtocol: ObservableObject {
    var isBannerReady: Bool { get }
    var isInterstitialReady: Bool { get }
    var isRewardedReady: Bool { get }
    var showInterstitialModal: Bool { get set }
    var showRewardedModal: Bool { get set }
    
    func initialize()
    func loadBanner()
    func loadInterstitial()
    func showInterstitial(completion: (() -> Void)?)
    func showRewarded(rewardGranted: @escaping (Int) -> Void)
}

/// Triển khai dịch vụ Quảng cáo giả lập (Mock) cho môi trường phát triển và thử nghiệm
@MainActor
public final class MockAdService: AdServiceProtocol {
    public static let shared = MockAdService()
    
    @Published public var isBannerReady: Bool = true
    @Published public var isInterstitialReady: Bool = true
    @Published public var isRewardedReady: Bool = true
    @Published public var showInterstitialModal: Bool = false
    @Published public var showRewardedModal: Bool = false
    
    private var pendingInterstitialCompletion: (() -> Void)?
    private var pendingRewardHandler: ((Int) -> Void)?
    
    public init() {
        initialize()
    }
    
    public func initialize() {
        // Giả lập khởi tạo SDK (ví dụ GADMobileAds.sharedInstance().start)
        self.isBannerReady = true
        self.isInterstitialReady = true
        self.isRewardedReady = true
    }
    
    public func loadBanner() {
        self.isBannerReady = true
    }
    
    public func loadInterstitial() {
        self.isInterstitialReady = true
    }
    
    public func showInterstitial(completion: (() -> Void)?) {
        guard isInterstitialReady else {
            completion?()
            return
        }
        self.pendingInterstitialCompletion = completion
        self.showInterstitialModal = true
    }
    
    public func dismissInterstitial() {
        self.showInterstitialModal = false
        self.pendingInterstitialCompletion?()
        self.pendingInterstitialCompletion = nil
    }
    
    public func showRewarded(rewardGranted: @escaping (Int) -> Void) {
        guard isRewardedReady else { return }
        self.pendingRewardHandler = rewardGranted
        self.showRewardedModal = true
    }
    
    public func completeRewarded() {
        self.showRewardedModal = false
        self.pendingRewardHandler?(100)
        self.pendingRewardHandler = nil
    }
    
    public func cancelRewarded() {
        self.showRewardedModal = false
        self.pendingRewardHandler = nil
    }
}
