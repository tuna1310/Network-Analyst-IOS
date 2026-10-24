//
//  ScanHistoryManager.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine
import NetworkCore

/// Quản lý lịch sử quét mạng, lưu trữ bằng tệp tin JSON trong thư mục Application Support
/// Tuân thủ quy tắc:
/// - Không dùng UserDefaults, không dùng SwiftData
/// - Logic thuần được tách vào NetworkCore (ScanHistoryContainer, giới hạn 100 bản ghi mỗi loại tác vụ)
/// - Đặt `isExcludedFromBackupKey = true` để không đồng bộ lên iCloud backup
/// - Ghi tệp bất đồng bộ ở luồng nền (Background Task).
@MainActor
public final class ScanHistoryManager: ObservableObject {
    public static let shared = ScanHistoryManager()
    
    @Published public private(set) var entries: [ScanHistoryEntry] = []
    
    private var container: ScanHistoryContainer
    private let maxEntriesPerType = 100
    private let fileQueue = DispatchQueue(label: "com.networkanalyst.history.fileio", qos: .background)
    
    private static var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var dir = appSupport.appendingPathComponent("ScanHistory", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        // Đặt thuộc tính không sao lưu lên iCloud cho thư mục
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }
    
    private static var historyFileURL: URL {
        var fileURL = storageDirectory.appendingPathComponent("history.json")
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? fileURL.setResourceValues(values)
        return fileURL
    }
    
    public init() {
        self.container = Self.loadFromDiskSync()
        self.entries = container.entries
    }
    
    /// Thêm một bản ghi mới vào lịch sử (giới hạn 100 bản ghi mỗi loại qua ScanHistoryContainer)
    public func addEntry(
        type: ScanHistoryType,
        target: String,
        summary: String,
        details: String? = nil
    ) {
        let newEntry = ScanHistoryEntry(
            type: type,
            target: target,
            summary: summary,
            details: details
        )
        
        container.add(newEntry)
        self.entries = container.entries
        scheduleSaveToDisk()
    }
    
    /// Xóa một bản ghi theo định danh ID
    public func deleteEntry(id: UUID) {
        container.remove(id: id)
        self.entries = container.entries
        scheduleSaveToDisk()
    }
    
    /// Xóa toàn bộ lịch sử của một phân loại tác vụ cụ thể
    public func clearCategory(_ type: ScanHistoryType) {
        container.clearCategory(type)
        self.entries = container.entries
        scheduleSaveToDisk()
    }
    
    /// Xóa toàn bộ lịch sử quét
    public func clearHistory() {
        container.clearAll()
        self.entries = container.entries
        scheduleSaveToDisk()
    }
    
    // MARK: - Disk Persistence (JSON in Application Support)
    private static func loadFromDiskSync() -> ScanHistoryContainer {
        let fileURL = historyFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ScanHistoryContainer(entries: [], maxEntriesPerType: 100)
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return ScanHistoryContainer.deserialize(from: data, maxEntriesPerType: 100)
        } catch {
            print("Lỗi nạp lịch sử quét từ đĩa: \(error.localizedDescription)")
            return ScanHistoryContainer(entries: [], maxEntriesPerType: 100)
        }
    }
    
    private func scheduleSaveToDisk() {
        let snapshotContainer = self.container
        let fileURL = Self.historyFileURL
        
        fileQueue.async {
            do {
                let data = try snapshotContainer.serialize()
                try data.write(to: fileURL, options: .atomic)
                
                // Đảm bảo cờ loại trừ backup được gán cho file sau khi ghi đĩa
                var mutableURL = fileURL
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? mutableURL.setResourceValues(values)
            } catch {
                print("Lỗi ghi tệp lịch sử quét: \(error.localizedDescription)")
            }
        }
    }
}
