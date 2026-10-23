//
//  DNSLookupViewModel.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine
import NetworkCore

/// Tab lựa chọn giữa DNS Records và RDAP/Whois
public enum LookupMode: String, CaseIterable, Identifiable {
    case dns = "Bản ghi DNS"
    case rdap = "WHOIS / RDAP"
    public var id: String { rawValue }
}

/// ViewModel điều khiển màn hình Tra cứu DNS và RDAP
@MainActor
public final class DNSLookupViewModel: ObservableObject {
    @Published public var domainInput: String = "apple.com"
    @Published public var selectedRecordType: DNSRecordType = .ANY
    @Published public var selectedProvider: DNSProvider = .cloudflare
    @Published public var lookupMode: LookupMode = .dns
    
    @Published public var isQuerying: Bool = false
    @Published public var dnsResult: DNSQueryResult?
    @Published public var rdapRecord: ParsedRDAPRecord?
    @Published public var rdapError: String?
    
    public let sampleDomains = ["apple.com", "google.com", "cloudflare.com", "microsoft.com", "github.com"]
    
    public init() {}
    
    /// Thực hiện tra cứu tùy theo tab hiện tại (DNS hoặc RDAP)
    public func performLookup() async {
        let clean = domainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        isQuerying = true
        
        if lookupMode == .dns {
            if selectedRecordType == .ANY {
                // Truy vấn song song các bản ghi phổ biến: A, AAAA, MX, TXT, NS, CNAME, SOA
                let types: [DNSRecordType] = [.A, .AAAA, .MX, .TXT, .NS, .CNAME, .SOA]
                var aggregatedRecords: [DNSRecordItem] = []
                var totalTime = 0.0
                
                for t in types {
                    let res = await DNSClient.shared.resolve(domain: clean, type: t, provider: selectedProvider)
                    aggregatedRecords.append(contentsOf: res.records)
                    totalTime = max(totalTime, res.responseTimeMs)
                }
                
                self.dnsResult = DNSQueryResult(
                    domain: clean,
                    recordType: .ANY,
                    provider: selectedProvider,
                    records: aggregatedRecords,
                    responseTimeMs: totalTime,
                    error: aggregatedRecords.isEmpty ? "Không tìm thấy bản ghi DNS nào cho \(clean)" : nil
                )
            } else {
                let res = await DNSClient.shared.resolve(domain: clean, type: selectedRecordType, provider: selectedProvider)
                self.dnsResult = res
            }
        } else {
            let res = await RDAPClient.shared.lookup(query: clean)
            switch res {
            case .success(let rec):
                self.rdapRecord = rec
                self.rdapError = nil
            case .failure(let err):
                self.rdapRecord = nil
                self.rdapError = err.localizedDescription
            }
        }
        
        isQuerying = false
    }
}
