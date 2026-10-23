//
//  WhoisReferralParserTests.swift
//  NetworkCoreTests
//
//  Created for iOS 16+, Swift 5.9+
//

import XCTest
@testable import NetworkCore

final class WhoisReferralParserTests: XCTestCase {
    
    func testExtractReferralFromIANAResponse() {
        let sampleIANAWhois = """
        % IANA WHOIS server
        % for more information on IANA, visit http://www.iana.org
        % This query returned 1 object
        
        refer:        whois.verisign-grs.com
        
        domain:       COM
        organisation: VeriSign Global Registry Services
        """
        
        let server = WhoisReferralParser.extractReferralServer(from: sampleIANAWhois)
        XCTAssertEqual(server, "whois.verisign-grs.com")
    }
    
    func testExtractReferralFromVerisignResponse() {
        let sampleVerisignWhois = """
           Domain Name: APPLE.COM
           Registry Domain ID: 2138514_DOMAIN_COM-VRSN
           Registrar WHOIS Server: whois.markmonitor.com
           Registrar URL: http://www.markmonitor.com
           Updated Date: 2024-01-15T10:30:00Z
           Creation Date: 1987-02-19T05:00:00Z
        """
        
        let server = WhoisReferralParser.extractReferralServer(from: sampleVerisignWhois)
        XCTAssertEqual(server, "whois.markmonitor.com")
    }
    
    func testExtractReferralWithPortAndWhitespace() {
        let sampleWithPort = """
        referralserver:  whois.ripe.net:43/
        status: allocated
        """
        
        let server = WhoisReferralParser.extractReferralServer(from: sampleWithPort)
        XCTAssertEqual(server, "whois.ripe.net")
    }
    
    func testExtractReferralWithRWhoisPrefix() {
        let sampleRWhois = """
        refer: rwhois://rwhois.cogentco.com:4321/auth
        """
        let server = WhoisReferralParser.extractReferralServer(from: sampleRWhois)
        XCTAssertEqual(server, "rwhois.cogentco.com")
    }
    
    func testNoReferralFound() {
        let plainWhois = """
        Domain Name: test.org
        Registry Domain ID: D123456
        Creation Date: 2010-01-01
        """
        let server = WhoisReferralParser.extractReferralServer(from: plainWhois)
        XCTAssertNil(server)
    }
}
