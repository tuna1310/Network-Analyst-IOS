//
//  DNSLookupView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI
import NetworkCore

/// Màn hình Tra cứu DNS đa bản ghi (DoH/UDP) và WHOIS / RDAP (URLSession)
public struct DNSLookupView: View {
    @StateObject private var viewModel = DNSLookupViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segment chuyển đổi giữa DNS và RDAP
                    Picker("Chế độ tra cứu", selection: $viewModel.lookupMode) {
                        ForEach(LookupMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Ô nhập liệu tên miền & nút tra cứu
                    inputCard
                        .padding(.horizontal)
                    
                    // Bộ lọc loại bản ghi DNS (nếu đang ở tab DNS)
                    if viewModel.lookupMode == .dns {
                        dnsRecordTypeSelector
                            .padding(.horizontal)
                    }
                    
                    // Kết quả hiển thị
                    if viewModel.isQuerying {
                        ProgressView("Đang tra cứu dữ liệu...")
                            .padding(.vertical, 32)
                    } else if viewModel.lookupMode == .dns {
                        dnsResultsCard
                            .padding(.horizontal)
                    } else {
                        rdapResultsCard
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("DNS & WHOIS / RDAP")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: RDAPLookupView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe.americas.fill")
                            Text("RDAP")
                                .font(.caption.bold())
                        }
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    // MARK: - Input Card
    private var inputCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                TextField("Nhập tên miền (vd: apple.com) hoặc IP", text: $viewModel.domainInput)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !viewModel.domainInput.isEmpty {
                    Button {
                        viewModel.domainInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(10)
            
            // Chips chọn nhanh tên miền mẫu
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.sampleDomains, id: \.self) { sample in
                        Button {
                            viewModel.domainInput = sample
                            Task { await viewModel.performLookup() }
                        } label: {
                            Text(sample)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(uiColor: .tertiarySystemFill))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Picker chọn DNS Resolver Upstream (khi ở chế độ DNS)
            if viewModel.lookupMode == .dns {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Máy chủ DNS Resolver:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Picker("DNS Provider", selection: $viewModel.selectedProviderOption) {
                            Text("Cloudflare (1.1.1.1 / DoH)").tag(0)
                            Text("Google (8.8.8.8 / DoH)").tag(1)
                            Text("Quad9 (9.9.9.9 / DoH)").tag(2)
                            Text("Tùy chỉnh IP").tag(3)
                            Text("Mạng hiện tại (Gateway)").tag(4)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    if viewModel.selectedProviderOption == 3 {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.secondary)
                            TextField("Nhập IP máy chủ DNS (vd: 208.67.222.222)", text: $viewModel.customResolverIP)
                                .font(.caption.monospaced())
                                .textFieldStyle(.roundedBorder)
                        }
                    } else if viewModel.selectedProviderOption == 4 {
                        Text("Lưu ý: Mạng hiện tại truy vấn DNS của router gateway nội bộ. Do hệ thống iOS chỉ hỗ trợ giải quyết A/AAAA, các bản ghi mở rộng (HTTPS, CAA, SRV) có thể cần chọn Cloudflare/Google.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Nút Tra cứu
            Button {
                Task { await viewModel.performLookup() }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Tra cứu thông tin")
                        .bold()
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 11)
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - DNS Record Type Selector
    private var dnsRecordTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DNSRecordType.allCases) { type in
                    Button {
                        viewModel.selectedRecordType = type
                        Task { await viewModel.performLookup() }
                    } label: {
                        Text(type.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedRecordType == type ? Color.blue : Color(uiColor: .tertiarySystemFill))
                            .foregroundColor(viewModel.selectedRecordType == type ? .white : .primary)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - DNS Results Card
    private var dnsResultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let result = viewModel.dnsResult {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KẾT QUẢ PHÂN GIẢI DNS")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(result.domain)
                            .font(.headline)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        if result.retriedOverTCP {
                            Text("TCP Retry (TC=1)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                        
                        Text(String(format: "%.0f ms", result.responseTimeMs))
                            .font(.caption.monospaced().bold())
                            .foregroundColor(.secondary)
                    }
                }
                
                if let err = result.error {
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else if result.records.isEmpty {
                    Text("Không tìm thấy bản ghi nào khớp với điều kiện tìm kiếm.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(result.records) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(record.type.rawValue)
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                    
                                    Text(record.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("TTL \(record.ttl)s")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    if let prio = record.priority {
                                        Text("Prio \(prio):")
                                            .font(.system(.footnote, design: .monospaced).bold())
                                            .foregroundColor(.purple)
                                    }
                                    
                                    Text(record.value)
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .cornerRadius(8)
                        }
                    }
                }
            } else {
                Text("Nhập tên miền và bấm 'Tra cứu thông tin' để kiểm tra bản ghi DNS.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - RDAP Results Card
    private var rdapResultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let rdap = viewModel.rdapRecord {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("THÔNG TIN ĐĂNG KÝ (RDAP / WHOIS)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(rdap.title)
                            .font(.headline)
                    }
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    if let reg = rdap.registrarOrOrg {
                        rdapRow(label: "Nhà đăng ký / Tổ chức", value: reg)
                    }
                    if let owner = rdap.registrantName {
                        rdapRow(label: "Chủ thể đăng ký", value: owner)
                    }
                    if let rDate = rdap.registrationDate {
                        rdapRow(label: "Ngày khởi tạo", value: rDate)
                    }
                    if let eDate = rdap.expirationDate {
                        rdapRow(label: "Ngày hết hạn", value: eDate)
                    }
                    if let uDate = rdap.lastUpdatedDate {
                        rdapRow(label: "Cập nhật lần cuối", value: uDate)
                    }
                    if let cidr = rdap.cidrOrRange {
                        rdapRow(label: "Dải IP / CIDR", value: cidr)
                    }
                    if !rdap.status.isEmpty {
                        rdapRow(label: "Trạng thái", value: rdap.status.joined(separator: ", "))
                    }
                    if !rdap.nameservers.isEmpty {
                        rdapRow(label: "Máy chủ tên miền (Nameservers)", value: rdap.nameservers.joined(separator: "\n"))
                    }
                }
            } else if let err = viewModel.rdapError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 8)
            } else {
                Text("Nhập tên miền, IP hoặc ASN để tra cứu hồ sơ chủ sở hữu chính thức qua giao thức RDAP (RFC 7480-7484).")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    private func rdapRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(6)
    }
}
