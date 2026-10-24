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
> **Cơ sở dữ liệu OUI hiện tại là DỮ LIỆU MẪU (24 vendor)** để phục vụ kiểm thử và chạy script trên môi trường phát triển ban đầu. Khi triển khai chính thức, hãy đặt file `oui.csv` chính thức của IEEE (hàng chục nghìn dòng) vào `Scripts/data/oui.csv` và chạy `python3 Scripts/build_oui.py` để sinh file `oui.json` đầy đủ (hỗ trợ MA-L, MA-M, MA-S).
- **Phát hiện MAC Ngẫu nhiên (Private / Randomized MAC)**:
  - Theo chuẩn IEEE 802, bit 1 của byte đầu tiên là bit U/L (Universal/Local).
  - Nếu `(byte0 & 0x02) != 0` (ví dụ `x2`, `x6`, `xA`, `xE` như `DA:A1:19...`), địa chỉ MAC là do hệ điều hành sinh ngẫu nhiên để bảo mật Wi-Fi. Ứng dụng lập tức gắn nhãn `"Private/Random MAC"` thay vì đoán sai hãng sản xuất.

### 4. Đọc SSID và BSSID trên iOS 14+
- **Vấn đề**: Apple giấu SSID/BSSID nếu thiếu quyền vị trí hoặc thiếu entitlement.
- **Giải pháp trong dự án**:
  - Khai báo entitlement `com.apple.developer.networking.wifi-info`.
  - Khai báo `NSLocationWhenInUseUsageDescription` trong `Info.plist`.
  - Gọi `NEHotspotNetwork.fetchCurrent` bất đồng bộ.
  - Phân loại rõ lỗi và hiển thị giao diện hướng dẫn người dùng:
    - Nếu chưa cấp quyền vị trí: Hiện nút "Cấp quyền Vị trí".
    - Nếu thiếu Entitlement trong Provisioning Profile: Giải thích rõ ràng nguyên nhân.
    - Nếu không kết nối Wi-Fi: Thông báo đang sử dụng mạng di động.

### 5. Quét cổng TCP với 3 Chế Độ & Phân Loại 4 Trạng Thái
- **3 Chế độ quét**:
  1. **Phổ biến**: Top 20 cổng thường dùng hoặc Top 100 dịch vụ mạng.
  2. **Tùy chọn**: Cú pháp linh hoạt `80, 443, 8000-8100` phân tích qua `PortRangeParser` (tự động loại trùng, kiểm tra biên `1-65535`).
  3. **Toàn dải (1 - 65535)**: Tính toán thời gian ước tính và hiển thị hộp thoại cảnh báo người dùng xác nhận trước khi bắt đầu.
- **Phân loại 4 trạng thái**:
  - `Open`: Bắt tay TCP 3-bước hoàn tất thành công.
  - `Closed`: Nhận cờ RST từ host (`ECONNREFUSED` = 61).
  - `Filtered`: Hết thời gian chờ phản hồi (Timeout).
  - `Error`: Các lỗi kết nối hệ thống khác (`ENETUNREACH`, `EHOSTUNREACH`). **Đặc biệt: nếu gặp lỗi quyền Mạng cục bộ (`kDNSServiceErr_PolicyDenied` / `EPERM`), hệ thống đánh dấu trạng thái Lỗi Quyền Riêng Tư và hiển thị thông báo, tuyệt đối không gộp nhầm thành Closed**.
- **Điều phối tài nguyên & Quản lý tác vụ**:
  - `TaskGroup` có giới hạn trần cứng (mặc định 200 tasks đồng thời, tối đa 250).
  - Timeout thích ứng: 0.8s cho mạng LAN nội bộ, 1.8s cho mạng Internet công cộng.
  - Hỗ trợ nút **Tạm dừng**, **Tiếp tục**, và **Hủy**: Hủy sạch các đối tượng `NWConnection` đang chờ để tránh rò rỉ File Descriptor (FD).
  - Thăm dò Banner dịch vụ (Banner Grabbing): Mặc định tắt, khi bật sẽ gửi probe ngắn và đọc tối đa 512 bytes trong 1.0s.

### 6. Bản ghi DNS Mở Rộng (HTTPS / SVCB), EDNS0 & Chống Lặp Con Trỏ Nén
- **Bản ghi hiện đại (RFC 9460)**: Tự giải mã cấu trúc phức tạp của `HTTPS` (type 65) và `SVCB` (type 64) bao gồm `SvcPriority`, `TargetName`, và các tham số `SvcParams` (`alpn`, `port`, `ipv4hint`, `ipv6hint`, `ech`, `no-default-alpn`).
- **Hỗ trợ EDNS0 (RFC 6891)**: Gói tin truy vấn được gắn thêm `OPT RR` với kích thước bộ đệm UDP 4096 bytes để tiếp nhận các phản hồi DNS lớn có chữ ký số DNSSEC hoặc danh sách IP dài.
- **Tự động thử lại qua TCP (RFC 7766)**: Khi nhận phản hồi UDP có cờ Truncated (`TC = 1`), hệ thống tự động khởi tạo kết nối TCP tới cổng 53, gắn tiền tố 2-byte độ dài và giải mã lại dữ liệu hoàn chỉnh.
- **Giải mã con trỏ nén an toàn (Safe Pointer Decompression)**:
  - Kiểm tra biên gói tin (chống đọc tràn bộ nhớ).
  - Kiểm tra độ sâu nhảy tối đa (ngăn đệ quy sâu).
  - Thuật toán phát hiện chu trình (Cycle Detection / Visited Offsets) ngăn chặn hoàn toàn nguy cơ treo máy hoặc tràn stack khi gặp gói tin cố tình tạo vòng lặp lồng nhau `0xC0`.

