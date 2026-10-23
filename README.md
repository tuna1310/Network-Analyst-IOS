# Network Analyst for iOS

Ứng dụng phân tích và chẩn đoán mạng chuyên nghiệp xây dựng trên **iOS 16+**, **Swift 5.9+**, **SwiftUI**, **Swift Concurrency** (`async/await`, `actor`, `TaskGroup`), và **Network.framework**.

---

## 📑 Mục Lục
1. [Tính Năng Chính](#tính-năng-chính)
2. [Xử Lý Các Ràng Buộc Riêng Của iOS Sandbox](#xử-lý-các-ràng-buộc-riêng-của-ios-sandbox)
3. [Danh Sách Entitlement & Cấu Hình Apple Developer Portal](#danh-sách-entitlement--cấu-hình-apple-developer-portal)
4. [Cấu Hình Quyền Riêng Tư (Info.plist)](#cấu-hình-quyền-riêng-tư-infoplist)
5. [Hướng Dẫn Tích Hợp Google Mobile Ads SDK (AdMob)](#hướng-dẫn-tích-hợp-google-mobile-ads-sdk-admob)
6. [Cấu Trúc Thư Mục Dự Án](#cấu-trúc-thư-mục-dự-án)
7. [Hướng Dẫn Biên Dịch & Chạy Dự Án](#hướng-dẫn-biên-dịch--chạy-dự-án)

---

## 🚀 Tính Năng Chính

- **Bảng tin tổng quan (Dashboard)**:
  - Tên Wi-Fi (SSID), địa chỉ MAC Router (BSSID), cường độ tín hiệu.
  - Thông số mạng cục bộ POSIX: IP thiết bị (`IPv4`/`IPv6`), Subnet Mask, Gateway IP, Broadcast IP, Interface (`en0`, `pdp_ip0`).
  - IP công khai (Public IP), Nhà mạng (ISP / ASN), Thành phố, Tọa độ địa lý.
  - Đo độ trễ tức thời tới Gateway và máy chủ DNS Cloudflare (`1.1.1.1`).
- **Quét thiết bị mạng nội bộ (LAN Device Scanner)**:
  - Khám phá thiết bị đa luồng trong dải Subnet mà không phụ thuộc vào ARP thô của kernel.
  - Kết hợp đồng thời Bonjour (`NWBrowser`), ICMP Ping datagram, TCP Port Probing, và truy vấn Unicast (NetBIOS UDP 137, mDNS UDP 5353, LLMNR UDP 5355, SNMP UDP 161).
  - Phân loại thiết bị tự động: Router/Gateway, Apple Device, Windows PC, Linux/NAS Server, Máy in, Smart TV, Thiết bị IoT.
  - Phân giải tên máy (Hostname) và Vendor nhà sản xuất.
- **Quét cổng TCP (Port Scanner)**:
  - Quét bằng `NWConnection` tối ưu hóa tài nguyên mạng.
  - Điều phối đồng thời qua `TaskGroup` có giới hạn (mặc định 180-200 tasks song song), mỗi cổng có timeout riêng biệt (1.2s).
  - Các chế độ: Top 20 cổng phổ biến, Top 100 dịch vụ mạng, và Tùy chỉnh dải cổng (1-65535).
  - Cơ sở dữ liệu nhận dạng dịch vụ IANA (HTTP, HTTPS, SSH, FTP, SMB, MySQL, Redis, RDP, MSSQL,...).
  - Xuất báo cáo kết quả quét dạng văn bản.
- **Kiểm tra độ trễ ICMP (Ping & Hop Analyzer)**:
  - Sử dụng Socket ICMP Datagram không cần đặc quyền (`SOCK_DGRAM`, `IPPROTO_ICMP`), tuân thủ sandbox iOS.
  - Thống kê chi tiết: Số gói gửi/nhận, tỉ lệ mất gói (Packet Loss %), Min / Avg / Max / StdDev RTT.
  - Biểu đồ biến thiên độ trễ theo thời gian thực (SwiftUI Canvas).
- **Tra cứu DNS đa bản ghi & WHOIS / RDAP**:
  - Tự xây dựng DNS Client hỗ trợ DNS-over-HTTPS (DoH RFC 8484 & RFC 8427) và Raw UDP DNS qua `NWConnection`.
  - Hỗ trợ đầy đủ các loại bản ghi ngoài A/AAAA: `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SOA`, `SRV`, `PTR`, `CAA`.
  - Tra cứu thông tin sở hữu tên miền / dải IP qua giao thức chuẩn **RDAP (RFC 7480-7484)** thay thế WHOIS cũ bằng `URLSession`.
- **Hệ thống Quảng cáo (Ad Service)**:
  - Cung cấp kiến trúc `AdServiceProtocol` kèm triển khai giả lập `MockAdService` (Banner, Interstitial đếm ngược, Rewarded ad).
  - Sẵn sàng chuyển đổi sang Google Mobile Ads SDK thật với chỉ 1 bước.

---

## 🛡️ Xử Lý Các Ràng Buộc Riêng Của iOS Sandbox

### 1. iOS chặn truy cập bảng ARP thô (`/proc/net/arp` / `SIOCGARP`)
- **Vấn đề**: Từ iOS 10 trở đi, Apple giới hạn sandbox không cho phép đọc bảng ARP của kernel nhằm bảo vệ quyền riêng tư người dùng.
- **Giải pháp trong dự án**:
  - Tính toán dải IP subnet từ IP thiết bị và Netmask (ví dụ: `192.168.1.1` ... `192.168.1.254`).
  - Thăm dò song song bằng **UnicastProber**:
    1. **NetBIOS Name Service (UDP 137)**: Gửi gói tin *Node Status Query* theo RFC 1002. Máy tính Windows, Samba Linux, hoặc NAS (Synology, QNAP) phản hồi tên máy tính, nhóm làm việc (Workgroup), và cả **địa chỉ MAC card mạng thật**.
    2. **mDNS Unicast (UDP 5353)**: Truy vấn bản ghi PTR đảo ngược hoặc `.local` để lấy tên thiết bị Apple / IoT.
    3. **LLMNR (UDP 5355)**: Truy vấn Link-Local Multicast Name Resolution cho máy trạm Windows.
    4. **SNMP v1/v2c (UDP 161)**: Gửi GetRequest cho OID `sysDescr.0` và `sysName.0` tới community `public`. Router (Cisco, TP-Link, Asus, MikroTik) và máy in mạng sẽ phản hồi chuỗi mô tả model/firmware.
    5. **Bonjour (`NWBrowser`)**: Quét song song các service type phổ biến (`_http._tcp`, `_airplay._tcp`, `_smb._tcp`, `_ipp._tcp`, `_printer._tcp`, `_googlecast._tcp`, `_matter._tcp`).
    6. **TCP Connect Probe**: Kiểm tra kết nối TCP chuẩn (full 3-way handshake) qua `NWConnection` trên các cổng dịch vụ nhận diện nhanh (80, 443, 22, 445, 8080, 5000, 62078).

### 2. Socket ICMP không cần đặc quyền root & Ràng buộc Traceroute
- **Vấn đề Ping**: iOS cấm `SOCK_RAW` trong sandbox ứng dụng của bên thứ ba. Hệ thống sử dụng Datagram ICMP Socket chuẩn POSIX Darwin: `socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)` (tương tự cơ chế của `SimplePing`). Gói tin Echo Request (Type 8, Code 0) được đóng gói cùng RFC 1071 Internet Checksum.
- **Ràng buộc với Traceroute**:
  - Khi tăng dần TTL bằng `setsockopt(sock, IPPROTO_IP, IP_TTL, &ttl, ...)`, các router trung gian sẽ phản hồi gói tin ICMP Type 11 (Time Exceeded).
  - *Lưu ý quan trọng*: Trên nhân Darwin/iOS, socket ICMP không đặc quyền (`SOCK_DGRAM`) có thể bị kernel lọc không chuyển tiếp gói tin ICMP Type 11 về tầng ứng dụng (chỉ đảm bảo nhận Type 0 Echo Reply).
  - *Giải pháp*: Ứng dụng triển khai qua `TracerouteEngineProtocol`, hỗ trợ cơ chế thăm dò ICMP chính thức kèm phương án dự phòng gửi probe UDP với `IP_TTL` tới cổng cao (33434+) và bắt phản hồi. **Điểm này bắt buộc phải kiểm chứng hành vi thực tế trên thiết bị iPhone thật**.
- **Tra cứu Quốc gia từng Hop (GeoIP)**:
  - Tách thành protocol `GeoIPProvider`. Mặc định sử dụng dịch vụ HTTPS không cần API Key `ipwho.is` (đồng nhất với bản Android, miễn phí ~10,000 lượt/tháng, tuân thủ ATS).
  - Để bảo vệ quyền riêng tư, tính năng này **mặc định TẮT**, có giải thích rõ ràng người dùng cần chủ động bật, có cache trong bộ nhớ kèm rate limiter.
  - Không nhúng bất kỳ token hoặc API Key bí mật nào trong mã nguồn ứng dụng.

### 3. Tra cứu OUI & Phát hiện MAC Ngẫu Nhiên
> [!WARNING]
> **Cơ sở dữ liệu OUI hiện tại là DỮ LIỆU MẪU (23 vendor)** để phục vụ kiểm thử và chạy script trên môi trường phát triển ban đầu. Khi triển khai chính thức, hãy đặt file `oui.csv` chính thức của IEEE (hàng chục nghìn dòng) vào `Scripts/data/oui.csv` và chạy `python3 Scripts/build_oui.py` để sinh file `oui.json` đầy đủ (hỗ trợ MA-L, MA-M, MA-S).
- **Phát hiện MAC Ngẫu nhiên (Private / Randomized MAC)**:
  - Theo chuẩn IEEE 802, bit 1 của byte đầu tiên là bit U/L (Universal/Local).
  - Nếu `(byte0 & 0x02) != 0` (ví dụ `x2`, `x6`, `xA`, `xE` như `DA:A1:19...`), địa chỉ MAC là do hệ điều hành sinh ngẫu nhiên để bảo mật Wi-Fi. Ứng dụng lập tức gắn nhãn `"Private/Random MAC"` thay vì đoán sai hãng sản xuất.

### 3. Đọc SSID và BSSID trên iOS 14+
- **Vấn đề**: Apple giấu SSID/BSSID nếu thiếu quyền vị trí hoặc thiếu entitlement.
- **Giải pháp trong dự án**:
  - Khai báo entitlement `com.apple.developer.networking.wifi-info`.
  - Khai báo `NSLocationWhenInUseUsageDescription` trong `Info.plist`.
  - Gọi `NEHotspotNetwork.fetchCurrent` bất đồng bộ.
  - Phân loại rõ lỗi và hiển thị giao diện hướng dẫn người dùng:
    - Nếu chưa cấp quyền vị trí: Hiện nút "Cấp quyền Vị trí".
    - Nếu thiếu Entitlement trong Provisioning Profile: Giải thích rõ ràng nguyên nhân.
    - Nếu không kết nối Wi-Fi: Thông báo đang sử dụng mạng di động.

### 4. Quét cổng giới hạn đồng thời bằng Concurrency
- Sử dụng `TaskGroup` với cửa sổ trượt (Sliding Window Concurrency) duy trì tối đa ~180-200 tasks kết nối `NWConnection` cùng lúc.
- Mỗi cổng được gắn một `DispatchSourceTimer` độc lập để ngắt kết nối sau 1.2s, tránh cạn kiệt File Descriptor (FD) hoặc rò rỉ bộ nhớ.

### 5. Bản ghi DNS ngoài A/AAAA
- System resolver (`getaddrinfo`) của iOS chỉ hỗ trợ A (IPv4) và AAAA (IPv6).
- Dự án tự hiện thực **DNSClient** tích hợp:
  - DoH (DNS-over-HTTPS) theo RFC 8484 và RFC 8427 JSON qua `URLSession` (truy vấn tới Cloudflare `1.1.1.1`, Google `8.8.8.8`, Quad9 `9.9.9.9`).
  - Raw UDP DNS Client qua `NWConnection` tới cổng 53.
  - Tự giải mã gói tin nhị phân RFC 1035 với giải thuật giải nén con trỏ (Pointers `0xC0`).

---

## 🔑 Danh Sách Entitlement & Cấu Hình Apple Developer Portal

Để tính năng đọc tên Wi-Fi (SSID) và địa chỉ MAC Router (BSSID) hoạt động được trên thiết bị thật, bạn cần bật capability trong tài khoản Apple Developer:

### 1. Bật Capability trên Apple Developer Portal
1. Truy cập [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list).
2. Chọn App ID của dự án (ví dụ: `com.developer.NetworkAnalyst`).
3. Trong tab **Capabilities**, tìm và tích chọn:
   - ✅ **Access Wi-Fi Information**
4. Nhấn **Save**.
5. Vào mục **Profiles**, tạo lại hoặc tải về Provisioning Profile mới chứa capability này.

### 2. Tệp Entitlements trong dự án
Dự án đã có sẵn tệp `NetworkAnalyst/Resources/NetworkAnalyst.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.networking.wifi-info</key>
	<true/>
</dict>
</plist>
```

> [!NOTE]
> Trên iOS Simulator, phần cứng Wi-Fi không hỗ trợ `NEHotspotNetwork.fetchCurrent`. Hãy thử nghiệm trên iPhone/iPad thật với Provisioning Profile đã kích hoạt entitlement trên để thấy tên Wi-Fi thực tế.

---

## 📜 Cấu Hình Quyền Riêng Tư (Info.plist)

Dự án đã cấu hình đầy đủ các chuỗi mô tả bắt buộc của iOS:

| Khóa Info.plist | Giá trị mô tả | Mục đích |
|---|---|---|
| `NSLocalNetworkUsageDescription` | "Network Analyst cần quyền truy cập Mạng cục bộ để quét tìm các thiết bị trong Wi-Fi, kiểm tra cổng mở và phân tích cấu hình mạng LAN." | Bắt buộc trên iOS 14+ khi mở kết nối tới các IP nội bộ (`192.168.x.x`, `10.x.x.x`) hoặc chạy Bonjour. |
| `NSLocationWhenInUseUsageDescription` | "Network Analyst cần quyền Vị trí khi dùng để đọc tên mạng Wi-Fi (SSID) và địa chỉ BSSID theo yêu cầu bảo mật của Apple." | Bắt buộc để `NEHotspotNetwork.fetchCurrent` trả về SSID thay vì `nil`. |
| `NSBonjourServices` | Mảng danh sách các dịch vụ Bonjour (`_http._tcp`, `_smb._tcp`, `_airplay._tcp`, `_ipp._tcp`, `_printer._tcp`, `_googlecast._tcp`, `_matter._tcp`, `_ssh._tcp`, v.v.) | Cho phép `NWBrowser` tìm kiếm các thiết bị phát sóng dịch vụ này trên LAN. |

---

## 📢 Hướng Dẫn Tích Hợp Google Mobile Ads SDK (AdMob)

Dự án hiện đang sử dụng `MockAdService` (triển khai đầy đủ giao diện `AdServiceProtocol`, hỗ trợ Banner ở chân trang và Interstitial đếm ngược).

Để gắn Google Mobile Ads SDK thật, hãy thực hiện 3 bước sau:

### Bước 1: Thêm Google Mobile Ads qua Swift Package Manager (SPM)
1. Trong Xcode, vào menu: **File** > **Add Package Dependencies...**
2. Dán đường dẫn repository:
   ```
   https://github.com/googleads/swift-package-manager-google-mobile-ads.git
   ```
3. Chọn version mới nhất (ví dụ `11.x` hoặc `10.x`), chọn target **NetworkAnalyst** và bấm **Add Package**.

### Bước 2: Cập nhật `Info.plist`
Mở `NetworkAnalyst/Resources/Info.plist` và thêm App ID AdMob (mã dưới đây là App ID thử nghiệm của Google):
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
</array>
```

### Bước 3: Tạo lớp `AdMobService.swift` và thay thế Mock
Tạo tệp mới `NetworkAnalyst/Services/Ads/AdMobService.swift`:
```swift
import Foundation
import UIKit
import GoogleMobileAds
import Combine

@MainActor
public final class AdMobService: NSObject, ObservableObject, AdServiceProtocol {
    public static let shared = AdMobService()
    
    @Published public var isBannerReady: Bool = false
    @Published public var isInterstitialReady: Bool = false
    @Published public var isRewardedReady: Bool = false
    @Published public var showInterstitialModal: Bool = false
    @Published public var showRewardedModal: Bool = false
    
    private var interstitial: GADInterstitialAd?
    
    public override init() {
        super.init()
    }
    
    public func initialize() {
        GADMobileAds.sharedInstance().start { status in
            print("Google Mobile Ads initialized: \(status)")
            Task { @MainActor in
                self.loadInterstitial()
            }
        }
    }
    
    public func loadBanner() {
        self.isBannerReady = true
    }
    
    public func loadInterstitial() {
        let request = GADRequest()
        // ID thử nghiệm Interstitial của Google: ca-app-pub-3940256099942544/4411468910
        GADInterstitialAd.load(withAdUnitID: "ca-app-pub-3940256099942544/4411468910", request: request) { [weak self] ad, error in
            guard let self = self else { return }
            if let error = error {
                print("Failed to load interstitial: \(error.localizedDescription)")
                self.isInterstitialReady = false
                return
            }
            self.interstitial = ad
            self.isInterstitialReady = true
        }
    }
    
    public func showInterstitial(completion: (() -> Void)?) {
        guard let interstitial = interstitial,
              let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
            completion?()
            return
        }
        
        interstitial.present(fromRootViewController: rootVC)
        self.loadInterstitial() // Tải lại cho lần tiếp theo
        completion?()
    }
    
    public func showRewarded(rewardGranted: @escaping (Int) -> Void) {
        // Tương tự cho GADRewardedAd
    }
}
```

Tại `NetworkAnalystApp.swift`, thay:
```swift
@StateObject private var adService = MockAdService.shared
```
Thành:
```swift
@StateObject private var adService = AdMobService.shared
```

---

## 📂 Cấu Trúc Thư Mục Dự Án

```
NetworkAnalystIOS/
├── NetworkAnalyst.xcodeproj/
│   └── project.pbxproj               # File cấu hình dự án Xcode chuẩn
├── NetworkAnalyst/
│   ├── App/
│   │   ├── NetworkAnalystApp.swift   # Điểm khởi chạy ứng dụng SwiftUI
│   │   └── MainTabView.swift         # 5 Tab chính + Khung quảng cáo chân trang
│   ├── Core/
│   │   ├── NetworkInterfaceInfo.swift# POSIX getifaddrs, Subnet CIDR, Gateway routing table
│   │   ├── NetworkMonitor.swift      # NWPathMonitor quan sát Wi-Fi, Cellular, trạng thái mạng
│   │   ├── LocationAndWiFiManager.swift # NEHotspotNetwork đọc SSID/BSSID & CoreLocation
│   │   └── LocalNetworkPermissionManager.swift # Xử lý và hướng dẫn quyền Mạng cục bộ iOS
│   ├── Services/
│   │   ├── DeviceScanner/
│   │   │   ├── DiscoveredDevice.swift# Model thiết bị, icon, phân loại loại thiết bị
│   │   │   ├── BonjourBrowser.swift  # NWBrowser duyệt tìm mDNS services
│   │   │   ├── UnicastProber.swift   # NetBIOS UDP 137, mDNS 5353, LLMNR 5355, SNMP 161, TCP probe
│   │   │   └── LanScannerEngine.swift# TaskGroup quét đa luồng kết hợp dải Subnet
│   │   ├── PortScanner/
│   │   │   ├── PortScannerModels.swift # Cổng mở/đóng/lọc & Database tên dịch vụ IANA
│   │   │   └── PortScannerEngine.swift # Quét cổng bằng NWConnection & TaskGroup giới hạn 200 tasks
│   │   ├── Ping/
│   │   │   ├── PingModels.swift      # Kết quả gói tin & Thống kê RTT min/avg/max/stddev
│   │   │   ├── ICMPEngine.swift      # Socket ICMP Datagram (SOCK_DGRAM, IPPROTO_ICMP) không cần root
│   │   │   └── PingService.swift     # Quản lý chuỗi gói tin ping liên tục
│   │   ├── DNS/
│   │   │   ├── PublicIPService.swift # URLSession lấy Public IP, ISP, Geo location
│   │   │   ├── RDAPClient.swift      # Tra cứu WHOIS / RDAP (RFC 7480-7484)
│   │   │   ├── DNSRecordTypes.swift  # Model bản ghi DNS (A, AAAA, MX, TXT, NS, SOA, SRV, PTR, CAA)
│   │   │   └── DNSClient.swift       # DoH JSON/RFC 8484 Wire và UDP DNS Client
│   │   └── Ads/
│   │       ├── AdServiceProtocol.swift # Interface chuẩn cho dịch vụ quảng cáo
│   │       └── AdViews.swift         # Banner view chân trang & Interstitial modal giả lập
│   ├── ViewModels/
│   │   ├── DashboardViewModel.swift
│   │   ├── LanScannerViewModel.swift
│   │   ├── PortScannerViewModel.swift
│   │   ├── PingViewModel.swift
│   │   └── DNSLookupViewModel.swift
│   ├── Views/
│   │   ├── Components/
│   │   │   └── UIComponents.swift    # PermissionAlertBanner, MetricItemCard, LatencyMiniChart
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift
│   │   ├── LanScanner/
│   │   │   ├── LanScannerView.swift
│   │   │   └── DeviceDetailSheet.swift
│   │   ├── PortScanner/
│   │   │   └── PortScannerView.swift
│   │   ├── Ping/
│   │   │   └── PingTracerouteView.swift
│   │   └── DNS/
│   │       └── DNSLookupView.swift
│   └── Resources/
│       ├── Assets.xcassets           # AppIcon, AccentColor
│       ├── Info.plist                # Quyền Local Network, Location, Bonjour services
│       └── NetworkAnalyst.entitlements # com.apple.developer.networking.wifi-info
└── README.md
```

---

## 🛠️ Hướng Dẫn Biên Dịch & Chạy Dự Án

### Yêu Cầu Môi Trường
- **macOS** 13.0 (Ventura) trở lên.
- **Xcode** 15.0 trở lên (hỗ trợ Swift 5.9+, iOS 16.0+ SDK).
- Thiết bị thật iPhone/iPad chạy iOS 16.0+ (khuyến khích để kiểm tra đầy đủ tính năng Wi-Fi SSID và quét mạng LAN).

### Các Bước Thực Hiện Với XcodeGen (Khuyên Dùng)
Dự án được định nghĩa chính thức qua file `project.yml` để tránh xung đột `project.pbxproj`:
1. Trên máy Mac, cài đặt XcodeGen (nếu chưa có):
   ```bash
   brew install xcodegen
   ```
2. Sinh file dự án Xcode từ thư mục gốc:
   ```bash
   xcodegen generate
   ```
3. Mở `NetworkAnalyst.xcodeproj` vừa được sinh.
4. Chọn scheme **NetworkAnalyst** và bấm **Cmd + R** để chạy, hoặc chọn **NetworkAnalystTests** bấm **Cmd + U** để chạy toàn bộ Unit Tests.

### Tạo File OUI Từ Bản Ghi Chính Thức Của IEEE
1. Tải file `oui.csv` chính thức từ IEEE:
   ```bash
   curl -o Scripts/data/oui.csv https://standards-oui.ieee.org/oui/oui.csv
   ```
2. Chạy script để sinh file tài nguyên `oui.json`:
   ```bash
   python3 Scripts/build_oui.py
   ```
*(Nếu chưa có `oui.csv`, script sẽ dùng file `sample_oui.csv` mẫu cho mục đích chạy test).*

---

## 🔍 Bảng Trạng Thái Kiểm Chứng (Verification Matrix)

| Đã kiểm chứng thực tế (chạy thật trên Windows) | Rà soát bằng mắt, chưa biên dịch (cần Mac) | Bắt buộc kiểm chứng trên thiết bị thật (iPhone) |
|---|---|---|
| - Script Python `build_oui.py` đọc CSV và xuất JSON hợp lệ. | - Mã nguồn Swift 5.9, `actor`, `@MainActor`, `Sendable`, protocol. | - Socket ICMP unprivileged nhận ICMP Type 11 (Time Exceeded) từ router mạng viễn thông. |
| - Tính hợp lệ của cấu trúc `oui.json` và `Localizable.xcstrings`. | - Lệnh `xcodegen generate` sinh project Xcode từ `project.yml`. | - Quyền Wi-Fi SSID / BSSID (`NEHotspotNetwork.fetchCurrent`) trên router thật. |
| - Cấu trúc cú pháp `project.yml` và `Package.swift`. | - Chạy `xcodebuild test` cho target `NetworkAnalystTests` và `NetworkCoreTests`. | - Nhận diện VPN qua `utun*` active + có IP gán thực tế. |
| | - Biên dịch và link các resource bundle (`Localizable.xcstrings`, `oui.json`). | - Phản hồi TCP Port 43 từ WHOIS server của các registrar khác nhau. |
