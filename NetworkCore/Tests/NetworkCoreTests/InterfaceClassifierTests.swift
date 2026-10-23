//
//  InterfaceClassifierTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class InterfaceClassifierTests: XCTestCase {
    
    let iffUp: UInt32 = InterfaceClassifier.iffUp
    let iffRunning: UInt32 = InterfaceClassifier.iffRunning
    let iffLoopback: UInt32 = InterfaceClassifier.iffLoopback
    
    func testWiFiClassification() {
        // en0 trên iOS luôn là Wi-Fi
        let t = InterfaceClassifier.classify(name: "en0", flags: iffUp | iffRunning, ipv4: ["192.168.1.50"])
        XCTAssertEqual(t, .wifi)
    }
    
    func testEthernetClassification() {
        // en1, en2 khi cắm USB-C / Lightning Ethernet adapter
        let t1 = InterfaceClassifier.classify(name: "en1", flags: iffUp | iffRunning, ipv4: ["10.0.0.15"])
        XCTAssertEqual(t1, .ethernet)
        
        let t2 = InterfaceClassifier.classify(name: "en2", flags: iffUp | iffRunning)
        XCTAssertEqual(t2, .ethernet)
    }
    
    func testCellularClassification() {
        // pdp_ip0 là mạng 4G/5G di động trên iOS
        let t = InterfaceClassifier.classify(name: "pdp_ip0", flags: iffUp | iffRunning, ipv4: ["10.45.12.3"])
        XCTAssertEqual(t, .cellular)
    }
    
    func testActiveVPNClassification() {
        // utun0 đang hoạt động VÀ có IP được gán -> VPN
        let t = InterfaceClassifier.classify(name: "utun2", flags: iffUp | iffRunning, ipv4: ["10.8.0.2"])
        XCTAssertEqual(t, .vpn)
        
        // ipsec0 đang hoạt động và có IPv6
        let t2 = InterfaceClassifier.classify(name: "ipsec0", flags: iffUp, ipv6: ["2001:db8::1"])
        XCTAssertEqual(t2, .vpn)
    }
    
    func testInactiveOrNoIPUtunNotClassifiedAsVPN() {
        // RÀNG BUỘC ĐẶC BIỆT: utun* tồn tại nhưng KHÔNG có IP được gán -> KHÔNG được gắn nhãn VPN
        let tNoIP = InterfaceClassifier.classify(name: "utun0", flags: iffUp | iffRunning, ipv4: [], ipv6: [])
        XCTAssertNotEqual(tNoIP, .vpn)
        XCTAssertEqual(tNoIP, .other("utun0"))
        
        // utun có IP nhưng cờ UP = 0 (tắt) -> Không gắn nhãn VPN
        let tDown = InterfaceClassifier.classify(name: "utun1", flags: 0, ipv4: ["10.8.0.3"])
        XCTAssertNotEqual(tDown, .vpn)
    }
    
    func testHotspotClassification() {
        let t1 = InterfaceClassifier.classify(name: "bridge0", flags: iffUp)
        XCTAssertEqual(t1, .hotspot)
        
        let t2 = InterfaceClassifier.classify(name: "ap0", flags: iffUp)
        XCTAssertEqual(t2, .hotspot)
    }
    
    func testLoopbackClassification() {
        let t1 = InterfaceClassifier.classify(name: "lo0", flags: iffLoopback)
        XCTAssertEqual(t1, .loopback)
    }
}
