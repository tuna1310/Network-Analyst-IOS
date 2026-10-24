//
//  ScanHistoryManager.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine

/// Quản lý lịch sử quét mạng, lưu trữ bằng tệp tin JSON trong thư mục Application Support
/// Tuân thủ quy tắc: Không dùng UserDefaults, không dùng SwiftData, giới hạn tối đa 100 bản ghi mỗi loại tác vụ,
/// ghi tệp bất đồng bộ ở luồng nền (Background Task).
@MainActor
public final class ScanHistoryManager: ObservableObject {
    public static let shared = ScanHistoryManager()
    
    @Published public private(set) var entries: [ScanHistoryEntry] = []
    
    private let maxEntriesPerType = 100
    private let fileQueue = DispatchQueue(label: "com.networkanalyst.history.fileio", qos: .background)
    
    private static var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ScanHistory", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private static var historyFileURL: URL {
        storageDirectory.appendingPathComponent("history.json")
    }
    
    public init() {
        loadFromDisk()
    }
    
    /// Thêm một bản ghi mới vào lịch sử (giới hạn 100 bản ghi mỗi loại)
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
        
        entries.insert(newEntry, at: 0)
        
        // Cắt tỉa nếu vượt quá giới hạn 100 bản ghi cho loại tác vụ này
        let countForType = entries.filter { $0.type == type }.count
        if countForType > maxEntriesPerType {
            if let lastIndex = entries.lastIndex(where: { $0.type == type }) {
                entries.remove(at: lastIndex)
            }
        }
        
        scheduleSaveToDisk()
    }
    
    /// Xóa một bản ghi theo định danh ID
    public func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        scheduleSaveToDisk()
    }
    
    /// Xóa toàn bộ lịch sử của một phân loại tác vụ cụ thể
    public func clearCategory(_ type: ScanHistoryType) {
        entries.removeAll { $0.type == type }
        scheduleSaveToDisk()
    }
    
    /// Xóa toàn bộ lịch sử quét
    public func clearHistory() {
        entries.removeAll()
        scheduleSaveToDisk()
    }
    
    // MARK: - Disk Persistence (JSON in Application Support)
    private func loadFromDisk() {
        let fileURL = Self.historyFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([ScanHistoryEntry].self, from: data)
            self.entries = loaded
        } catch {
            print("Lỗi nạp lịch sử quét từ đĩa: \(error.localizedDescription)")
        }
    }
    
    private func scheduleSaveToDisk() {
        let snapshot = self.entries
        let fileURL = Self.historyFileURL
        
        fileQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(snapshot)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("Lỗi ghi tệp lịch sử quét: \(error.localizedDescription)")
            }
        }
    }
}