---

## 🗺️ Kế Hoạch Các Mốc Tiếp Theo (Roadmap)

### Mốc 4: Mở Rộng Quét LAN, IPv6 & Lưu Trữ Lịch Sử
- **Quét LAN nâng cao**: Thăm dò danh sách thiết bị IPv6 trong mạng cục bộ và truy vấn DNS ngược (`PTR`) làm nguồn hostname chính xác.
- **Ping / Traceroute IPv6**: Mở rộng socket datagram hỗ trợ `AF_INET6` và `IPPROTO_ICMPV6`.
- **Lưu trữ lịch sử quét**:
  - Sử dụng định dạng file JSON thuần (Codable) lưu trong thư mục `Application Support` (tương thích iOS 16+, không dùng UserDefaults hoặc SwiftData iOS 17).
  - Giới hạn tối đa 100 bản ghi mỗi phân hệ, thực hiện tác vụ đọc/ghi bất đồng bộ tại background thread.
  - Cung cấp nút xóa toàn bộ lịch sử trong giao diện.
- **Cảnh báo bảo mật**: Hộp thoại cảnh báo pháp lý "Chỉ quét mạng mà bạn được ủy quyền sở hữu hoặc quản trị", hiển thị một lần duy nhất và bắt buộc người dùng đồng ý trước khi thực hiện lượt quét đầu tiên.

### Mốc 5: Hoàn Thiện Bản Phát Hành & Rà Soát Bảo Mật
- **Rà soát Localization**: Quét toàn bộ project đảm bảo 100% chuỗi UI nằm trong `Localizable.xcstrings`, không sót chuỗi hardcode.
- **Báo cáo Quyền riêng tư (Privacy Audit)**: Liệt kê chi tiết mọi domain/endpoint kết nối bên ngoài (`api.ipify.org`, `v6.ident.me`, `ipwho.is`, `data.iana.org`, `rdap.org`, các DNS resolver Cloudflare/Google/Quad9).
- **Entitlements & Capabilities**: Hoàn thiện danh sách cấu hình trên Apple Developer Portal và Provisioning Profiles.
- **Bảng kiểm thử trên iPhone thật**: Danh mục chi tiết các chức năng bắt buộc phải chạy trên thiết bị thật trước khi xuất bản App Store.
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
│   │   │   ├── DiscoveredDevice.swift# Model thiết bị, icon, IPv6, Hostname source
│   │   │   ├── BonjourBrowser.swift  # NWBrowser duyệt tìm mDNS services
│   │   │   ├── UnicastProber.swift   # NetBIOS UDP 137, mDNS 5353, LLMNR 5355, Local PTR 53, SNMP 161, TCP probe
│   │   │   └── LanScannerEngine.swift# TaskGroup quét đa luồng kết hợp dải Subnet & lưu lịch sử
│   │   ├── PortScanner/
│   │   │   ├── PortScannerModels.swift # Cổng mở/đóng/lọc & Database tên dịch vụ IANA
│   │   │   └── PortScannerEngine.swift # Quét cổng bằng NWConnection & TaskGroup giới hạn 200 tasks
│   │   ├── Ping/
│   │   │   ├── PingModels.swift      # Kết quả gói tin & Thống kê RTT min/avg/max/stddev
│   │   │   ├── ICMPEngine.swift      # Socket ICMP & ICMPv6 Datagram (SOCK_DGRAM) không cần root
│   │   │   ├── PingService.swift     # Quản lý chuỗi gói tin ping liên tục
│   │   │   ├── TracerouteModels.swift# Model Hop, RTT, Trạng thái, GeoIP
│   │   │   ├── TracerouteEngine.swift# Traceroute IPv4 (IP_TTL) & IPv6 (IPV6_UNICAST_HOPS)
│   │   │   └── TracerouteService.swift# Quản lý phiên traceroute đa luồng
│   │   ├── DNS/
│   │   │   ├── PublicIPService.swift # URLSession lấy Public IP, ISP, Geo location
│   │   │   ├── RDAPClient.swift      # Tra cứu WHOIS / RDAP (RFC 7480-7484)
│   │   │   ├── RDAPBootstrapManager.swift # Tải động & Cache đĩa 24h từ data.iana.org/rdap/
│   │   │   ├── WhoisTCPClient.swift  # WHOIS TCP Port 43 Fallback với DNS SSRF Validation
│   │   │   ├── DNSRecordTypes.swift  # Model bản ghi DNS (A, AAAA, MX, TXT, NS, SOA, SRV, PTR, CAA, SVCB, HTTPS)
│   │   │   └── DNSClient.swift       # DoH JSON/RFC 8484 Wire và UDP DNS Client
│   │   ├── History/
│   │   │   ├── ScanHistoryModels.swift # Model bản ghi lịch sử Codable
│   │   │   └── ScanHistoryManager.swift# Lưu trữ JSON trong Application Support (max 100/loại)
│   │   ├── Config/
│   │   │   └── AppConfigManager.swift# Cấu hình cam kết pháp lý trong Application Support
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
│   │   │   ├── UIComponents.swift    # PermissionAlertBanner, MetricItemCard, LatencyMiniChart
│   │   │   └── AuthorizationDisclaimerModal.swift # Modal cam kết chỉ quét mạng được ủy quyền
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   ├── NetworkDetailsView.swift
│   │   │   └── ScanHistoryView.swift # Màn hình xem, lọc và xóa lịch sử quét
│   │   ├── LanScanner/
│   │   │   ├── LanScannerView.swift
│   │   │   └── DeviceDetailSheet.swift
│   │   ├── PortScanner/
│   │   │   └── PortScannerView.swift
│   │   ├── Ping/
│   │   │   └── PingTracerouteView.swift
│   │   └── DNS/
│   │       ├── DNSLookupView.swift
│   │       └── RDAPLookupView.swift
│   └── Resources/
│       ├── Assets.xcassets           # AppIcon, AccentColor
│       ├── Info.plist                # Quyền Local Network, Location, Bonjour services
│       ├── Localizable.xcstrings     # Đa ngôn ngữ En / Vi (114 keys)
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

