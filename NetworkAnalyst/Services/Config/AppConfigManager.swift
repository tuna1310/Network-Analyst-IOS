//
//  AppConfigManager.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import Foundation
import Combine

/// Cấu hình người dùng và trạng thái cam kết pháp lý được lưu trữ bằng tệp JSON
/// trong thư mục Application Support (Không dùng UserDefaults, loại trừ khỏi iCloud backup).
public struct AppConfig: Codable, Sendable {
    public var hasAcceptedScanDisclaimer: Bool
    public var disclaimerAcceptedDate: Date?
    
    public init(
        hasAcceptedScanDisclaimer: Bool = false,
        disclaimerAcceptedDate: Date? = nil
    ) {
        self.hasAcceptedScanDisclaimer = hasAcceptedScanDisclaimer
        self.disclaimerAcceptedDate = disclaimerAcceptedDate
    }
}

@MainActor
public final class AppConfigManager: ObservableObject {
    public static let shared = AppConfigManager()
    
    @Published public private(set) var config: AppConfig
    
    private let fileQueue = DispatchQueue(label: "com.networkanalyst.config.fileio", qos: .background)
    
    private static var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var dir = appSupport.appendingPathComponent("Config", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        // Đặt thuộc tính không sao lưu lên iCloud cho thư mục config
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }
    
    private static var configFileURL: URL {
        var fileURL = storageDirectory.appendingPathComponent("config.json")
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? fileURL.setResourceValues(values)
        return fileURL
    }
    
    public init() {
        self.config = Self.loadFromDiskSync()
    }
    
    /// Người dùng xác nhận đồng ý với tuyên bố chỉ quét mạng được ủy quyền
    public func acceptScanDisclaimer() {
        config.hasAcceptedScanDisclaimer = true
        config.disclaimerAcceptedDate = Date()
        saveToDisk()
    }
    
    /// Đặt lại cam kết (cho mục đích kiểm thử hoặc thiết lập lại cài đặt)
    public func resetScanDisclaimer() {
        config.hasAcceptedScanDisclaimer = false
        config.disclaimerAcceptedDate = nil
        saveToDisk()
    }
    
    // MARK: - File I/O
    private static func loadFromDiskSync() -> AppConfig {
        let fileURL = configFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return AppConfig()
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("Lỗi nạp cấu hình từ đĩa: \(error.localizedDescription)")
            return AppConfig()
        }
    }
    
    private func saveToDisk() {
        let snapshot = self.config
        let fileURL = Self.configFileURL
        
        fileQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(snapshot)
                try data.write(to: fileURL, options: .atomic)
                
                // Đảm bảo cờ loại trừ backup được gán sau khi ghi đĩa
                var mutableURL = fileURL
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? mutableURL.setResourceValues(values)
            } catch {
                print("Lỗi ghi cấu hình xuống đĩa: \(error.localizedDescription)")
            }
        }
    }
}
