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
                
                Section(header: Text(LocalizedStringKey("device.details.network_params"))) {
                    HStack {
                        Text(LocalizedStringKey("device.details.ipv4"))
                        Spacer()
                        Text(device.ipAddress)
                            .font(.system(.body, design: .monospaced).bold())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(LocalizedStringKey("device.details.ipv6"))
                            Spacer()
                            if let v6 = device.ipv6Address {
                                Text(v6)
                                    .font(.system(.footnote, design: .monospaced).bold())
                                    .textSelection(.enabled)
                            }
                        }
                        if device.ipv6Address == nil {
                            Text(device.ipv6StatusExplanation ?? String(localized: "lan.no_ipv6_explanation", defaultValue: "Không có địa chỉ IPv6 (Router hoặc thiết bị không kích hoạt IPv6)"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("device.details.hostname"))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(device.hostname ?? String(localized: "common.unknown", defaultValue: "Không xác định"))
                                .foregroundColor(device.hostname != nil ? .primary : .secondary)
                            if let src = device.hostnameSource {
                                let sourceFormat = String(localized: "device.details.source_format", defaultValue: "Nguồn: %@")
                                Text(String(format: sourceFormat, src.displayName))
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("device.details.mac"))
                        Spacer()
                        Text(device.macAddress ?? String(localized: "device.details.mac_hidden", defaultValue: "iOS Sandbox (Bị ẩn)"))
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("device.details.vendor"))
                        Spacer()
                        Text(device.vendor ?? String(localized: "common.unknown", defaultValue: "Chưa rõ"))
                    }
                    
                    if let rtt = device.rttMs {
                        HStack {
                            Text(LocalizedStringKey("device.details.rtt"))
                            Spacer()
                            Text(String(format: "%.1f ms", rtt))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text(LocalizedStringKey("device.details.discovery_methods"))) {
                    ForEach(device.discoveryMethods, id: \.self) { method in
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                            Text(method.displayName)
                        }
                    }
                }
                
                if !device.bonjourServices.isEmpty {
                    Section(header: Text(LocalizedStringKey("device.details.bonjour_services"))) {
                        ForEach(device.bonjourServices, id: \.self) { service in
                            Text(service)
                                .font(.caption)
                        }
                    }
                }
                
                if !device.openPorts.isEmpty {
                    Section(header: Text(LocalizedStringKey("device.details.open_ports"))) {
                        ForEach(device.openPorts, id: \.self) { port in
                            let info = PortDatabase.lookup(port: port)
                            HStack {
                                let portFormat = String(localized: "port.number_format", defaultValue: "Cổng %d")
                                Text(String(format: portFormat, port))
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
                            Text(LocalizedStringKey("device.details.scan_ports_btn"))
                                .bold()
                            Spacer()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("device.details.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