> [!NOTE]
> Môi trường phát triển hiện tại là Windows, không cài đặt Swift toolchain (`swift : The term 'swift' is not recognized`). Do đó, toàn bộ mã nguồn Swift và các bộ Unit Test mới chỉ được **rà soát bằng mắt (code review), chưa biên dịch và chưa chạy test tự động**.

| Đã kiểm chứng thực tế (chạy thật trên Windows) | Rà soát bằng mắt, chưa biên dịch (cần Mac/Swift Toolchain) | Bắt buộc kiểm chứng trên thiết bị thật (iPhone) |
|---|---|---|
| - Script Python `build_oui.py` đọc CSV và sinh `oui.json`. | - Toàn bộ mã nguồn Swift 5.9, `actor`, `@MainActor`, `Sendable`, SwiftUI Views (`PortScannerView`, `DNSLookupView`, `ScanHistoryView`, `AuthorizationDisclaimerModal`). | - Socket ICMP/ICMPv6 unprivileged nhận gói tin Type 11 / Type 3 (Time Exceeded / Hop Limit Exceeded) từ router mạng viễn thông. |
| - Tính hợp lệ cú pháp JSON của `Localizable.xcstrings` (114 keys), `oui.json`. | - **12 bộ Unit Test (70 tests)** trong `NetworkCoreTests` (`DNSCodecTests`: 7, `HostnameResolverTests`: 8, `ICMPChecksumTests`: 3, `ICMPv6CodecTests`: 5, `InterfaceClassifierTests`: 7, `OUILookupTests`: 8, `PortRangeParserTests`: 8, `PortScanStatusTests`: 6, `RDAPBootstrapParserTests`: 3, `RDAPParserTests`: 5, `TracerouteParserTests`: 4, `WhoisReferralParserTests`: 6). | - Quyền Wi-Fi SSID / BSSID (`NEHotspotNetwork.fetchCurrent`) và Entitlement thật. |
| - Cấu trúc cú pháp `project.yml` và `NetworkCore/Package.swift`. | - Lệnh `xcodegen generate` sinh project Xcode từ `project.yml`. | - Nhận diện VPN qua `utun*` active + có IP gán thực tế. |
| - Script Python quét đếm và xác thực tên 12 test classes + 70 unit tests. | - Biên dịch và link các resource bundle (`Localizable.xcstrings`, `oui.json` qua `Bundle.module`). | - Gửi probe ICMPv6 qua mạng di động IPv6-only (T-Mobile/Viettel/VNPT IPv6 APN). |
| | - Hành vi socket TCP khi thử lại (Fallback) gói tin DNS bị cắt ngắn (`TC=1`). | - Quét 65,535 cổng có bị iOS tạm dừng/ngắt kết nối nền dù đã giữ màn hình sáng hay không. |
| | - Lưu/đọc JSON lịch sử quét (`ScanHistoryManager`) trong thư mục Application Support. | - Tải và ghi đĩa cache 24h tệp RDAP bootstrap từ `data.iana.org/rdap/`. |
