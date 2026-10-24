//
//  RDAPBootstrapManager.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import NetworkCore

/// Quản lý việc tải động các tệp Bootstrap Registry từ data.iana.org/rdap và lưu bộ đệm đĩa 24 giờ
public actor RDAPBootstrapManager {
    public static let shared = RDAPBootstrapManager()
    
    private let urlSession: URLSession
    private let fileManager = FileManager.default
    private let cacheTTL: TimeInterval = 86400 // 24 giờ
    
    private var cacheDirectory: URL {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("RDAPBootstrap", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Đảm bảo nạp dữ liệu Bootstrap từ đĩa (nếu còn hạn 24h) hoặc tải mới từ IANA
    public func ensureBootstrapLoaded() async {
        let cacheFile = cacheDirectory.appendingPathComponent("dns_bootstrap.json")
        
        // 1. Kiểm tra cache trên đĩa xem có tồn tại và dưới 24h không
        if let attrs = try? fileManager.attributesOfItem(atPath: cacheFile.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) < cacheTTL,
           let cachedData = try? Data(contentsOf: cacheFile),
           let mapping = try? RDAPBootstrapParser.parse(data: cachedData) {
            RDAPBootstrap.updateDNSCache(with: mapping)
            return
        }
        
        // 2. Tải mới từ data.iana.org/rdap/dns.json
        do {
            var req = URLRequest(url: RDAPBootstrap.ianaDNSBootstrapURL)
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, resp) = try await urlSession.data(for: req)
            
            guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return
            }
            
            let mapping = try RDAPBootstrapParser.parse(data: data)
            RDAPBootstrap.updateDNSCache(with: mapping)
            
            // Lưu cache xuống đĩa
            try? data.write(to: cacheFile, options: .atomic)
        } catch {
            // Nếu lỗi mạng, ứng dụng tiếp tục sử dụng bảng gõ tay dự phòng offline trong RDAPBootstrap
        }
    }
}
