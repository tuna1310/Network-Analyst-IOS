//
//  BonjourBrowser.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Network

/// Đại diện cho kết quả dịch vụ Bonjour được tìm thấy
public struct BonjourDiscoveredService: Sendable {
    public let name: String
    public let serviceType: String
    public let domain: String
    public let ipAddress: String?
    public let txtRecord: [String: String]
    
    public init(name: String, serviceType: String, domain: String, ipAddress: String?, txtRecord: [String: String] = [:]) {
        self.name = name
        self.serviceType = serviceType
        self.domain = domain
        self.ipAddress = ipAddress
        self.txtRecord = txtRecord
    }
}

/// Trình duyệt Bonjour sử dụng NWBrowser để quét các dịch vụ LAN
public actor BonjourBrowser {
    private var browsers: [NWBrowser] = []
    private var isBrowsing: Bool = false
    
    public static let commonServiceTypes = [
        "_http._tcp",
        "_airplay._tcp",
        "_raop._tcp",
        "_smb._tcp",
        "_ipp._tcp",
        "_printer._tcp",
        "_googlecast._tcp",
        "_matter._tcp",
        "_ssh._tcp",
        "_companion-link._tcp"
    ]
    
    public init() {}
    
    /// Bắt đầu duyệt Bonjour trong khoảng thời gian nhất định và trả về danh sách dịch vụ
    public func browse(duration: TimeInterval = 3.0) async -> [BonjourDiscoveredService] {
        var discovered: [BonjourDiscoveredService] = []
        isBrowsing = true
        
        let stream = AsyncStream<BonjourDiscoveredService> { continuation in
            let queue = DispatchQueue(label: "com.networkanalyst.bonjour", qos: .utility)
            var activeBrowsers: [NWBrowser] = []
            
            for serviceType in BonjourBrowser.commonServiceTypes {
                let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
                let parameters = NWParameters()
                parameters.includePeerToPeer = true
                let browser = NWBrowser(for: descriptor, using: parameters)
                
                browser.browseResultsChangedHandler = { results, _ in
                    for result in results {
                        switch result.endpoint {
                        case .service(let name, let type, let domain, _):
                            // Thử trích xuất IP từ interfaces của result nếu có
                            var resolvedIP: String? = nil
                            for iface in result.interfaces {
                                if iface.type == .wifi {
                                    // Interface matched
                                }
                            }
                            
                            var txtMap: [String: String] = [:]
                            if case .bonjour(let txt) = result.metadata {
                                for key in txt.dictionary.keys {
                                    txtMap[key] = txt.dictionary[key]
                                }
                            }
                            
                            let item = BonjourDiscoveredService(
                                name: name,
                                serviceType: type,
                                domain: domain,
                                ipAddress: resolvedIP,
                                txtRecord: txtMap
                            )
                            continuation.yield(item)
                        default:
                            break
                        }
                    }
                }
                
                browser.start(queue: queue)
                activeBrowsers.append(browser)
            }
            
            // Dừng sau khi hết duration
            queue.asyncAfter(deadline: .now() + duration) {
                for b in activeBrowsers {
                    b.cancel()
                }
                continuation.finish()
            }
        }
        
        for await service in stream {
            discovered.append(service)
        }
        
        self.isBrowsing = false
        return discovered
    }
}
