//
//  PortRangeParserTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class PortRangeParserTests: XCTestCase {
    
    func testSingleAndMultiplePorts() {
        let result = PortRangeParser.parse("80, 443, 8080")
        switch result {
        case .success(let ports):
            XCTAssertEqual(ports, [80, 443, 8080])
        case .failure(let err):
            XCTFail("Unexpected error: \(err)")
        }
    }
    
    func testPortRangeHyphenSyntax() {
        let result = PortRangeParser.parse("8000-8005")
        switch result {
        case .success(let ports):
            XCTAssertEqual(ports, [8000, 8001, 8002, 8003, 8004, 8005])
        case .failure(let err):
            XCTFail("Unexpected error: \(err)")
        }
    }
    
    func testCombinedRangeWithDeduplication() {
        let result = PortRangeParser.parse("80, 443, 8000-8003, 80, 8002")
        switch result {
        case .success(let ports):
            XCTAssertEqual(ports, [80, 443, 8000, 8001, 8002, 8003])
        case .failure(let err):
            XCTFail("Unexpected error: \(err)")
        }
    }
    
    func testInvertedRangeReturnsError() {
        let result = PortRangeParser.parse("8080-8000")
        switch result {
        case .success:
            XCTFail("Must fail for inverted bounds")
        case .failure(let err):
            XCTAssertEqual(err, .invertedRange(start: 8080, end: 8000))
        }
    }
    
    func testOutOfRangePorts() {
        let result1 = PortRangeParser.parse("0")
        XCTAssertEqual(result1, .failure(.portOutOfRange(0)))
        
        let result2 = PortRangeParser.parse("70000")
        XCTAssertEqual(result2, .failure(.portOutOfRange(70000)))
        
        let result3 = PortRangeParser.parse("80, 65536")
        XCTAssertEqual(result3, .failure(.portOutOfRange(65536)))
    }
    
    func testInvalidTokenString() {
        let result = PortRangeParser.parse("80, abc, 443")
        XCTAssertEqual(result, .failure(.invalidToken("abc")))
    }
    
    func testEmptyInputReturnsError() {
        let result = PortRangeParser.parse("   ")
        XCTAssertEqual(result, .failure(.emptyInput))
    }
    
    func testDurationEstimation() {
        // 65535 ports với concurrency 200, timeout 0.8s
        let (seconds, display) = PortRangeParser.estimateScanDuration(portCount: 65535, concurrency: 200, averageTimeoutSeconds: 0.8)
        XCTAssertGreaterThan(seconds, 60.0)
        XCTAssertTrue(display.contains("phút"))
        
        // 20 ports với concurrency 200
        let (sec20, display20) = PortRangeParser.estimateScanDuration(portCount: 20, concurrency: 200, averageTimeoutSeconds: 0.8)
        XCTAssertLessThan(sec20, 10.0)
        XCTAssertTrue(display20.contains("giây"))
    }
}
