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
    case dns
    case rdap
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .dns: return String(localized: "dns.tab_records", defaultValue: "Bản ghi DNS")
        case .rdap: return String(localized: "dns.tab_rdap", defaultValue: "WHOIS / RDAP")
        }
    }
}

/// ViewModel điều khiển màn hình Tra cứu DNS đa bản ghi (kèm HTTPS/SVCB) và RDAP
@MainActor
public final class DNSLookupViewModel: ObservableObject {
    @Published public var domainInput: String = "apple.com"
    @Published public var selectedRecordType: DNSRecordType = .ANY
    @Published public var selectedProviderOption: Int = 0 // 0: Cloudflare, 1: Google, 2: Quad9, 3: Custom, 4: System Gateway
    @Published public var customResolverIP: String = "1.1.1.1"
    @Published public var lookupMode: LookupMode = .dns
    
    @Published public var isQuerying: Bool = false
    @Published public var dnsResult: DNSQueryResult?
    @Published public var rdapRecord: ParsedRDAPRecord?
    @Published public var rdapError: String?
    
    public let sampleDomains = ["apple.com", "google.com", "cloudflare.com", "microsoft.com", "github.com"]
    
    public var currentProvider: DNSProvider {
        switch selectedProviderOption {
        case 0: return .cloudflare
        case 1: return .google
        case 2: return .quad9
        case 3:
            let ip = customResolverIP.trimmingCharacters(in: .whitespacesAndNewlines)
            return .custom(ip: ip.isEmpty ? "1.1.1.1" : ip)
        case 4:
            let gw = NetworkInterfaceInfo.getDefaultGateway()
            return .system(gatewayIP: gw)
        default:
            return .cloudflare
        }
    }
    
    public init() {}
    
    private func ifCaseSystem(_ provider: DNSProvider) -> Bool {
        if case .system = provider { return true }
        return false
    }
    
    /// Thực hiện tra cứu tùy theo tab hiện tại (DNS hoặc RDAP)
    public func performLookup() async {
        let clean = domainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        isQuerying = true
        let provider = currentProvider
        
        if lookupMode == .dns {
            if selectedRecordType == .ANY {
                // Truy vấn song song tất cả các bản ghi phổ biến kể cả HTTPS và SVCB
                let allTypes: [DNSRecordType] = [
                    .A, .AAAA, .HTTPS, .SVCB, .CNAME, .MX, .TXT, .NS, .SOA, .SRV, .CAA
                ]
                
                var aggregatedRecords: [DNSRecordItem] = []
                var maxResponseTime = 0.0
                var anyTruncated = false
                var anyRetriedTCP = false
                
                await withTaskGroup(of: DNSQueryResult.self) { group in
                    for t in allTypes {
                        group.addTask {
                            return await DNSClient.shared.resolve(domain: clean, type: t, provider: provider)
                        }
                    }
                    
                    for await res in group {
                        aggregatedRecords.append(contentsOf: res.records)
                        maxResponseTime = max(maxResponseTime, res.responseTimeMs)
                        if res.isTruncated { anyTruncated = true }
                        if res.retriedOverTCP { anyRetriedTCP = true }
                    }
                }
                
                // Sắp xếp: A, AAAA, HTTPS, CNAME trước, rồi theo tên
                aggregatedRecords.sort { a, b in
                    if a.type != b.type {
                        return a.type.code < b.type.code
                    }
                    return a.name < b.name
                }
                
                self.dnsResult = DNSQueryResult(
                    domain: clean,
                    recordType: .ANY,
                    provider: provider,
                    records: aggregatedRecords,
                    responseTimeMs: maxResponseTime,
                    isTruncated: anyTruncated,
                    retriedOverTCP: anyRetriedTCP,
                    error: aggregatedRecords.isEmpty ? (
                        ifCaseSystem(provider)
                            ? String(localized: "dns.error.gateway_unresponsive", defaultValue: "Không nhận được phản hồi bản ghi từ DNS mạng hiện tại (Gateway). Router mạng thường chỉ hỗ trợ A/AAAA hoặc chặn truy vấn đa bản ghi. Gợi ý: Hãy chuyển sang Cloudflare (1.1.1.1) hoặc Google (8.8.8.8) qua DoH.")
                            : String(format: String(localized: "dns.error.no_records_for", defaultValue: "Không tìm thấy bản ghi DNS nào cho %@"), clean)
                    ) : nil
                )
            } else {
                let res = await DNSClient.shared.resolve(domain: clean, type: selectedRecordType, provider: provider)
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
