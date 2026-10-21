//
//  DeviceDetailSheet.swift
//  NetworkAnalyst
//
//  Created for iOS 16+, Swift 5.9+
//

import SwiftUI

/// Sheet hiển thị chi tiết thiết bị phát hiện được trên mạng LAN
public struct DeviceDetailSheet: View {
    public let device: DiscoveredDevice
    public let onScanPorts: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    public init(device: DiscoveredDevice, onScanPorts: @escaping (String) -> Void) {
        self.device = device
        self.onScanPorts = onScanPorts
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: device.deviceType.iconName)
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                            .frame(width: 50, height: 50)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.displayName)
                                .font(.headline)
                            Text(device.deviceType.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Thông số mạng")) {
                    HStack {
                        Text("Địa chỉ IP")
                        Spacer()
                        Text(device.ipAddress)
                            .font(.system(.body, design: .monospaced).bold())
                    }
                    
                    HStack {
                        Text("Tên máy (Hostname)")
                        Spacer()
                        Text(device.hostname ?? "Không xác định")
                            .foregroundColor(device.hostname != nil ? .primary : .secondary)
                    }
                    
                    HStack {
                        Text("Địa chỉ MAC")
                        Spacer()
                        Text(device.macAddress ?? "iOS Sandbox (Bị ẩn)")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Nhà sản xuất (Vendor)")
                        Spacer()
                        Text(device.vendor ?? "Chưa rõ")
                    }
                    
                    if let rtt = device.rttMs {
                        HStack {
                            Text("Độ trễ phản hồi (RTT)")
                            Spacer()
                            Text(String(format: "%.1f ms", rtt))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text("Phương thức phát hiện")) {
                    ForEach(device.discoveryMethods, id: \.self) { method in
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                            Text(method.rawValue)
                        }
                    }
                }
                
                if !device.bonjourServices.isEmpty {
                    Section(header: Text("Dịch vụ Bonjour phát hiện")) {
                        ForEach(device.bonjourServices, id: \.self) { service in
                            Text(service)
                                .font(.caption)
                        }
                    }
                }
                
                if !device.openPorts.isEmpty {
                    Section(header: Text("Các cổng mở sơ bộ")) {
                        ForEach(device.openPorts, id: \.self) { port in
                            let info = PortDatabase.lookup(port: port)
                            HStack {
                                Text("Cổng \(port)")
                                    .font(.system(.body, design: .monospaced).bold())
                                Spacer()
                                Text(info.name)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        let ip = device.ipAddress
                        dismiss()
                        onScanPorts(ip)
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                            Text("Quét toàn bộ cổng của thiết bị này")
                                .bold()
                            Spacer()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Chi tiết thiết bị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
        }
    }
}
