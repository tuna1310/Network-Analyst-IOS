//
//  RDAPLookupView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI
import NetworkCore

/// Màn hình chuyên dụng tra cứu WHOIS / RDAP (RFC 7480-7484, RFC 9083) kèm dự phòng WHOIS TCP 43
public struct RDAPLookupView: View {
    @StateObject private var viewModel = RDAPViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Thanh nhập liệu & Loại truy vấn
                        inputCard
                            .padding(.horizontal)
                        
                        // Chuyển đổi chế độ hiển thị (Tóm tắt, Raw JSON, WHOIS TCP 43)
                        modePicker
                            .padding(.horizontal)
                        
                        // Nội dung hiển thị
                        if viewModel.isLoading {
                            ProgressView("Đang tra cứu dữ liệu...")
                                .padding(.vertical, 36)
                        } else if let error = viewModel.errorMessage, viewModel.rdapRecord == nil && (viewModel.whoisResult == nil || viewModel.whoisResult!.rawText.isEmpty) {
                            errorCard(error: error)
                                .padding(.horizontal)
                        } else {
                            resultsContent
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // Toast thông báo sao chép
                if viewModel.showToast {
                    toastBanner
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.showToast)
            .navigationTitle(LocalizedStringKey("rdap.title"))
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    // MARK: - Input Card
    private var inputCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                TextField(LocalizedStringKey("rdap.search_placeholder"), text: $viewModel.queryInput)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !viewModel.queryInput.isEmpty {
                    Button {
                        viewModel.queryInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(10)
            
            // Bộ chọn loại đối tượng truy vấn
            HStack {
                Text("Loại truy vấn:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Loại", selection: $viewModel.typeOption) {
                    ForEach(RDAPTypeOption.allCases) { opt in
                        Text(LocalizedStringKey(opt.rawValue)).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Gợi ý mẫu (Sample Queries)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.sampleQueries, id: \.self) { sample in
                        Button {
                            viewModel.queryInput = sample
                            Task { await viewModel.performRDAPLookup() }
                        } label: {
                            Text(sample)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Nút thực hiện tra cứu
            Button {
                Task {
                    if viewModel.displayMode == .whois {
                        await viewModel.performWhoisLookup()
                    } else {
                        await viewModel.performRDAPLookup()
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
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
    
    // MARK: - Mode Picker
    private var modePicker: some View {
        Picker("Chế độ hiển thị", selection: $viewModel.displayMode) {
            ForEach(RDAPDisplayMode.allCases) { mode in
                Text(LocalizedStringKey(mode.rawValue)).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Results Content
    @ViewBuilder
    private var resultsContent: some View {
        switch viewModel.displayMode {
        case .summary:
            if let record = viewModel.rdapRecord {
                summaryCard(record: record)
            } else {
                emptyState
            }
            
        case .rawJSON:
            if let record = viewModel.rdapRecord, let raw = record.rawJSON {
                rawJSONCard(jsonString: raw)
            } else {
                emptyState
            }
            
        case .whois:
            if let whois = viewModel.whoisResult {
                whoisCard(whois: whois)
            } else {
                VStack(spacing: 12) {
                    Text("Bấm nút bên dưới để truy vấn máy chủ WHOIS qua cổng TCP 43 truyền thống:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        Task { await viewModel.performWhoisLookup() }
                    } label: {
                        HStack {
                            Image(systemName: "network")
                            Text(LocalizedStringKey("rdap.whois_fallback_btn"))
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.indigo)
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(14)
            }
        }
    }
    
    // MARK: - Summary Card
    private func summaryCard(record: ParsedRDAPRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(record.title)
                            .font(.title3.bold())
                        
                        Text(record.queryType.pathComponent.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    if let handle = record.handle {
                        Text("Handle: \(handle)")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            // Trạng thái (Status tags)
            if !record.status.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(record.status, id: \.self) { st in
                            Text(st)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.12))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            Divider()
            
            // Nhóm: Chủ sở hữu / Tổ chức
            VStack(spacing: 8) {
                if let reg = record.registrarOrOrg {
                    itemRow(label: LocalizedStringKey("rdap.registrar"), value: reg)
                }
                if let owner = record.registrantName {
                    itemRow(label: LocalizedStringKey("rdap.owner_org"), value: owner)
                }
                if let cidr = record.cidrOrRange {
                    itemRow(label: LocalizedStringKey("rdap.cidr_range"), value: cidr)
                }
                if let rDate = record.registrationDate {
                    itemRow(label: LocalizedStringKey("rdap.created_date"), value: rDate)
                }
                if let eDate = record.expirationDate {
                    itemRow(label: LocalizedStringKey("rdap.expires_date"), value: eDate)
                }
                if let uDate = record.lastUpdatedDate {
                    itemRow(label: LocalizedStringKey("rdap.updated_date"), value: uDate)
                }
            }
            
            // Nhóm: Máy chủ tên miền
            if !record.nameservers.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("rdap.nameservers"))
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(record.nameservers, id: \.self) { ns in
                            HStack {
                                Image(systemName: "server.rack")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(ns)
                                    .font(.caption.monospaced())
                                Spacer()
                            }
                            .padding(6)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            
            // Nhóm: Liên hệ (Contacts)
            if !record.contacts.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("rdap.contacts"))
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(record.contacts.enumerated()), id: \.offset) { _, contact in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(contact.role.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            if let name = contact.name {
                                Text(name).font(.caption.bold())
                            }
                            if let org = contact.organization {
                                Text(org).font(.caption2).foregroundColor(.secondary)
                            }
                            if let email = contact.email {
                                Text(email).font(.caption2.monospaced()).foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                    }
                }
            }
            
            Divider()
            
            // Nút dự phòng WHOIS TCP 43
            Button {
                Task { await viewModel.performWhoisLookup() }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                    Text(LocalizedStringKey("rdap.whois_fallback_btn"))
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(.indigo)
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Raw JSON Card
    private func rawJSONCard(jsonString: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PHẢN HỒI GỐC RDAP (RFC 7483 JSON)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    viewModel.copyToClipboard(text: jsonString, label: "RDAP JSON")
                } label: {
                    Label(String(localized: "rdap.copy_json"), systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
            }
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(jsonString)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(maxHeight: 350)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Whois Card
    private func whoisCard(whois: WhoisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PHẢN HỒI WHOIS CỔ ĐIỂN (TCP PORT 43)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    if !whois.referralChain.isEmpty {
                        Text(String(format: String(localized: "rdap.whois_referral_hops"), whois.referralChain.count))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    viewModel.copyToClipboard(text: whois.rawText, label: "WHOIS Text")
                } label: {
                    Label(String(localized: "rdap.copy_whois"), systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
            }
            
            // Danh sách các hop referral đã theo dõi
            if whois.referralChain.count > 1 {
                HStack(spacing: 4) {
                    ForEach(whois.referralChain, id: \.self) { server in
                        Text(server)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.12))
                            .foregroundColor(.indigo)
                            .cornerRadius(4)
                    }
                }
            }
            
            if let err = whois.error {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(whois.rawText.isEmpty ? "Không nhận được nội dung phản hồi." : whois.rawText)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(maxHeight: 350)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Error & Empty State
    private func errorCard(error: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thông Báo RDAP")
                        .font(.subheadline.bold())
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Nút thử chuyển sang WHOIS TCP 43
            Button {
                Task { await viewModel.performWhoisLookup() }
            } label: {
                HStack {
                    Image(systemName: "network")
                    Text(LocalizedStringKey("rdap.whois_fallback_btn"))
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Nhập tên miền, IP hoặc ASN và bấm 'Tra cứu thông tin'")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    private func itemRow(label: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.caption.bold())
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Toast Banner
    private var toastBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(viewModel.toastMessage)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
