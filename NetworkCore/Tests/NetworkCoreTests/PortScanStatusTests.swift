//
//  PortScanStatusTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class PortScanStatusTests: XCTestCase {
    
    func testOpenStatusWhenConnected() {
        let status = PortStatusClassifier.classify(
            isConnected: true,
            isTimedOut: false,
            errorCode: nil
        )
        XCTAssertEqual(status, .open)
    }
    
    func testClosedStatusOnECONNREFUSED() {
        // ECONNREFUSED = 61 trên Darwin (RST nhận từ host)
        let status = PortStatusClassifier.classify(
            isConnected: false,
            isTimedOut: false,
            errorCode: PortStatusClassifier.posixECONNREFUSED
        )
        XCTAssertEqual(status, .closed)
    }
    
    func testFilteredStatusOnTimeout() {
        let status = PortStatusClassifier.classify(
            isConnected: false,
            isTimedOut: true,
            errorCode: nil
        )
        XCTAssertEqual(status, .filtered)
        
        let status2 = PortStatusClassifier.classify(
            isConnected: false,
            isTimedOut: false,
            errorCode: PortStatusClassifier.posixETIMEDOUT
        )
        XCTAssertEqual(status2, .filtered)
    }
    
    func testLocalNetworkPermissionDeniedNotClassifiedAsClosed() {
        // RÀNG BUỘC QUAN TRỌNG: Lỗi quyền mạng cục bộ (PolicyDenied / EPERM) KHÔNG ĐƯỢC gộp vào Closed!
        let status1 = PortStatusClassifier.classify(
            isConnected: false,
            isTimedOut: false,
            errorCode: PortStatusClassifier.policyDeniedDNS
        )
        XCTAssertNotEqual(status1, .closed)
        XCTAssertEqual(status1, .error("Quyền Mạng cục bộ bị từ chối"))
        
        let status2 = PortStatusClassifier.classify(
            isConnected: false,
            isTimedOut: false,
            errorCode: PortStatusClassifier.posixEPERM
        )
        XCTAssertNotEqual(status2, .closed)
        XCTAssertEqual(status2, .error("Quyền Mạng cục bộ bị từ chối"))
    }
    
    func testHostUnreachableClassifiedAsError() {
        let status = PortStatusClassifier.classify(
            isConnected: false,
            isTimedOut: false,
            errorCode: PortStatusClassifier.posixEHOSTUNREACH
        )
        XCTAssertNotEqual(status, .closed)
        XCTAssertEqual(status, .error("Host/Network không thể tiếp cận"))
    }
    
    func testServiceNameMapping() {
        XCTAssertEqual(PortStatusClassifier.serviceName(for: 80), "HTTP")
        XCTAssertEqual(PortStatusClassifier.serviceName(for: 443), "HTTPS")
        XCTAssertEqual(PortStatusClassifier.serviceName(for: 22), "SSH / SFTP")
        XCTAssertEqual(PortStatusClassifier.serviceName(for: 53), "DNS")
        XCTAssertEqual(PortStatusClassifier.serviceName(for: 3389), "RDP (Remote Desktop)")
    }
}
