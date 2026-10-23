//
//  RDAPParserTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class RDAPParserTests: XCTestCase {
    
    func testParseDomainRDAP() throws {
        // Dữ liệu fixture mẫu tự soạn theo chuẩn RFC 7483 (không phải trích từ phản hồi thật từ mạng)
        let domainFixtureSynthetic = """
        {
            "objectClassName": "domain",
            "handle": "2138514_DOMAIN_COM-VRSN",
            "ldhName": "apple.com",
            "status": ["client delete prohibited", "client transfer prohibited"],
            "events": [
                { "eventAction": "registration", "eventDate": "1987-02-19T05:00:00Z" },
                { "eventAction": "expiration", "eventDate": "2027-02-20T05:00:00Z" },
                { "eventAction": "last changed", "eventDate": "2024-01-15T10:30:00Z" }
            ],
            "entities": [
                {
                    "roles": ["registrar"],
                    "handle": "292",
                    "vcardArray": [
                        "vcard",
                        [
                            ["version", {}, "text", "4.0"],
                            ["fn", {}, "text", "MarkMonitor Inc."],
                            ["org", {}, "text", "MarkMonitor Inc."]
                        ]
                    ]
                },
                {
                    "roles": ["registrant"],
                    "vcardArray": [
                        "vcard",
                        [
                            ["version", {}, "text", "4.0"],
                            ["fn", {}, "text", "Apple Inc."],
                            ["org", {}, "text", "Apple Inc."],
                            ["email", {}, "text", "domains@apple.com"]
                        ]
                    ]
                }
            ],
            "nameservers": [
                { "ldhName": "a.ns.apple.com" },
                { "ldhName": "b.ns.apple.com" }
            ]
        }
        """
        
        let data = Data(domainFixtureSynthetic.utf8)
        let record = try RDAPParser.parse(data: data, query: "apple.com", queryType: .domain)
        
        XCTAssertEqual(record.query, "apple.com")
        XCTAssertEqual(record.queryType, .domain)
        XCTAssertEqual(record.title, "apple.com")
        XCTAssertEqual(record.handle, "2138514_DOMAIN_COM-VRSN")
        XCTAssertEqual(record.registrarOrOrg, "MarkMonitor Inc.")
        XCTAssertEqual(record.registrantName, "Apple Inc.")
        XCTAssertEqual(record.registrationDate, "1987-02-19T05:00:00Z")
        XCTAssertEqual(record.expirationDate, "2027-02-20T05:00:00Z")
        XCTAssertEqual(record.lastUpdatedDate, "2024-01-15T10:30:00Z")
        XCTAssertEqual(record.status.count, 2)
        XCTAssertEqual(record.nameservers, ["a.ns.apple.com", "b.ns.apple.com"])
        XCTAssertEqual(record.contacts.count, 2)
        XCTAssertEqual(record.contacts[1].email, "domains@apple.com")
    }
    
    func testParseIPNetworkRDAP() throws {
        // Dữ liệu fixture mẫu tự soạn cho IP Network theo chuẩn RFC 7483 (không phải trích từ phản hồi thật từ mạng)
        let ipFixtureSynthetic = """
        {
            "objectClassName": "ip network",
            "handle": "NET-8-8-8-0-1",
            "startAddress": "8.8.8.0",
            "endAddress": "8.8.8.255",
            "ipVersion": "v4",
            "name": "LVLT-GOGL-8-8-8",
            "type": "DIRECT ALLOCATION",
            "cidr0_cidrs": [
                { "v4prefix": "8.8.8.0", "length": 24 }
            ],
            "status": ["active"],
            "events": [
                { "eventAction": "registration", "eventDate": "2014-03-14T00:00:00Z" }
            ],
            "entities": [
                {
                    "roles": ["registrant"],
                    "vcardArray": [
                        "vcard",
                        [
                            ["version", {}, "text", "4.0"],
                            ["fn", {}, "text", "Google LLC"],
                            ["org", {}, "text", "Google LLC"]
                        ]
                    ]
                }
            ]
        }
        """
        
        let data = Data(ipFixtureSynthetic.utf8)
        let record = try RDAPParser.parse(data: data, query: "8.8.8.8", queryType: .ip)
        
        XCTAssertEqual(record.query, "8.8.8.8")
        XCTAssertEqual(record.queryType, .ip)
        XCTAssertEqual(record.title, "LVLT-GOGL-8-8-8")
        XCTAssertEqual(record.cidrOrRange, "8.8.8.0/24")
        XCTAssertEqual(record.registrantName, "Google LLC")
        XCTAssertEqual(record.registrationDate, "2014-03-14T00:00:00Z")
        XCTAssertNil(record.expirationDate)
    }
    
    func testParseASNRDAP() throws {
        // Dữ liệu fixture mẫu tự soạn cho ASN theo chuẩn RFC 7483 (không phải trích từ phản hồi thật từ mạng)
        let asnFixtureSynthetic = """
        {
            "objectClassName": "autnum",
            "handle": "AS15169",
            "startAutnum": 15169,
            "endAutnum": 15169,
            "name": "GOOGLE",
            "status": ["active"],
            "events": [
                { "eventAction": "registration", "eventDate": "2000-03-30T00:00:00Z" }
            ],
            "entities": [
                {
                    "roles": ["registrant"],
                    "vcardArray": [
                        "vcard",
                        [
                            ["version", {}, "text", "4.0"],
                            ["fn", {}, "text", "Google LLC"]
                        ]
                    ]
                }
            ]
        }
        """
        
        let data = Data(asnFixtureSynthetic.utf8)
        let record = try RDAPParser.parse(data: data, query: "AS15169", queryType: .asn)
        
        XCTAssertEqual(record.queryType, .asn)
        XCTAssertEqual(record.title, "GOOGLE")
        XCTAssertEqual(record.cidrOrRange, "AS15169")
        XCTAssertEqual(record.registrantName, "Google LLC")
        XCTAssertEqual(record.registrationDate, "2000-03-30T00:00:00Z")
    }
    
    func testParseInvalidJSONThrows() {
        let malformed = Data("This is not JSON".utf8)
        XCTAssertThrowsError(try RDAPParser.parse(data: malformed, query: "bad", queryType: .domain))
    }
    
    func testRDAPBootstrapDetection() {
        let (q1, t1) = RDAPBootstrap.detectQueryType(from: "AS15169")
        XCTAssertEqual(q1, "15169")
        XCTAssertEqual(t1, .asn)
        
        let (q2, t2) = RDAPBootstrap.detectQueryType(from: "as13335")
        XCTAssertEqual(q2, "13335")
        XCTAssertEqual(t2, .asn)
        
        let (q3, t3) = RDAPBootstrap.detectQueryType(from: "1.1.1.1")
        XCTAssertEqual(q3, "1.1.1.1")
        XCTAssertEqual(t3, .ip)
        
        let (q4, t4) = RDAPBootstrap.detectQueryType(from: "2606:4700:4700::1111")
        XCTAssertEqual(q4, "2606:4700:4700::1111")
        XCTAssertEqual(t4, .ip)
        
        let (q5, t5) = RDAPBootstrap.detectQueryType(from: "https://apple.com/")
        XCTAssertEqual(q5, "apple.com")
        XCTAssertEqual(t5, .domain)
    }
}
