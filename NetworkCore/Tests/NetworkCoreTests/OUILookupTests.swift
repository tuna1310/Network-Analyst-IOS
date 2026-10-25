//
//  OUILookupTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class OUILookupTests: XCTestCase {
    
    func testMACNormalizationWithStandardColons() {
        let mac = "00:50:56:A1:B2:C3"
        let normalized = OUIDatabase.normalizeMAC(mac)
        XCTAssertEqual(normalized, "005056A1B2C3")
        
        let oui = OUIDatabase.extractOUI24(from: mac)
        XCTAssertEqual(oui, "005056")
    }
    
    func testMACNormalizationWithHyphens() {
        let mac = "F0-18-98-12-34-56"
        let normalized = OUIDatabase.normalizeMAC(mac)
        XCTAssertEqual(normalized, "F01898123456")
        
        let oui = OUIDatabase.extractOUI24(from: mac)
        XCTAssertEqual(oui, "F01898")
    }
    
    func testMACNormalizationWithCiscoDotFormatAndLowercase() {
        let mac = "f018.9812.3456"
        let normalized = OUIDatabase.normalizeMAC(mac)
        XCTAssertEqual(normalized, "F01898123456")
        
        let oui = OUIDatabase.extractOUI24(from: mac)
        XCTAssertEqual(oui, "F01898")
    }
    
    func testMACNormalizationWithNoSeparators() {
        let mac = "001A11223344"
        let oui = OUIDatabase.extractOUI24(from: mac)
        XCTAssertEqual(oui, "001A11")
    }
    
    func testRandomizedMACDetection() {
        // Bit 1 của byte đầu = 1 (LAA / Locally Administered)
        // 0x02 = 0000 0010 (bit 1 is 1)
        XCTAssertTrue(OUIDatabase.isLocallyAdministered(mac: "02:00:00:11:22:33"))
        
        // 0xDA = 1101 1010 (bit 1 is 1) -> Địa chỉ Wi-Fi riêng tư phổ biến trên iOS
        XCTAssertTrue(OUIDatabase.isLocallyAdministered(mac: "DA:A1:19:44:55:66"))
        
        // 0xF6 = 1111 0110 (bit 1 is 1)
        XCTAssertTrue(OUIDatabase.isLocallyAdministered(mac: "f6-12-34-56-78-90"))
        
        // 0xAE = 1010 1110 (bit 1 is 1)
        XCTAssertTrue(OUIDatabase.isLocallyAdministered(mac: "ae12.3456.7890"))
        
        // Địa chỉ UAA thật của Apple (0xF0 = 1111 0000 -> bit 1 is 0)
        XCTAssertFalse(OUIDatabase.isLocallyAdministered(mac: "F0:18:98:AA:BB:CC"))
        
        // Địa chỉ UAA thật của VMware (0x00 = 0000 0000 -> bit 1 is 0)
        XCTAssertFalse(OUIDatabase.isLocallyAdministered(mac: "00:50:56:11:22:33"))
        
        // Kiểm tra hàm lookupDetail trả về .randomized
        let db = OUIDatabase(customDictionary: ["F01898": "Apple, Inc."])
        XCTAssertEqual(db.lookupDetail(mac: "DA:A1:19:11:22:33"), .randomized)
        XCTAssertEqual(db.lookup(mac: "DA:A1:19:11:22:33"), "Private / Randomized MAC")
    }
    
    func testInvalidShortMACAddress() {
        let invalid = "12:34"
        XCTAssertNil(OUIDatabase.normalizeMAC(invalid))
        XCTAssertNil(OUIDatabase.extractOUI24(from: invalid))
        XCTAssertFalse(OUIDatabase.isLocallyAdministered(mac: invalid))
    }
    
    func testOUILookupWithCustomDictionary() {
        let testData = [
            "F01898": "Apple, Inc.",
            "005056": "VMware, Inc.",
            "001A11": "Google, Inc.",
            "70B3D5E": "Test Organization MA-M, Ltd.", // 28-bit OUI MA-M
            "70B3D5000": "IEEE Registration Authority" // 36-bit OUI MA-S
        ]
        
        let db = OUIDatabase(customDictionary: testData)
        XCTAssertEqual(db.entryCount, 5)
        
        XCTAssertEqual(db.lookup(mac: "f0:18:98:aa:bb:cc"), "Apple, Inc.")
        XCTAssertEqual(db.lookup(mac: "00-50-56-11-22-33"), "VMware, Inc.")
        XCTAssertEqual(db.lookup(mac: "001a.1100.2244"), "Google, Inc.")
        
        // 28-bit lookup (MA-M)
        XCTAssertEqual(db.lookup(mac: "70:B3:D5:E1:23:45"), "Test Organization MA-M, Ltd.")
        
        // 36-bit lookup (MA-S)
        XCTAssertEqual(db.lookup(mac: "70:B3:D5:00:01:23"), "IEEE Registration Authority")
        
        // MAC hợp lệ nhưng không có trong database
        XCTAssertNil(db.lookup(mac: "00:11:22:33:44:55"))
    }
    
    func testBundledResourceLoadingFromPackageModule() {
        // Kiểm tra instance shared nạp oui.json từ Bundle.module thành công
        let sharedDB = OUIDatabase.shared
        XCTAssertGreaterThan(sharedDB.entryCount, 0, "Resource oui.json trong Bundle.module phải được nạp và có bản ghi")
        
        // Tra cứu địa chỉ MAC VMware 00:50:56 có sẵn trong file oui.json bundled
        let vendor = sharedDB.lookup(mac: "00:50:56:11:22:33")
        XCTAssertEqual(vendor, "VMware, Inc.", "Tra cứu địa chỉ MAC mẫu từ resource bundle phải trả về tên nhà sản xuất")
    }
}
