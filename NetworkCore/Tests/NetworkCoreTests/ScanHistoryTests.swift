//
//  ScanHistoryTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class ScanHistoryTests: XCTestCase {
    
    // MARK: - Test 1: Encode / Decode Round-trip với Versioned Schema
    func testEncodeDecodeRoundTrip() throws {
        var container = ScanHistoryContainer(entries: [], maxEntriesPerType: 100)
        let entry1 = ScanHistoryEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1700000000),
            type: .port,
            target: "192.168.1.1",
            summary: "3 cổng mở",
            details: "Port 80, 443, 8080"
        )
        let entry2 = ScanHistoryEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1700000100),
            type: .lan,
            target: "192.168.1.0/24",
            summary: "12 thiết bị phát hiện",
            details: nil
        )
        container.add(entry1)
        container.add(entry2)
        
        let data = try container.serialize()
        XCTAssertFalse(data.isEmpty)
        
        // Kiểm tra xem JSON có chứa schemaVersion = 1 không
        let jsonString = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(jsonString.contains("\"schemaVersion\" : 1"))
        
        let decoded = ScanHistoryContainer.deserialize(from: data)
        XCTAssertEqual(decoded.entries.count, 2)
        XCTAssertEqual(decoded.entries[0].id, entry2.id)
        XCTAssertEqual(decoded.entries[1].id, entry1.id)
        XCTAssertEqual(decoded.entries[0].target, "192.168.1.0/24")
    }
    
    // MARK: - Test 2: Vượt Giới Hạn 100 Bản Ghi Tự Động Bỏ Bản Ghi Cũ Nhất
    func testCategoryLimitDropsOldest() {
        var container = ScanHistoryContainer(entries: [], maxEntriesPerType: 100)
        
        // Thêm 105 bản ghi loại .port theo thứ tự
        for i in 0..<105 {
            let entry = ScanHistoryEntry(
                id: UUID(),
                timestamp: Date(timeIntervalSince1970: Double(i)),
                type: .port,
                target: "host-\(i)",
                summary: "Quét cổng lần \(i)"
            )
            container.add(entry)
        }
        
        // Tổng số bản ghi của loại .port phải dừng ở đúng 100
        let portEntries = container.entries.filter { $0.type == .port }
        XCTAssertEqual(portEntries.count, 100)
        
        // Bản ghi mới nhất (i = 104) phải nằm ở đầu (index 0)
        XCTAssertEqual(portEntries.first?.target, "host-104")
        
        // Bản ghi cũ nhất còn giữ lại phải là (i = 5)
        XCTAssertEqual(portEntries.last?.target, "host-5")
        
        // Các bản ghi cũ hơn (0, 1, 2, 3, 4) đã bị loại bỏ
        for oldIndex in 0..<5 {
            XCTAssertFalse(portEntries.contains { $0.target == "host-\(oldIndex)" })
        }
    }
    
    // MARK: - Test 3: Các Phân Loại Khác Nhau Không Ảnh Hưởng Lẫn Nhau
    func testIndependentCategoryLimits() {
        var container = ScanHistoryContainer(entries: [], maxEntriesPerType: 100)
        
        // Thêm 100 bản ghi .lan
        for i in 0..<100 {
            container.add(ScanHistoryEntry(type: .lan, target: "lan-\(i)", summary: ""))
        }
        
        // Thêm 100 bản ghi .ping
        for i in 0..<100 {
            container.add(ScanHistoryEntry(type: .ping, target: "ping-\(i)", summary: ""))
        }
        
        XCTAssertEqual(container.entries.filter { $0.type == .lan }.count, 100)
        XCTAssertEqual(container.entries.filter { $0.type == .ping }.count, 100)
        
        // Thêm 1 bản ghi .lan mới
        container.add(ScanHistoryEntry(type: .lan, target: "lan-newest", summary: ""))
        
        // .lan vẫn là 100 (bỏ bản ghi lan cũ nhất)
        XCTAssertEqual(container.entries.filter { $0.type == .lan }.count, 100)
        XCTAssertEqual(container.entries.first?.target, "lan-newest")
        
        // .ping vẫn giữ nguyên đầy đủ 100 bản ghi
        XCTAssertEqual(container.entries.filter { $0.type == .ping }.count, 100)
    }
    
    // MARK: - Test 4: Tệp JSON Hỏng Cú Pháp Tự Phục Hồi Về Rỗng (Không Crash)
    func testCorruptedJSONDoesNotCrash() {
        let corruptedData = "{\"schemaVersion\": 1, \"entries\": [ { malformed json invalid syntax ...".data(using: .utf8)!
        
        let container = ScanHistoryContainer.deserialize(from: corruptedData)
        XCTAssertEqual(container.entries.count, 0)
    }
    
    // MARK: - Test 5: Tệp Rỗng Tự Phục Hồi Về Rỗng (Không Crash)
    func testEmptyDataDoesNotCrash() {
        let emptyData = Data()
        let container = ScanHistoryContainer.deserialize(from: emptyData)
        XCTAssertEqual(container.entries.count, 0)
    }
    
    // MARK: - Test 6: Xóa Bản Ghi Cụ Thể Và Xóa Phân Loại
    func testDeletionAndClearOperations() {
        var container = ScanHistoryContainer(entries: [], maxEntriesPerType: 100)
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        
        container.add(ScanHistoryEntry(id: id1, type: .dns, target: "apple.com", summary: ""))
        container.add(ScanHistoryEntry(id: id2, type: .dns, target: "google.com", summary: ""))
        container.add(ScanHistoryEntry(id: id3, type: .rdap, target: "cloudflare.com", summary: ""))
        
        XCTAssertEqual(container.entries.count, 3)
        
        // Xóa một mục theo id
        container.remove(id: id1)
        XCTAssertEqual(container.entries.count, 2)
        XCTAssertFalse(container.entries.contains { $0.id == id1 })
        
        // Xóa theo category .dns
        container.clearCategory(.dns)
        XCTAssertEqual(container.entries.count, 1)
        XCTAssertEqual(container.entries.first?.id, id3)
        
        // Xóa toàn bộ
        container.clearAll()
        XCTAssertEqual(container.entries.count, 0)
    }
}
