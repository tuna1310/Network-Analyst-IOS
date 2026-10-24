# Network Analyst for iOS

Ứng dụng phân tích và chẩn đoán mạng chuyên nghiệp xây dựng trên **iOS 16+**, **Swift 5.9+**, **SwiftUI**, **Swift Concurrency** (`async/await`, `actor`, `TaskGroup`), và **Network.framework**.

---

## 📑 Mục Lục
1. [Tính Năng Chính](#-tính-năng-chính)
2. [Xử Lý Các Ràng Buộc Riêng Của iOS Sandbox](#-xử-lý-các-ràng-buộc-riêng-của-ios-sandbox)
3. [Danh Sách Entitlement & Cấu Hình Apple Developer Portal](#-danh-sách-entitlement--cấu-hình-apple-developer-portal)
4. [Báo Cáo Quyền Riêng Tư & Danh Sách Endpoint Ngoài](#-báo-cáo-quyền-riêng-tư--danh-sách-endpoint-ngoài)
5. [Khai Báo Privacy Manifest (PrivacyInfo.xcprivacy)](#-khai-báo-privacy-manifest-privacyinfoxcprivacy)
6. [Cấu Hình Quyền Riêng Tư Hệ Thống (Info.plist & InfoPlist.xcstrings)](#-cấu-hình-quyền-riêng-tư-hệ-thống-infoplist--infoplistxcstrings)
7. [Hướng Dẫn Tích Hợp Google Mobile Ads SDK (AdMob)](#-hướng-dẫn-tích-hợp-google-mobile-ads-sdk-admob)
8. [Cấu Trúc Thư Mục Dự Án](#-cấu-trúc-thư-mục-dự-án)
9. [Hướng Dẫn Biên Dịch, Chạy Test & Tự Động Hóa (CI/CD)](#-hướng-dẫn-biên-dịch-chạy-test--tự-động-hóa-cicd)
10. [Danh Mục 9 Việc Bắt Buộc Kiểm Thử Trên iPhone Thật](#-danh-mục-9-việc-bắt-buộc-kiểm-thử-trên-iphone-thật)
11. [Bảng Trạng Thái Kiểm Chứng (Verification Matrix)](#-bảng-trạng-thái-kiểm-chứng-verification-matrix)

---

## 🚀 Tính Năng Chính

- **Bảng tin tổng quan (Dashboard)**:
  - Tên Wi-Fi (SSID), địa chỉ MAC Router (BSSID), trạng thái kết nối mạng qua `NWPathMonitor`.
  - Thông số mạng cục bộ POSIX: IP thiết bị (`IPv4`/`IPv6`), Subnet Mask, Gateway IP, Broadcast IP, Interface (`en0`, `pdp_ip0`).
  - IP công khai (Public IP), Nhà mạng (ISP / ASN), Thành phố, Tọa độ địa lý qua HTTPS an toàn.
  - Đo độ trễ tức thời tới Gateway và máy chủ DNS Cloudflare (`1.1.1.1`).
  - Màn hình **Chi tiết mạng toàn diện (Network Details)** hỗ trợ chạm để sao chép thông số và hiển thị bảng phân loại interface (Wi-Fi, Cellular, VPN `utun*`, Hotspot `bridge*`, Loopback `lo0`).
- **Quét thiết bị mạng nội bộ (LAN Device Scanner)**:
  - Khám phá thiết bị đa luồng trong dải Subnet mà không phụ thuộc vào ARP thô của kernel.
  - Kết hợp đồng thời Bonjour (`NWBrowser`), ICMP Ping datagram, TCP Port Probing, và truy vấn Unicast (NetBIOS UDP 137, mDNS UDP 5353, LLMNR UDP 5355, Local DNS PTR UDP 53, SNMP UDP 161).
  - Khám phá địa chỉ IPv6 của thiết bị (qua mDNS AAAA); nếu không có thì để trống kèm giải thích nguyên nhân rõ ràng, không suy đoán.
  - Phân cấp ưu tiên chọn tên máy chủ (Hostname): `mDNS > NetBIOS > LLMNR > PTR` thực thi độc lập trong `NetworkCore`.
  - Tra cứu nhà sản xuất thiết bị (OUI) và phát hiện địa chỉ MAC ngẫu nhiên (Private/Randomized MAC IEEE bit 1).
- **Quét cổng TCP (Port Scanner)**:
  - Quét bằng `NWConnection` chuẩn POSIX (3-way handshake hoàn chỉnh, không raw SYN / không TCP Fast Open).
  - 3 chế độ: Top 20 phổ biến, Top 100 dịch vụ, và Tùy chọn dải cổng cú pháp linh hoạt (`80, 443, 8000-8100`) hoặc Toàn dải (`1-65535`).
  - Phân loại 4 trạng thái: `Open`, `Closed` (`ECONNREFUSED`), `Filtered` (Timeout), và `Error` (lỗi quyền hoặc mạng).
  - Tự động giữ màn hình sáng (`isIdleTimerDisabled = true`) khi quét toàn dải và tự động tạm dừng khi ứng dụng xuống nền (`didEnterBackgroundNotification`).
- **Kiểm tra độ trễ ICMP (Ping & Hop Analyzer)**:
  - Datagram ICMP/ICMPv6 Socket không đặc quyền (`SOCK_DGRAM`, `IPPROTO_ICMP` / `IPPROTO_ICMPV6`).
  - Thống kê chi tiết: Gói gửi/nhận, tỉ lệ mất gói (Packet Loss %), Min / Avg / Max / StdDev RTT.
  - Hỗ trợ cả IPv4 và IPv6 đích.
- **Dò tuyến đường Traceroute (Hop-by-Hop)**:
  - Tăng dần TTL (`IP_TTL` cho IPv4, `IPV6_UNICAST_HOPS` cho IPv6), 3 lần probe mỗi hop.
  - Phân giải Reverse DNS PTR và tra cứu quốc gia từng hop (GeoIP qua HTTPS không cần key, mặc định tắt để bảo vệ quyền riêng tư).
  - Có phương án dự phòng UDP probe tăng TTL tới cổng cao.
- **Tra cứu DNS đa bản ghi & WHOIS / RDAP**:
  - Hỗ trợ DoH (RFC 8484) và Raw UDP DNS kèm EDNS0 (RFC 6891) bộ đệm 4096 bytes, tự động thử lại qua TCP (RFC 7766) khi gặp cờ Truncated (`TC=1`).
  - Hỗ trợ các bản ghi mở rộng hiện đại RFC 9460 (`HTTPS` type 65, `SVCB` type 64) cùng các bản ghi tiêu chuẩn `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS`, `SOA`, `SRV`, `PTR`, `CAA`.
  - Tra cứu chủ sở hữu chính thức qua giao thức chuẩn **RDAP (RFC 7480-7484)** kết hợp tải động IANA Bootstrap Registry (cache đĩa 24h) và dự phòng TCP Port 43 WHOIS có cơ chế chống SSRF và DNS Rebinding.
- **Lịch sử quét cục bộ (Scan History)**:
  - Lưu trữ bằng tệp JSON (Codable) trong `Application Support/ScanHistory/history.json`, loại trừ khỏi iCloud backup (`isExcludedFromBackupKey = true`).
  - Giới hạn tối đa 100 bản ghi mỗi loại tác vụ, tự động loại bỏ bản ghi cũ nhất, ghi tệp bất đồng bộ ở background thread.
- **Cam kết quét mạng được ủy quyền (Disclaimer Modal)**:
  - Hộp thoại cảnh báo pháp lý bắt buộc người dùng xác nhận cam kết trước khi thực hiện bất kỳ lượt quét LAN, quét cổng hoặc traceroute nào.

---

## 🛡️ Xử Lý Các Ràng Buộc Riêng Của iOS Sandbox

### 1. iOS chặn truy cập bảng ARP thô (`/proc/net/arp` / `SIOCGARP`)
- **Vấn đề**: Từ iOS 10+, Apple cấm đọc bảng ARP của kernel trong sandbox.
- **Giải pháp**:
  - Tính toán dải IP subnet từ IP thiết bị và Netmask.
  - Thăm dò song song bằng **UnicastProber**:
    1. **NetBIOS Name Service (UDP 137)**: Gửi *Node Status Query* theo RFC 1002 để lấy tên máy và địa chỉ MAC card mạng thật của thiết bị Windows/Samba/NAS.
    2. **mDNS Unicast (UDP 5353)**: Truy vấn bản ghi PTR hoặc `.local` và lấy địa chỉ IPv6 (AAAA).
    3. **LLMNR (UDP 5355)**: Truy vấn Link-Local Multicast Name Resolution cho máy trạm Windows.
    4. **Local DNS PTR (UDP 53)**: Truy vấn phân giải ngược gửi trực tiếp tới router gateway nội bộ với timeout ngắn (500ms).
    5. **SNMP v1/v2c (UDP 161)**: Gửi GetRequest cho OID `sysDescr.0` tới community `public` để nhận diện router/máy in.
    6. **Bonjour (`NWBrowser`)**: Quét song song các service type phổ biến.
    7. **TCP Connect Probe**: Kiểm tra bắt tay TCP 3-bước trên các cổng dịch vụ nhận diện nhanh (80, 443, 22, 445, 8080, 5000, 62078).

### 2. Socket ICMP không cần root & Ràng buộc Traceroute
- **Ping**: Sử dụng Datagram ICMP Socket chuẩn POSIX Darwin: `socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)` và `socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)`.
- **Ràng buộc Traceroute & ICMPv6 Checksum**:
  - *ICMP Type 11 / Type 3*: Trên nhân Darwin/iOS, socket ICMP không đặc quyền (`SOCK_DGRAM`) có thể bị kernel lọc không chuyển tiếp gói tin ICMP Type 11 (IPv4 Time Exceeded) hoặc Type 3 (IPv6 Hop Limit Exceeded) về tầng ứng dụng. Cần kiểm chứng trực tiếp trên thiết bị iPhone thật.
  - *ICMPv6 Checksum*: Trên lý thuyết, một số phiên bản Darwin kernel tự tính checksum cho socket datagram ICMPv6. Tuy nhiên, hành vi này chưa chắc chắn trên mọi thiết bị thương mại. `NetworkCore` cung cấp sẵn hàm tính toán checksum RFC 4443 pseudo-header dự phòng.
  - *UDP fallback*: Hỗ trợ gửi probe UDP tăng TTL tới cổng cao (33434+) để đón nhận phản hồi nếu ICMP bị chặn.

### 3. Tra cứu OUI & Phát hiện MAC Ngẫu Nhiên
- **Phát hiện MAC Ngẫu nhiên (Private / Randomized MAC)**:
  - Bit 1 của byte đầu tiên là bit U/L (Universal/Local). Nếu `(byte0 & 0x02) != 0`, địa chỉ MAC là do hệ điều hành sinh ngẫu nhiên để bảo vệ quyền riêng tư Wi-Fi. Ứng dụng lập tức gắn nhãn `"Private/Random MAC"`.
- **Dữ liệu OUI IEEE**:
  - Tải file chính thức `https://standards-oui.ieee.org/oui/oui.csv` và chạy `python3 Scripts/build_oui.py` để sinh file `oui.json` đầy đủ (hỗ trợ MA-L, MA-M, MA-S).

### 4. Đọc SSID và BSSID trên iOS 14+
- Yêu cầu entitlement `com.apple.developer.networking.wifi-info` cùng quyền Vị trí (`NSLocationWhenInUseUsageDescription`).
- Gọi `NEHotspotNetwork.fetchCurrent` bất đồng bộ, xử lý rõ các trường hợp lỗi quyền hoặc chạy trên Simulator.

### 5. Phòng Chống SSRF & DNS Rebinding Trong WHOIS TCP 43
- Trước khi chuyển tiếp referral sang máy chủ mới, ứng dụng phân giải DNS và từ chối nếu bất kỳ IP nào trỏ về dải nội bộ/loopback/link-local/ULA.
- Sau khi xác thực, ứng dụng kết nối **thẳng tới địa chỉ IP đã xác thực** (`NWEndpoint.Host(validatedIP)`) thay vì kết nối lại bằng hostname, ngăn chặn hoàn toàn nguy cơ tấn công **DNS Rebinding**.

---

## 🔑 Danh Sách Entitlement & Cấu Hình Apple Developer Portal

### 1. Entitlement: Access Wi-Fi Information
- **Khóa Entitlement**: `com.apple.developer.networking.wifi-info` (Boolean `true`)
- **Mục đích**: Bắt buộc trên iOS 14+ để `NEHotspotNetwork.fetchCurrent` có thể đọc SSID và BSSID của mạng Wi-Fi hiện tại.
- **Cách kích hoạt trên Apple Developer Portal**:
  1. Đăng nhập [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list).
  2. Chọn App ID của dự án (ví dụ `com.developer.NetworkAnalyst`).
  3. Trong tab **Capabilities**, tích chọn **Access Wi-Fi Information**.
  4. Bấm **Save** và tạo lại/tải về Provisioning Profile mới.

### 2. Entitlement: Multicast Networking (Tùy chọn nâng cao)
- **Khóa Entitlement**: `com.apple.developer.networking.multicast` (Boolean `true`)
- **Tại sao Apple hạn chế**: Từ iOS 14.5+, Apple chặn các ứng dụng bên thứ ba lắng nghe hoặc gửi gói tin multicast/broadcast tự do (như nhận thông điệp multicast 224.0.0.251 / SSDP 239.255.255.250 mà không qua daemon hệ thống).
- **Cách Network Analyst giải quyết mà KHÔNG cần entitlement này**:
  - Ứng dụng sử dụng `NWBrowser` của `Network.framework` (chạy qua daemon Bonjour chính thức của Apple, hoàn toàn hợp lệ và không cần entitlement đặc biệt).
  - Kết hợp với `UnicastProber`: gửi các truy vấn unicast trực tiếp tới từng địa chỉ IP trong subnet (`192.168.1.1` đến `192.168.1.254`). Nhờ đó, ứng dụng hoạt động 100% trên mọi thiết bị App Store mà không bắt buộc phải có entitlement multicast.
- **Cách xin entitlement nếu muốn mở rộng lắng nghe raw multicast**:
  - Truy cập biểu mẫu của Apple tại: [developer.apple.com/contact/request/networking-multicast](https://developer.apple.com/contact/request/networking-multicast).
  - Điền lý do: *"Chẩn đoán và phân tích cấu hình thiết bị IoT / mDNS trong mạng cục bộ"*. Sau khi Apple phê duyệt, tích chọn capability này trong App ID.

---

## 🌐 Báo Cáo Quyền Riêng Tư & Danh Sách Endpoint Ngoài

Toàn bộ các kết nối ra ngoài Internet của ứng dụng được kiểm soát chặt chẽ, tuân thủ 100% Apple App Transport Security (ATS):

| Endpoint | Mục đích | Thời điểm gọi | Gửi IP người dùng? | Giao thức | Trạng thái ATS |
|---|---|---|---|---|---|
| `https://ipwho.is/` (hoặc `ident.me` / `ipify.org`) | Lấy thông tin Public IP, ISP, ASN, Quốc gia, Tọa độ | Tự động khi mở Dashboard hoặc khi bấm làm mới | Có (máy chủ nhận được IP nguồn của kết nối HTTPS) | HTTPS (TLS 1.3) | Tuân thủ 100% ATS mặc định |
| `https://data.iana.org/rdap/` (`dns.json`, `ipv4.json`, `ipv6.json`, `asn.json`) | Tải dữ liệu IANA Bootstrap Registry để định tuyến máy chủ RDAP chính thức | Tự động tải nền khi mở tra cứu RDAP lần đầu, cache đĩa 24h | Có (IP nguồn kết nối HTTPS) | HTTPS | Tuân thủ 100% ATS |
| `https://rdap.org/` | Cổng phân phối truy vấn RDAP dự phòng (RFC 7484) | Chỉ khi người dùng bấm tra cứu RDAP | Có (IP nguồn kết nối HTTPS) | HTTPS | Tuân thủ 100% ATS |
| Các máy chủ RDAP ủy quyền (Verisign, PIR, ARIN, RIPE, APNIC, VNNIC...) | Tra cứu hồ sơ đăng ký chính thức của tên miền/IP/ASN | Khi người dùng thực hiện tra cứu RDAP | Có (IP nguồn kết nối HTTPS) | HTTPS | Tuân thủ 100% ATS |
| `https://cloudflare-dns.com/dns-query` | Phân giải DNS DoH wire-format (RFC 8484) | Khi người dùng chọn Cloudflare và bấm tra cứu DNS | Có (kết nối HTTPS) | HTTPS | Tuân thủ 100% ATS |
| `https://dns.google/resolve` | Phân giải DNS DoH | Khi người dùng chọn Google và bấm tra cứu DNS | Có (kết nối HTTPS) | HTTPS | Tuân thủ 100% ATS |
| `https://dns.quad9.net/dns-query` | Phân giải DNS DoH | Khi người dùng chọn Quad9 và bấm tra cứu DNS | Có (kết nối HTTPS) | HTTPS | Tuân thủ 100% ATS |
| `whois.iana.org` (và các máy chủ Whois referral) | Truy vấn hồ sơ Whois văn bản dự phòng (RFC 3912) | Chỉ khi người dùng bấm nút "Truy vấn WHOIS qua TCP 43" | Có | TCP Port 43 (Non-HTTP) | Không qua HTTP, không vi phạm ATS. Có cơ chế DNS SSRF & Rebinding check trước khi kết nối |
| DNS Gateway / Resolver IP (Port 53) | Phân giải DNS qua UDP 53 / TCP 53 khi người dùng chọn Gateway/Custom IP | Khi người dùng chọn phân giải qua Gateway hoặc IP tùy chỉnh | Chỉ lưu chuyển trong LAN hoặc tới IP tùy chỉnh | Raw UDP/TCP Port 53 | Không qua HTTP, không vi phạm ATS |

> [!IMPORTANT]
> **Xác nhận cấu hình ATS**: Dự án **KHÔNG bật** `NSAllowsArbitraryLoads = true`. Mọi kết nối HTTP không mã hóa đều bị chặn hoàn toàn ở tầng hệ điều hành.

---

## 🔒 Khai Báo Privacy Manifest (PrivacyInfo.xcprivacy)

Tệp `NetworkAnalyst/Resources/PrivacyInfo.xcprivacy` được cấu hình đầy đủ theo quy định của Apple (áp dụng từ mùa xuân 2024):
1. **Không theo dõi người dùng**:
   - `NSPrivacyTracking`: `false`
   - `NSPrivacyTrackingDomains`: Danh sách rỗng (`[]`).
2. **Không thu thập dữ liệu định danh**:
   - `NSPrivacyCollectedDataTypes`: Danh sách rỗng (`[]`). Toàn bộ phân tích mạng chạy trực tiếp trên thiết bị (On-Device).
3. **Khai báo Required Reason API**:
   - Qua rà soát mã nguồn tự động, ứng dụng **chỉ sử dụng duy nhất một nhóm API Required Reason**:
     - **API Category**: `NSPrivacyAccessedAPICategoryFileTimestamp`
     - **Lý do sử dụng (Reason Code)**: `C617.1` (*"Inside app container - To access the timestamps, size, or other metadata of files inside the app container, app group, or user-granted documents, for purposes of app functionality"*).
     - **Vị trí sử dụng**: Trong `RDAPBootstrapManager.swift` đọc thuộc tính `attrs[.modificationDate]` để kiểm tra hạn sử dụng 24 giờ của tệp cache đĩa trước khi tải bản cập nhật bootstrap từ IANA.
   - Ứng dụng **không sử dụng** `UserDefaults`, `systemUptime`, hay `diskSpace` API.

---

## 📜 Cấu Hình Quyền Riêng Tư Hệ Thống (Info.plist & InfoPlist.xcstrings)

Ứng dụng cung cấp tệp đa ngôn ngữ `InfoPlist.xcstrings` (Tiếng Anh & Tiếng Việt) mô tả trung thực mục đích sử dụng quyền:
- `NSLocalNetworkUsageDescription`:
  - **Tiếng Việt**: *"Network Analyst cần quyền truy cập Mạng cục bộ để quét tìm các thiết bị kết nối trong mạng Wi-Fi, kiểm tra cổng mở và phân tích cấu hình mạng LAN."*
  - **Tiếng Anh**: *"Network Analyst requires Local Network access to discover connected devices on your Wi-Fi, probe active ports, and analyze LAN configurations."*
- `NSLocationWhenInUseUsageDescription`:
  - **Tiếng Việt**: *"Quyền vị trí là yêu cầu bắt buộc của Apple iOS để ứng dụng có thể đọc và hiển thị tên mạng Wi-Fi (SSID) và địa chỉ phần cứng router (BSSID)."*
  - **Tiếng Anh**: *"Location access is strictly required by Apple iOS to read and display the current Wi-Fi network name (SSID) and router hardware address (BSSID)."*
- `NSBonjourServices`: Đăng ký sẵn danh sách 12 service types phổ biến (`_http._tcp`, `_https._tcp`, `_smb._tcp`, `_airplay._tcp`, `_raop._tcp`, `_ipp._tcp`, `_printer._tcp`, `_googlecast._tcp`, `_matter._tcp`, `_ssh._tcp`, `_companion-link._tcp`, `_workstation._tcp`).

---

## 📢 Hướng Dẫn Tích Hợp Google Mobile Ads SDK (AdMob)

Dự án hiện đang sử dụng `MockAdService` (triển khai đầy đủ giao diện `AdServiceProtocol`, hỗ trợ Banner ở chân trang và Interstitial đếm ngược).

Để gắn Google Mobile Ads SDK thật, hãy thực hiện các bước sau:

### Bước 1: Thêm Google Mobile Ads qua Swift Package Manager (SPM)
1. Trong Xcode, vào menu: **File** > **Add Package Dependencies...**
2. Dán URL: `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`
3. Chọn version mới nhất, chọn target **NetworkAnalyst** và bấm **Add Package**.

### Bước 2: Cập nhật `Info.plist`
Mở `NetworkAnalyst/Resources/Info.plist` và thêm App ID AdMob cùng các mạng quảng cáo:
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

### Bước 3: Tích hợp ATT (App Tracking Transparency) & Google UMP Consent
- Nếu bật quảng cáo được cá nhân hóa, bạn cần thêm `NSUserTrackingUsageDescription` vào `Info.plist` và `InfoPlist.xcstrings`.
- Tích hợp Google User Messaging Platform (UMP) SDK để xin chấp thuận người dùng tại Châu Âu (GDPR) và California (CCPA).
- Bổ sung các loại dữ liệu theo dõi vào `PrivacyInfo.xcprivacy` theo tài liệu hướng dẫn của Google AdMob.

### Bước 4: Tạo `AdMobService.swift` hiện thực `AdServiceProtocol`
Tạo tệp `NetworkAnalyst/Services/Ads/AdMobService.swift` triển khai `GADMobileAds.sharedInstance().start(...)`, `GADBannerView`, và `GADInterstitialAd`. Sau đó trong `NetworkAnalystApp.swift`, đổi `@StateObject private var adService = MockAdService.shared` thành `AdMobService.shared`.

---

## 📂 Cấu Trúc Thư Mục Dự Án

```
NetworkAnalystIOS/
├── project.yml                       # File đặc tả XcodeGen chính thức của dự án
├── .github/workflows/ci.yml          # GitHub Actions CI Workflow chạy trên macOS-14
├── NetworkCore/                      # Swift Package chứa toàn bộ logic thuần (có unit tests độc lập)
│   ├── Package.swift
│   ├── Sources/NetworkCore/
│   │   ├── DNSCodec.swift            # Bộ mã hóa/giải mã DNS nhị phân, EDNS0, HTTPS/SVCB RFC 9460
│   │   ├── HostnameResolver.swift    # Phân cấp mDNS > NetBIOS > LLMNR > PTR, in-addr/ip6.arpa
│   │   ├── ICMPChecksum.swift        # RFC 1071 Internet Checksum
│   │   ├── ICMPv6Parser.swift        # RFC 4443 ICMPv6 Codec & Checksum kèm IPv6 Pseudo-Header
│   │   ├── InterfaceClassifier.swift # Phân loại interface mạng & phát hiện VPN thực tế
│   │   ├── OUIDatabase.swift         # Tra cứu IEEE OUI 24/28/36-bit & Random MAC bit 1
│   │   ├── PortRangeParser.swift     # Phân tích dải cổng cú pháp tùy chọn 1-65535 & ước tính thời gian
│   │   ├── RDAPBootstrap.swift       # Quản lý ánh xạ bootstrap TLD và dự phòng offline
│   │   ├── RDAPBootstrapParser.swift # Parser tệp JSON IANA bootstrap registry
│   │   ├── RDAPParser.swift          # Parser JSON phản hồi RDAP RFC 7483/9083
│   │   ├── ScanHistoryStore.swift    # Logic thuần quản lý lịch sử Codable, versioning, max 100
│   │   ├── TracerouteParser.swift    # Parser gói tin phản hồi Traceroute RFC 792
│   │   └── WhoisReferralParser.swift # Parser văn bản Whois RFC 3912 & kiểm tra IP SSRF
│   └── Tests/NetworkCoreTests/       # 13 Test Classes (77 Unit Tests)
├── NetworkAnalyst/                   # Target ứng dụng chính iOS
│   ├── App/
│   │   ├── NetworkAnalystApp.swift
│   │   └── MainTabView.swift
│   ├── Core/
│   │   ├── NetworkInterfaceInfo.swift# POSIX getifaddrs, Subnet CIDR, Gateway routing table
│   │   ├── NetworkMonitor.swift      # NWPathMonitor quan sát Wi-Fi, Cellular
│   │   ├── LocationAndWiFiManager.swift # NEHotspotNetwork đọc SSID/BSSID
│   │   └── LocalNetworkPermissionManager.swift
│   ├── Services/
│   │   ├── DeviceScanner/            # DiscoveredDevice, BonjourBrowser, UnicastProber, LanScannerEngine
│   │   ├── PortScanner/              # PortScannerModels, PortScannerEngine (Sliding window 200 tasks)
│   │   ├── Ping/                     # PingModels, ICMPEngine (IPv4/IPv6), TracerouteEngine, TracerouteService
│   │   ├── DNS/                      # PublicIPService, RDAPClient, RDAPBootstrapManager, WhoisTCPClient, DNSClient
│   │   ├── History/                  # ScanHistoryManager (JSON trong Application Support, exclude backup)
│   │   ├── Config/                   # AppConfigManager (Cam kết ủy quyền trong Application Support)
│   │   └── Ads/                      # AdServiceProtocol, AdViews, MockAdService
│   ├── ViewModels/                   # Dashboard, LanScanner, PortScanner, Ping, DNSLookup, RDAP
│   ├── Views/
│   │   ├── Components/               # UIComponents, AuthorizationDisclaimerModal
│   │   ├── Dashboard/                # DashboardView, NetworkDetailsView, ScanHistoryView
│   │   ├── LanScanner/               # LanScannerView, DeviceDetailSheet
│   │   ├── PortScanner/              # PortScannerView
│   │   ├── Ping/                     # PingTracerouteView
│   │   └── DNS/                      # DNSLookupView, RDAPLookupView
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Info.plist
│       ├── InfoPlist.xcstrings       # Đa ngôn ngữ En/Vi cho mô tả quyền hệ thống
│       ├── Localizable.xcstrings     # Đa ngôn ngữ En/Vi (213 keys) cho toàn bộ ứng dụng
│       ├── NetworkAnalyst.entitlements
│       ├── oui.json
│       └── PrivacyInfo.xcprivacy     # Apple Privacy Manifest (File timestamp C617.1)
└── Scripts/
    ├── build_oui.py                  # Script sinh oui.json từ CSV
    ├── audit_strings.py              # Script quét chuỗi UI chưa khai báo
    └── validate_localizable.py       # Script kiểm tra 100% key có đủ En và Vi
```

---

## 🛠️ Hướng Dẫn Biên Dịch, Chạy Test & Tự Động Hóa (CI/CD)

### 1. Sinh Dự Án Bằng XcodeGen
Trên macOS có Xcode 15+, chạy lệnh:
```bash
brew install xcodegen
xcodegen generate
```
Lệnh sẽ đọc `project.yml` và tạo ra `NetworkAnalyst.xcodeproj` chuẩn với 2 target: `NetworkAnalyst` (App iOS 16+) và `NetworkAnalystTests` (Unit Tests).

### 2. Chạy Kiểm Thử Độc Lập Cho NetworkCore
Package `NetworkCore` hoàn toàn độc lập với UI, có thể chạy test trực tiếp từ terminal:
```bash
swift test --package-path NetworkCore
```

### 3. Chạy Toàn Bộ Test Trên iOS Simulator
```bash
xcodebuild test \
  -project NetworkAnalyst.xcodeproj \
  -scheme NetworkAnalystTests \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

### 4. Tự Động Hóa Với GitHub Actions CI
Dự án đã tích hợp tệp workflow `.github/workflows/ci.yml`. Mỗi khi push hoặc mở pull request lên nhánh `master` hoặc `main`, máy ảo GitHub Actions `macos-14` sẽ tự động:
1. Cài đặt XcodeGen qua Homebrew.
2. Sinh `NetworkAnalyst.xcodeproj`.
3. Chạy toàn bộ 77 unit tests của `NetworkCore`.
4. Biên dịch và chạy test trên iOS Simulator iPhone 15.
*(Lưu ý: Tệp CI mới chỉ được soạn thảo và kiểm tra cú pháp, chưa chạy trên môi trường Windows hiện tại).*

---

## 📱 Danh Mục 9 Việc Bắt Buộc Kiểm Thử Trên iPhone Thật

Do sandbox và phần cứng của iOS trên thiết bị thương mại có các hạn chế riêng mà iOS Simulator không thể mô phỏng chính xác, các hạng mục sau bắt buộc phải kiểm thử trực tiếp trên iPhone thật:

1. **Traceroute nhận gói tin ICMP Type 11 / Type 3**:
   - Kiểm tra xem socket ICMP datagram unprivileged trên iOS có nhận được gói tin Time Exceeded khi tăng dần TTL qua mạng Wi-Fi và mạng 4G/5G hay không, hay bị kernel lọc bỏ dẫn tới các hop hiển thị `* * *`.
2. **Kiểm tra tính toán Checksum ICMPv6 trên thiết bị thương mại**:
   - Kiểm tra xem gói tin Echo Request IPv6 gửi với checksum 0x0000 có được kernel Darwin trên thiết bị thật tự động tính toán hay không, hoặc cần chuyển sang cờ tự tính RFC 4443 pseudo-header checksum.
3. **Đọc tên Wi-Fi (SSID) và địa chỉ Router (BSSID)**:
   - Cài đặt app lên iPhone thật với Provisioning Profile có capability **Access Wi-Fi Information**, cấp quyền Vị trí và kiểm tra `NEHotspotNetwork.fetchCurrent` trả về đúng tên Wi-Fi đang kết nối.
4. **Nhận diện giao diện VPN thực tế**:
   - Bật một kết nối VPN thật (WireGuard, OpenVPN, Tailscale, hoặc Cloudflare WARP) và kiểm tra bảng Interface trong màn hình Network Details: interface `utun*` chỉ được gắn cờ "Đang kết nối VPN" khi trạng thái là UP và đã được cấp phát địa chỉ IP hợp lệ.
5. **Quét toàn dải 65,535 cổng TCP & Quản lý vòng đời**:
   - Khởi động quét toàn dải cổng, quan sát màn hình có được giữ sáng (`isIdleTimerDisabled`) hay không; ấn phím Home hoặc chuyển sang app khác để kiểm tra app có tự động tạm dừng (`didEnterBackgroundNotification`) và bảo toàn kết quả hay không.
6. **Mạng di động đa SIM (Dual SIM / eSIM)**:
   - Thử nghiệm trên iPhone có 2 SIM (vật lý + eSIM) để xác minh việc hiển thị tên nhà mạng và công nghệ mạng di động không bị crash do `CTCarrier` bị Apple deprecated.
7. **Khám phá mDNS IPv6 (AAAA) trong mạng LAN**:
   - Kiểm tra khả năng phân giải địa chỉ IPv6 nội bộ của các thiết bị Apple hoặc máy chủ Linux trên cùng subnet Wi-Fi.
8. **Quyền riêng tư Mạng cục bộ (Local Network)**:
   - Khởi chạy quét lần đầu để quan sát hộp thoại xin quyền `NSLocalNetworkUsageDescription` của hệ điều hành; thử từ chối quyền và xác nhận ứng dụng hiển thị banner hướng dẫn người dùng vào Cài đặt cấp lại quyền thay vì crash.
9. **Kết nối WHOIS TCP Port 43 qua mạng di động**:
   - Thử nghiệm truy vấn WHOIS cổng 43 khi chỉ bật dữ liệu di động (4G/5G) để xác minh nhà mạng viễn thông có chặn kết nối outbound TCP 43 hay không.

---

## 🔍 Bảng Trạng Thái Kiểm Chứng (Verification Matrix)

> [!NOTE]
> Môi trường phát triển hiện tại là Windows, không cài đặt Swift toolchain (`swift : The term 'swift' is not recognized`). Do đó, toàn bộ mã nguồn Swift và các bộ Unit Test mới chỉ được **rà soát bằng mắt (code review), chưa biên dịch và chưa chạy test tự động**.

| Đã kiểm chứng thực tế (chạy thật trên Windows) | Rà soát bằng mắt, chưa biên dịch (cần Mac/Swift Toolchain) | Bắt buộc kiểm chứng trên thiết bị thật (iPhone) |
|---|---|---|
| - Script Python `validate_localizable.py` kiểm tra 213/213 keys có đủ En và Vi (0 thiếu sót). | - Toàn bộ mã nguồn Swift 5.9, `actor`, `@MainActor`, `Sendable`, SwiftUI Views (`ScanHistoryView`, `AuthorizationDisclaimerModal`, `DeviceDetailSheet`, `PortScannerView`). | - Socket ICMP/ICMPv6 datagram unprivileged nhận gói tin Type 11 / Type 3 từ router nhà mạng. |
| - Script Python `audit_strings.py` rà soát 100% chuỗi UI trong toàn bộ ViewModels và Views. | - **13 bộ Unit Test (77 unit tests) (đã viết, chưa chạy trên môi trường này)** trong `NetworkCoreTests`. | - Quyền Wi-Fi SSID / BSSID (`NEHotspotNetwork.fetchCurrent`) và Entitlement thật. |
| - Tính hợp lệ cú pháp JSON của `Localizable.xcstrings` (213 keys), `InfoPlist.xcstrings`, `oui.json`, `Assets.xcassets`. | - Lệnh `xcodegen generate` sinh project Xcode từ `project.yml`. | - Nhận diện VPN qua `utun*` active + có IP gán thực tế. |
| - Tính hợp lệ XML plist của `PrivacyInfo.xcprivacy`, `Info.plist`, `NetworkAnalyst.entitlements`. | - Biên dịch và link các resource bundle (`Localizable.xcstrings`, `oui.json` qua `Bundle.module`). | - Gửi probe ICMPv6 qua mạng di động IPv6-only (T-Mobile/Viettel/VNPT IPv6 APN). |
| - Script Python `build_oui.py` đọc CSV và sinh `oui.json`. | - Tải và ghi đĩa cache 24h tệp RDAP bootstrap từ `data.iana.org/rdap/`. | - Quét 65,535 cổng có bị iOS tạm dừng/ngắt kết nối nền dù đã giữ màn hình sáng hay không. |
| - Cấu trúc cú pháp `project.yml`, `NetworkCore/Package.swift`, và workflow `.github/workflows/ci.yml`. | - Lưu/đọc JSON lịch sử quét (`ScanHistoryManager`) và config (`AppConfigManager`) trong `Application Support`. | - Hành vi giữ màn hình sáng và tự động tạm dừng khi app xuống nền. |
| | - Hành vi socket TCP khi thử lại (Fallback) gói tin DNS bị cắt ngắn (`TC=1`). | - Kết nối WHOIS TCP Port 43 qua mạng 4G/5G. |
