//
//  RDAPViewModel.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import SwiftUI
import NetworkCore

/// Chế độ chọn loại đối tượng truy vấn trong giao diện
public enum RDAPTypeOption: String, CaseIterable, Identifiable {
    case auto = "rdap.query_type_auto"
    case domain = "rdap.query_type_domain"
    case ip = "rdap.query_type_ip"
    case asn = "rdap.query_type_asn"
    
    public var id: String { rawValue }
    
    public var explicitType: RDAPQueryType? {
        switch self {
        case .auto: return nil
        case .domain: return .domain
        case .ip: return .ip
        case .asn: return .asn
        }
    }
}

/// Chế độ hiển thị kết quả (Tóm tắt, Raw JSON, hoặc WHOIS cổ điển)
public enum RDAPDisplayMode: String, CaseIterable, Identifiable {
    case summary = "rdap.mode_summary"
    case rawJSON = "rdap.mode_raw"
    case whois = "rdap.mode_whois_fallback"
    
    public var id: String { rawValue }
}

@MainActor
public final class RDAPViewModel: ObservableObject {
    @Published public var queryInput: String = "apple.com"
    @Published public var typeOption: RDAPTypeOption = .auto
    @Published public var displayMode: RDAPDisplayMode = .summary
    
    @Published public var isLoading: Bool = false
    @Published public var rdapRecord: ParsedRDAPRecord? = nil
    @Published public var whoisResult: WhoisResult? = nil
    @Published public var errorMessage: String? = nil
    
    // Toast notification
    @Published public var showToast: Bool = false
    @Published public var toastMessage: String = ""
    
    public let sampleQueries = [
        "apple.com",
        "8.8.8.8",
        "AS15169",
        "cloudflare.com",
        "1.1.1.1",
        "AS13335"
    ]
    
    public init() {}
    
    /// Thực hiện tra cứu RDAP chính thức
    public func performRDAPLookup() async {
        let clean = queryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        let result = await RDAPClient.shared.lookup(query: clean, explicitType: typeOption.explicitType)
        switch result {
        case .success(let record):
            self.rdapRecord = record
            self.errorMessage = nil
            if displayMode == .whois {
                self.displayMode = .summary
            }
        case .failure(let error):
            self.errorMessage = error.localizedDescription
            self.rdapRecord = nil
        }
        
        isLoading = false
    }
    
    /// Thực hiện tra cứu WHOIS cổ điển qua TCP cổng 43 (Fallback)
    public func performWhoisLookup() async {
        let clean = queryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        let result = await WhoisTCPClient.shared.query(domainOrIP: clean)
        self.whoisResult = result
        self.displayMode = .whois
        
        if let err = result.error, result.rawText.isEmpty {
            self.errorMessage = err
        }
        
        isLoading = false
    }
    
    /// Sao chép dữ liệu vào Clipboard kèm Toast phản hồi
    public func copyToClipboard(text: String, label: String) {
        UIPasteboard.general.string = text
        toastMessage = String(localized: "details.copied_toast", defaultValue: "Đã sao chép: \(label)")
        showToast = true
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showToast = false
        }
    }
}
