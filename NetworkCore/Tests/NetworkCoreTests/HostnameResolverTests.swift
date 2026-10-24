//
//  HostnameResolverTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class HostnameResolverTests: XCTestCase {
    
    // MARK: - Test 1: Priority Hierarchy (mDNS > NetBIOS > LLMNR > PTR)
    func testPriorityHierarchyAllPresent() {
        let best = HostnameResolver.resolveBestHostname(
            mDNS: "my-macbook.local.",
            netBIOS: "DESKTOP-PC",
            llmnr: "synology-nas",
            ptr: "host-42.lan"
        )
        
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.name, "my-macbook.local")
        XCTAssertEqual(best?.source, .mDNS)
    }
    
    // MARK: - Test 2: Fallback to NetBIOS when mDNS is absent
    func testFallbackToNetBIOS() {
        let best = HostnameResolver.resolveBestHostname(
            mDNS: nil,
            netBIOS: "WINSERVER2022",
            llmnr: "synology-nas",
            ptr: "host-10.lan"
        )
        
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.name, "WINSERVER2022")
        XCTAssertEqual(best?.source, .netBIOS)
    }
    
    // MARK: - Test 3: Fallback to LLMNR when mDNS & NetBIOS absent
    func testFallbackToLLMNR() {
        let best = HostnameResolver.resolveBestHostname(
            mDNS: "  ",
            netBIOS: "(null)",
            llmnr: "PRINTER-EPSON",
            ptr: "printer.localdomain"
        )
        
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.name, "PRINTER-EPSON")
        XCTAssertEqual(best?.source, .llmnr)
    }
    
    // MARK: - Test 4: Fallback to PTR when only PTR available
    func testFallbackToPTR() {
        let best = HostnameResolver.resolveBestHostname(
            mDNS: nil,
            netBIOS: nil,
            llmnr: nil,
            ptr: "gateway.router.home."
        )
        
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.name, "gateway.router.home")
        XCTAssertEqual(best?.source, .ptr)
    }
    
    // MARK: - Test 5: All invalid returns nil
    func testAllInvalidReturnsNil() {
        let best = HostnameResolver.resolveBestHostname(
            mDNS: "",
            netBIOS: "unknown",
            llmnr: "(null)",
            ptr: "localhost"
        )
        
        XCTAssertNil(best)
    }
    
    // MARK: - Test 6: Hostname sanitization
    func testSanitization() {
        XCTAssertEqual(HostnameResolver.sanitizeHostname("  server.local.  "), "server.local")
        XCTAssertEqual(HostnameResolver.sanitizeHostname("DEVICE\0\0"), "DEVICE")
        XCTAssertNil(HostnameResolver.sanitizeHostname(nil))
        XCTAssertNil(HostnameResolver.sanitizeHostname(""))
        XCTAssertNil(HostnameResolver.sanitizeHostname("   "))
        XCTAssertNil(HostnameResolver.sanitizeHostname("unknown"))
        XCTAssertNil(HostnameResolver.sanitizeHostname("(null)"))
        XCTAssertNil(HostnameResolver.sanitizeHostname("localhost"))
    }
    
    // MARK: - Test 7: IPv4 in-addr.arpa conversion
    func testIPv4ReverseDomain() {
        XCTAssertEqual(HostnameResolver.ipv4ToReverseDomain("192.168.1.100"), "100.1.168.192.in-addr.arpa")
        XCTAssertEqual(HostnameResolver.ipv4ToReverseDomain("10.0.0.1"), "1.0.0.10.in-addr.arpa")
        XCTAssertNil(HostnameResolver.ipv4ToReverseDomain("999.1.1.1"))
        XCTAssertNil(HostnameResolver.ipv4ToReverseDomain("invalid-ip"))
    }
    
    // MARK: - Test 8: IPv6 ip6.arpa conversion
    func testIPv6ReverseDomain() {
        // 2001:db8::1
        let reverse = HostnameResolver.ipv6ToReverseDomain("2001:db8::1")
        XCTAssertNotNil(reverse)
        XCTAssertTrue(reverse!.hasSuffix(".ip6.arpa"))
        XCTAssertTrue(reverse!.hasPrefix("1.0.0.0.0.0.0.0."))
    }
}
