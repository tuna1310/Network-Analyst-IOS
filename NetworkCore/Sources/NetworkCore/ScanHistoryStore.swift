//
//  ScanHistoryStore.swift
//  NetworkCore
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation

/// Phân loại tác vụ mạng được ghi nhận trong lịch sử
public enum ScanHistoryType: String, Codable, CaseIterable, Identifiable, Sendable {
    case lan = "lan"
    case port = "port"
    case ping = "ping"
    case traceroute = "traceroute"
    case dns = "dns"
    case rdap = "rdap"
    
    public var id: String { rawValue }
    
    public var localizedTitle: String {
        switch self {
        case .lan: return "Quét mạng LAN"
        case .port: return "Quét cổng TCP"
        case .ping: return "Kiểm tra Ping"
        case .traceroute: return "Dò tuyến Traceroute"
        case .dns: return "Tra cứu DNS"
        case .rdap: return "WHOIS / RDAP"
        }
    }
    
    public var iconName: String {
        switch self {
        case .lan: return "network"
        case .port: return "server.rack"
        case .ping: return "waveform.path.ecg"
        case .traceroute: return "point.topleft.down.curvedto.point.bottomright.up"
        case .dns: return "text.magnifyingglass"
        case .rdap: return "globe.americas.fill"
        }
    }
}

/// Một bản ghi lịch sử quét mạng (Codable, Sendable, Equatable)
public struct ScanHistoryEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let type: ScanHistoryType
    public let target: String
    public let summary: String
    public let details: String?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ScanHistoryType,
        target: String,
        summary: String,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.target = target
        self.summary = summary
        self.details = details
    }
}

/// Cấu trúc tệp tin lưu trữ lịch sử có hỗ trợ Schema Versioning
public struct ScanHistoryDocument: Codable, Sendable {
    public static let currentSchemaVersion = 1
    
    public let schemaVersion: Int
    public let entries: [ScanHistoryEntry]
    
    public init(schemaVersion: Int = currentSchemaVersion, entries: [ScanHistoryEntry]) {
        self.schemaVersion = schemaVersion
        self.entries = entries
    }
}

/// Bộ chứa logic thuần quản lý lịch sử quét:
/// - Giới hạn tối đa 100 bản ghi mỗi loại tác vụ (tự động loại bỏ bản ghi cũ nhất khi đầy)
/// - Đọc tệp hỏng hoặc rỗng sẽ tự phục hồi về danh sách rỗng mà không crash
/// - Tuân thủ Schema Versioning để di chuyển dữ liệu an toàn trong tương lai
public struct ScanHistoryContainer: Sendable, Equatable {
    public private(set) var entries: [ScanHistoryEntry]
    public let maxEntriesPerType: Int
    
    public init(entries: [ScanHistoryEntry] = [], maxEntriesPerType: Int = 100) {
        self.entries = entries
        self.maxEntriesPerType = maxEntriesPerType
    }
    
    /// Thêm một bản ghi mới vào đầu danh sách và cắt tỉa bản ghi cũ nếu vượt giới hạn
    public mutating func add(_ entry: ScanHistoryEntry) {
        entries.insert(entry, at: 0)
        
        let countForType = entries.filter { $0.type == entry.type }.count
        if countForType > maxEntriesPerType {
            if let oldestIndex = entries.lastIndex(where: { $0.type == entry.type }) {
                entries.remove(at: oldestIndex)
            }
        }
    }
    
    /// Xóa một bản ghi theo UUID
    public mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }
    
    /// Xóa toàn bộ bản ghi của một phân loại
    public mutating func clearCategory(_ type: ScanHistoryType) {
        entries.removeAll { $0.type == type }
    }
    
    /// Xóa toàn bộ lịch sử
    public mutating func clearAll() {
        entries.removeAll()
    }
    
    /// Mã hóa thành Data JSON kèm thông tin schemaVersion
    public func serialize() throws -> Data {
        let doc = ScanHistoryDocument(schemaVersion: ScanHistoryDocument.currentSchemaVersion, entries: self.entries)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(doc)
    }
    
    /// Giải mã từ Data JSON. Nếu dữ liệu rỗng hoặc tệp bị hỏng, trả về container rỗng thay vì ném lỗi/crash.
    public static func deserialize(from data: Data, maxEntriesPerType: Int = 100) -> ScanHistoryContainer {
        guard !data.isEmpty else {
            return ScanHistoryContainer(entries: [], maxEntriesPerType: maxEntriesPerType)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 1. Thử giải mã theo tài liệu có version schema
        if let doc = try? decoder.decode(ScanHistoryDocument.self, from: data) {
            return ScanHistoryContainer(entries: doc.entries, maxEntriesPerType: maxEntriesPerType)
        }
        
        // 2. Dự phòng giải mã định dạng mảng JSON cũ [ScanHistoryEntry]
        if let rawList = try? decoder.decode([ScanHistoryEntry].self, from: data) {
            return ScanHistoryContainer(entries: rawList, maxEntriesPerType: maxEntriesPerType)
        }
        
        // 3. Tệp bị hỏng cú pháp JSON -> Khởi tạo lại từ danh sách rỗng để bảo vệ app khỏi crash
        return ScanHistoryContainer(entries: [], maxEntriesPerType: maxEntriesPerType)
    }
}
