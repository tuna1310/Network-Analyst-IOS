//
//  ScanHistoryView.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI
import NetworkCore

/// Màn hình Lịch sử quét mạng lưu trữ cục bộ (JSON FileManager)
public struct ScanHistoryView: View {
    @ObservedObject private var historyManager = ScanHistoryManager.shared
    @State private var selectedFilter: ScanHistoryType? = nil
    @State private var showClearAllAlert: Bool = false
    @State private var selectedEntryForDetail: ScanHistoryEntry? = nil
    
    public init() {}
    
    public var filteredEntries: [ScanHistoryEntry] {
        if let filter = selectedFilter {
            return historyManager.entries.filter { $0.type == filter }
        }
        return historyManager.entries
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Thanh lọc danh mục
            categoryFilterBar
            
            if filteredEntries.isEmpty {
                emptyStateView
            } else {
                historyList
            }
        }
        .navigationTitle("Lịch sử phân tích")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !historyManager.entries.isEmpty {
                    Button(role: .destructive) {
                        showClearAllAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert("Xóa toàn bộ lịch sử?", isPresented: $showClearAllAlert) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa tất cả", role: .destructive) {
                historyManager.clearHistory()
            }
        } message: {
            Text("Thao tác này sẽ xóa vĩnh viễn toàn bộ nhật ký quét đã lưu trên máy.")
        }
        .sheet(item: $selectedEntryForDetail) { entry in
            entryDetailSheet(entry: entry)
        }
    }
    
    // MARK: - Category Filter Bar
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedFilter = nil
                } label: {
                    Text("Tất cả (\(historyManager.entries.count))")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedFilter == nil ? Color.blue : Color(uiColor: .tertiarySystemFill))
                        .foregroundColor(selectedFilter == nil ? .white : .primary)
                        .cornerRadius(16)
                }
                
                ForEach(ScanHistoryType.allCases) { cat in
                    let count = historyManager.entries.filter { $0.type == cat }.count
                    Button {
                        selectedFilter = cat
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.iconName)
                            Text("\(cat.rawValue) (\(count))")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedFilter == cat ? Color.blue : Color(uiColor: .tertiarySystemFill))
                        .foregroundColor(selectedFilter == cat ? .white : .primary)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    // MARK: - History List
    private var historyList: some View {
        List {
            ForEach(filteredEntries) { entry in
                Button {
                    selectedEntryForDetail = entry
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: entry.type.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.target)
                                    .font(.system(.subheadline, design: .monospaced).bold())
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(entry.summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Text(entry.type.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundColor(.secondary)
                                .cornerRadius(3)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let item = filteredEntries[index]
                    historyManager.deleteEntry(id: item.id)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Chưa có lịch sử quét")
                .font(.headline)
            Text("Kết quả từ các lần quét mạng LAN, kiểm tra cổng, ping và traceroute sẽ tự động được lưu lại tại đây.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
    
    // MARK: - Detail Sheet
    private func entryDetailSheet(entry: ScanHistoryEntry) -> some View {
        NavigationStack {
            List {
                Section(header: Text("Tác vụ")) {
                    HStack {
                        Text("Phân loại")
                        Spacer()
                        Text(entry.type.rawValue)
                            .bold()
                    }
                    HStack {
                        Text("Mục tiêu")
                        Spacer()
                        Text(entry.target)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("Thời gian")
                        Spacer()
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Tóm tắt kết quả")) {
                    Text(entry.summary)
                        .font(.body)
                }
                
                if let details = entry.details, !details.isEmpty {
                    Section(header: Text("Chi tiết kỹ thuật")) {
                        Text(details)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Chi tiết bản ghi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: "\(entry.type.rawValue): \(entry.target)\n\(entry.summary)\n\(entry.details ?? "")")
                }
            }
        }
    }
}
