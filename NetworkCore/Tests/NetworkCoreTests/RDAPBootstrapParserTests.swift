//
//  RDAPBootstrapParserTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class RDAPBootstrapParserTests: XCTestCase {
    
    func testParseDNSServicesFixtureSynthetic() throws {
        // Dữ liệu fixture tự soạn theo định dạng RFC 9224 dns.json của IANA
        let dnsBootstrapFixtureSynthetic = """
        {
            "version": "1.0",
            "publication": "2024-01-01T00:00:00Z",
            "description": "Synthetic IANA RDAP bootstrap fixture for DNS",
            "services": [
                [
                    ["com", "net"],
                    ["https://rdap.verisign.com/com/v1/"]
                ],
                [
                    ["org"],
                    ["https://rdap.publicinterestregistry.org/rdap/"]
                ],
                [
                    ["vn"],
                    ["https://rdap.vnnic.vn/"]
                ]
            ]
        }
        """
        
        let data = Data(dnsBootstrapFixtureSynthetic.utf8)
        let mapping = try RDAPBootstrapParser.parse(data: data)
        
        XCTAssertEqual(mapping["com"], "https://rdap.verisign.com/com/v1/")
        XCTAssertEqual(mapping["net"], "https://rdap.verisign.com/com/v1/")
        XCTAssertEqual(mapping["org"], "https://rdap.publicinterestregistry.org/rdap/")
        XCTAssertEqual(mapping["vn"], "https://rdap.vnnic.vn/")
        XCTAssertNil(mapping["xyz"])
    }
    
    func testParseIPv4ServicesFixtureSynthetic() throws {
        // Dữ liệu fixture tự soạn theo định dạng RFC 9224 ipv4.json của IANA
        let ipv4BootstrapFixtureSynthetic = """
        {
            "version": "1.0",
            "publication": "2024-01-01T00:00:00Z",
            "services": [
                [
                    ["8.0.0.0/8", "9.0.0.0/8"],
                    ["https://rdap.arin.net/registry/"]
                ],
                [
                    ["1.0.0.0/8"],
                    ["https://rdap.apnic.net/"]
                ]
            ]
        }
        """
        
        let data = Data(ipv4BootstrapFixtureSynthetic.utf8)
        let mapping = try RDAPBootstrapParser.parse(data: data)
        
        XCTAssertEqual(mapping["8.0.0.0/8"], "https://rdap.arin.net/registry/")
        XCTAssertEqual(mapping["9.0.0.0/8"], "https://rdap.arin.net/registry/")
        XCTAssertEqual(mapping["1.0.0.0/8"], "https://rdap.apnic.net/")
    }
    
    func testParseEmptyOrMalformedServicesThrows() {
        let malformed = Data("{\"version\": \"1.0\"}".utf8)
        XCTAssertThrowsError(try RDAPBootstrapParser.parse(data: malformed))
    }
}
