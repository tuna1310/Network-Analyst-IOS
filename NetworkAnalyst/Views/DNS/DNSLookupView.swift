//
//  DNSLookupView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

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
                HStack {
                    Text("Máy chủ DNS:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("DNS Provider", selection: $viewModel.selectedProvider) {
                        ForEach(DNSProvider.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
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
                    Text(String(format: "%.0f ms", result.responseTimeMs))
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
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
            if let rdap = viewModel.rdapResult {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("THÔNG TIN ĐĂNG KÝ (RDAP / WHOIS)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(rdap.ldhName ?? rdap.query)
                            .font(.headline)
                    }
                    Spacer()
                }
                
                if let err = rdap.error {
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        if let reg = rdap.registrar {
                            rdapRow(label: "Nhà đăng ký (Registrar)", value: reg)
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
                        if !rdap.status.isEmpty {
                            rdapRow(label: "Trạng thái", value: rdap.status.joined(separator: ", "))
                        }
                        if !rdap.nameservers.isEmpty {
                            rdapRow(label: "Máy chủ tên miền (Nameservers)", value: rdap.nameservers.joined(separator: "\n"))
                        }
                    }
                }
            } else {
                Text("Nhập tên miền hoặc IP để tra cứu hồ sơ chủ sở hữu chính thức qua giao thức RDAP (RFC 7480-7484).")
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
