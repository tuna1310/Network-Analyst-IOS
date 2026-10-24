import json

translations = {
    "Cam kết quét mạng được ủy quyền": {
        "en": "Authorized Scanning Commitment",
        "vi": "Cam kết quét mạng được ủy quyền"
    },
    "Bạn chỉ được phép quét cổng, phân tích mạng và thăm dò dịch vụ trên những thiết bị hoặc mạng mà bạn sở hữu hoặc đã được ủy quyền hợp pháp.": {
        "en": "You may only scan ports, analyze networks, and probe services on devices or networks that you own or have legal authorization to assess.",
        "vi": "Bạn chỉ được phép quét cổng, phân tích mạng và thăm dò dịch vụ trên những thiết bị hoặc mạng mà bạn sở hữu hoặc đã được ủy quyền hợp pháp."
    },
    "Hành vi quét mạng không có thẩm quyền có thể kích hoạt hệ thống phát hiện xâm nhập (IDS/IPS), bị chặn kết nối, hoặc vi phạm pháp luật an toàn thông tin.": {
        "en": "Unauthorized network scanning may trigger intrusion detection systems (IDS/IPS), result in blocked connections, or violate cybersecurity laws.",
        "vi": "Hành vi quét mạng không có thẩm quyền có thể kích hoạt hệ thống phát hiện xâm nhập (IDS/IPS), bị chặn kết nối, hoặc vi phạm pháp luật an toàn thông tin."
    },
    "Toàn bộ tiến trình quét được xử lý trực tiếp trên thiết bị (On-Device), bảo mật và không truyền dữ liệu nội bộ tới bất kỳ máy chủ nào.": {
        "en": "All scans are processed directly on-device, securely, and no internal network data is transmitted to external servers.",
        "vi": "Toàn bộ tiến trình quét được xử lý trực tiếp trên thiết bị (On-Device), bảo mật và không truyền dữ liệu nội bộ tới bất kỳ máy chủ nào."
    },
    "Tôi đã hiểu và cam kết tuân thủ": {
        "en": "I understand and agree to comply",
        "vi": "Tôi đã hiểu và cam kết tuân thủ"
    },
    "Biểu đồ Độ trễ RTT (ms)": {
        "en": "RTT Latency Chart (ms)",
        "vi": "Biểu đồ Độ trễ RTT (ms)"
    },
    "Xem chi tiết": {
        "en": "View Details",
        "vi": "Xem chi tiết"
    },
    "Tổng quan mạng": {
        "en": "Network Overview",
        "vi": "Tổng quan mạng"
    },
    "Lịch sử": {
        "en": "History",
        "vi": "Lịch sử"
    },
    "Tên mạng (SSID)": {
        "en": "Network Name (SSID)",
        "vi": "Tên mạng (SSID)"
    },
    "Thông tin SSID/BSSID được iOS bảo vệ:": {
        "en": "SSID/BSSID protected by iOS:",
        "vi": "Thông tin SSID/BSSID được iOS bảo vệ:"
    },
    "iOS yêu cầu quyền 'Vị trí khi dùng' để hiển thị tên Wi-Fi (SSID).": {
        "en": "iOS requires 'While Using App' Location permission to display the Wi-Fi name (SSID).",
        "vi": "iOS yêu cầu quyền 'Vị trí khi dùng' để hiển thị tên Wi-Fi (SSID)."
    },
    "Cấp quyền Vị trí": {
        "en": "Grant Location Permission",
        "vi": "Cấp quyền Vị trí"
    },
    "Đang kiểm tra thông tin điểm truy cập Wi-Fi...": {
        "en": "Checking Wi-Fi access point information...",
        "vi": "Đang kiểm tra thông tin điểm truy cập Wi-Fi..."
    },
    "CẤU HÌNH MẠNG CỤC BỘ (LAN)": {
        "en": "LOCAL NETWORK CONFIGURATION (LAN)",
        "vi": "CẤU HÌNH MẠNG CỤC BỘ (LAN)"
    },
    "Địa chỉ IPv6 nội bộ:": {
        "en": "Internal IPv6 Address:",
        "vi": "Địa chỉ IPv6 nội bộ:"
    },
    "INTERNET & IP CÔNG KHAI": {
        "en": "INTERNET & PUBLIC IP",
        "vi": "INTERNET & IP CÔNG KHAI"
    },
    "Địa chỉ IP Công khai (Public IP)": {
        "en": "Public IP Address",
        "vi": "Địa chỉ IP Công khai (Public IP)"
    },
    "Nhà mạng (ISP / ASN)": {
        "en": "Service Provider (ISP / ASN)",
        "vi": "Nhà mạng (ISP / ASN)"
    },
    "Vị trí địa lý": {
        "en": "Geographic Location",
        "vi": "Vị trí địa lý"
    },
    "Đang tra cứu thông tin địa chỉ IP công khai...": {
        "en": "Looking up public IP information...",
        "vi": "Đang tra cứu thông tin địa chỉ IP công khai..."
    },
    "KIỂM TRA ĐỘ TRỄ NHANH (ICMP)": {
        "en": "QUICK LATENCY CHECK (ICMP)",
        "vi": "KIỂM TRA ĐỘ TRỄ NHANH (ICMP)"
    },
    "Router Gateway": {
        "en": "Router Gateway",
        "vi": "Router Gateway"
    },
    "Cloudflare (1.1.1.1)": {
        "en": "Cloudflare (1.1.1.1)",
        "vi": "Cloudflare (1.1.1.1)"
    },
    "Chưa gán địa chỉ IP": {
        "en": "No IP address assigned",
        "vi": "Chưa gán địa chỉ IP"
    },
    "Lịch sử phân tích": {
        "en": "Scan History",
        "vi": "Lịch sử phân tích"
    },
    "Hủy": {
        "en": "Cancel",
        "vi": "Hủy"
    },
    "Xóa tất cả": {
        "en": "Clear All",
        "vi": "Xóa tất cả"
    },
    "Thao tác này sẽ xóa vĩnh viễn toàn bộ nhật ký quét đã lưu trên máy.": {
        "en": "This action will permanently delete all scan history stored on this device.",
        "vi": "Thao tác này sẽ xóa vĩnh viễn toàn bộ nhật ký quét đã lưu trên máy."
    },
    "Chưa có lịch sử quét": {
        "en": "No scan history yet",
        "vi": "Chưa có lịch sử quét"
    },
    "Kết quả từ các lần quét mạng LAN, kiểm tra cổng, ping và traceroute sẽ tự động được lưu lại tại đây.": {
        "en": "Results from LAN scans, port scans, ping, and traceroute will automatically appear here.",
        "vi": "Kết quả từ các lần quét mạng LAN, kiểm tra cổng, ping và traceroute sẽ tự động được lưu lại tại đây."
    },
    "Tác vụ": {
        "en": "Task",
        "vi": "Tác vụ"
    },
    "Phân loại": {
        "en": "Category",
        "vi": "Phân loại"
    },
    "Mục tiêu": {
        "en": "Target",
        "vi": "Mục tiêu"
    },
    "Thời gian": {
        "en": "Time",
        "vi": "Thời gian"
    },
    "Tóm tắt kết quả": {
        "en": "Result Summary",
        "vi": "Tóm tắt kết quả"
    },
    "Chi tiết kỹ thuật": {
        "en": "Technical Details",
        "vi": "Chi tiết kỹ thuật"
    },
    "Chi tiết bản ghi": {
        "en": "Entry Details",
        "vi": "Chi tiết bản ghi"
    },
    "DNS & WHOIS / RDAP": {
        "en": "DNS & WHOIS / RDAP",
        "vi": "DNS & WHOIS / RDAP"
    },
    "Máy chủ DNS Resolver:": {
        "en": "DNS Resolver Server:",
        "vi": "Máy chủ DNS Resolver:"
    },
    "Cloudflare (1.1.1.1 / DoH)": {
        "en": "Cloudflare (1.1.1.1 / DoH)",
        "vi": "Cloudflare (1.1.1.1 / DoH)"
    },
    "Google (8.8.8.8 / DoH)": {
        "en": "Google (8.8.8.8 / DoH)",
        "vi": "Google (8.8.8.8 / DoH)"
    },
    "Quad9 (9.9.9.9 / DoH)": {
        "en": "Quad9 (9.9.9.9 / DoH)",
        "vi": "Quad9 (9.9.9.9 / DoH)"
    },
    "Tùy chỉnh IP": {
        "en": "Custom IP",
        "vi": "Tùy chỉnh IP"
    },
    "Mạng hiện tại (Gateway)": {
        "en": "Current Network (Gateway)",
        "vi": "Mạng hiện tại (Gateway)"
    },
    "Lưu ý: Mạng hiện tại truy vấn DNS của router gateway nội bộ. Do hệ thống iOS chỉ hỗ trợ giải quyết A/AAAA, các bản ghi mở rộng (HTTPS, CAA, SRV) có thể cần chọn Cloudflare/Google.": {
        "en": "Note: Current network queries local gateway DNS. Because iOS resolvers typically only handle A/AAAA, advanced records (HTTPS, CAA, SRV) may require Cloudflare or Google via DoH.",
        "vi": "Lưu ý: Mạng hiện tại truy vấn DNS của router gateway nội bộ. Do hệ thống iOS chỉ hỗ trợ giải quyết A/AAAA, các bản ghi mở rộng (HTTPS, CAA, SRV) có thể cần chọn Cloudflare/Google."
    },
    "Tra cứu thông tin": {
        "en": "Perform Lookup",
        "vi": "Tra cứu thông tin"
    },
    "KẾT QUẢ PHÂN GIẢI DNS": {
        "en": "DNS RESOLUTION RESULTS",
        "vi": "KẾT QUẢ PHÂN GIẢI DNS"
    },
    "Không tìm thấy bản ghi nào khớp với điều kiện tìm kiếm.": {
        "en": "No records found matching the search criteria.",
        "vi": "Không tìm thấy bản ghi nào khớp với điều kiện tìm kiếm."
    },
    "Nhập tên miền và bấm 'Tra cứu thông tin' để kiểm tra bản ghi DNS.": {
        "en": "Enter a domain and tap 'Perform Lookup' to query DNS records.",
        "vi": "Nhập tên miền và bấm 'Tra cứu thông tin' để kiểm tra bản ghi DNS."
    },
    "THÔNG TIN ĐĂNG KÝ (RDAP / WHOIS)": {
        "en": "REGISTRATION DATA (RDAP / WHOIS)",
        "vi": "THÔNG TIN ĐĂNG KÝ (RDAP / WHOIS)"
    },
    "Nhập tên miền, IP hoặc ASN để tra cứu hồ sơ chủ sở hữu chính thức qua giao thức RDAP (RFC 7480-7484).": {
        "en": "Enter a domain, IP address, or ASN to lookup registration ownership records via RFC 7480-7484 RDAP.",
        "vi": "Nhập tên miền, IP hoặc ASN để tra cứu hồ sơ chủ sở hữu chính thức qua giao thức RDAP (RFC 7480-7484)."
    },
    "Loại truy vấn:": {
        "en": "Query Type:",
        "vi": "Loại truy vấn:"
    },
    "Bấm nút bên dưới để truy vấn máy chủ WHOIS qua cổng TCP 43 truyền thống:": {
        "en": "Tap below to query the classic WHOIS server over TCP port 43:",
        "vi": "Bấm nút bên dưới để truy vấn máy chủ WHOIS qua cổng TCP 43 truyền thống:"
    },
    "PHẢN HỒI GỐC RDAP (RFC 7483 JSON)": {
        "en": "RAW RDAP RESPONSE (RFC 7483 JSON)",
        "vi": "PHẢN HỒI GỐC RDAP (RFC 7483 JSON)"
    },
    "PHẢN HỒI WHOIS CỔ ĐIỂN (TCP PORT 43)": {
        "en": "CLASSIC WHOIS RESPONSE (TCP PORT 43)",
        "vi": "PHẢN HỒI WHOIS CỔ ĐIỂN (TCP PORT 43)"
    },
    "Thông Báo RDAP": {
        "en": "RDAP Notices",
        "vi": "Thông Báo RDAP"
    },
    "Nhập tên miền, IP hoặc ASN và bấm 'Tra cứu thông tin'": {
        "en": "Enter domain, IP, or ASN and tap 'Perform Lookup'",
        "vi": "Nhập tên miền, IP hoặc ASN và bấm 'Tra cứu thông tin'"
    },
    "Thông số mạng": {
        "en": "Network Parameters",
        "vi": "Thông số mạng"
    },
    "Địa chỉ IPv4": {
        "en": "IPv4 Address",
        "vi": "Địa chỉ IPv4"
    },
    "Địa chỉ IPv6": {
        "en": "IPv6 Address",
        "vi": "Địa chỉ IPv6"
    },
    "Tên máy (Hostname)": {
        "en": "Hostname",
        "vi": "Tên máy (Hostname)"
    },
    "Địa chỉ MAC": {
        "en": "MAC Address",
        "vi": "Địa chỉ MAC"
    },
    "Nhà sản xuất (Vendor)": {
        "en": "Vendor / Manufacturer",
        "vi": "Nhà sản xuất (Vendor)"
    },
    "Độ trễ phản hồi (RTT)": {
        "en": "Response Latency (RTT)",
        "vi": "Độ trễ phản hồi (RTT)"
    },
    "Phương thức phát hiện": {
        "en": "Discovery Methods",
        "vi": "Phương thức phát hiện"
    },
    "Dịch vụ Bonjour phát hiện": {
        "en": "Discovered Bonjour Services",
        "vi": "Dịch vụ Bonjour phát hiện"
    },
    "Các cổng mở sơ bộ": {
        "en": "Initially Open Ports",
        "vi": "Các cổng mở sơ bộ"
    },
    "Quét toàn bộ cổng của thiết bị này": {
        "en": "Scan all ports on this device",
        "vi": "Quét toàn bộ cổng của thiết bị này"
    },
    "Chi tiết thiết bị": {
        "en": "Device Details",
        "vi": "Chi tiết thiết bị"
    },
    "Đóng": {
        "en": "Close",
        "vi": "Đóng"
    },
    "Quét mạng LAN": {
        "en": "LAN Device Scanner",
        "vi": "Quét mạng LAN"
    },
    "BẠN": {
        "en": "YOU",
        "vi": "BẠN"
    },
    "Chưa có thiết bị nào được quét": {
        "en": "No devices discovered yet",
        "vi": "Chưa có thiết bị nào được quét"
    },
    "Nhấn 'Bắt đầu quét' để phát hiện các thiết bị kết nối trong mạng Wi-Fi cục bộ qua ICMP, TCP/UDP, NetBIOS, mDNS và Bonjour.": {
        "en": "Tap 'Start Scan' to discover connected devices on your Wi-Fi network via ICMP, TCP/UDP, NetBIOS, mDNS, and Bonjour.",
        "vi": "Nhấn 'Bắt đầu quét' để phát hiện các thiết bị kết nối trong mạng Wi-Fi cục bộ qua ICMP, TCP/UDP, NetBIOS, mDNS và Bonjour."
    },
    "Bắt đầu quét mạng": {
        "en": "Start Network Scan",
        "vi": "Bắt đầu quét mạng"
    },
    "Số gói:": {
        "en": "Packets:",
        "vi": "Số gói:"
    },
    "5 gói": {
        "en": "5 packets",
        "vi": "5 gói"
    },
    "10 gói": {
        "en": "10 packets",
        "vi": "10 gói"
    },
    "20 gói": {
        "en": "20 packets",
        "vi": "20 gói"
    },
    "50 gói": {
        "en": "50 packets",
        "vi": "50 gói"
    },
    "KẾT QUẢ THỐNG KÊ": {
        "en": "STATISTICAL RESULTS",
        "vi": "KẾT QUẢ THỐNG KÊ"
    },
    "NHẬT KÝ GÓI TIN (ICMP PACKETS)": {
        "en": "PACKET LOG (ICMP PACKETS)",
        "vi": "NHẬT KÝ GÓI TIN (ICMP PACKETS)"
    },
    "Ứng dụng đã tạm dừng khi xuống nền để bảo toàn tài nguyên. Bấm Tiếp tục để tiếp tục quét.": {
        "en": "Scan paused automatically when entering background to preserve resources. Tap Resume to continue.",
        "vi": "Ứng dụng đã tạm dừng khi xuống nền để bảo toàn tài nguyên. Bấm Tiếp tục để tiếp tục quét."
    },
    "Quét cổng TCP": {
        "en": "TCP Port Scanner",
        "vi": "Quét cổng TCP"
    },
    "Bắt đầu quét": {
        "en": "Start Scan",
        "vi": "Bắt đầu quét"
    },
    "Nhập các cổng cách nhau bằng dấu phẩy hoặc dấu gạch nối cho dải (1-65535).": {
        "en": "Enter ports separated by commas or hyphenated ranges (1-65535).",
        "vi": "Nhập các cổng cách nhau bằng dấu phẩy hoặc dấu gạch nối cho dải (1-65535)."
    },
    "Quét toàn dải 1 đến 65535. Màn hình tự động giữ sáng. Vui lòng giữ ứng dụng ở màn hình chính (foreground) để tránh bị iOS ngắt kết nối mạng nền.": {
        "en": "Scanning full range 1-65535. Screen remains awake. Keep app in foreground to avoid iOS background disconnect.",
        "vi": "Quét toàn dải 1 đến 65535. Màn hình tự động giữ sáng. Vui lòng giữ ứng dụng ở màn hình chính (foreground) để tránh bị iOS ngắt kết nối mạng nền."
    },
    "Thăm dò banner dịch vụ (Banner Grabbing)": {
        "en": "Probe service banners (Banner Grabbing)",
        "vi": "Thăm dò banner dịch vụ (Banner Grabbing)"
    },
    "Dừng": {
        "en": "Stop",
        "vi": "Dừng"
    },
    "Bắt đầu quét cổng": {
        "en": "Start Port Scan",
        "vi": "Bắt đầu quét cổng"
    },
    "Hiển thị:": {
        "en": "Display:",
        "vi": "Hiển thị:"
    },
    "MỞ": {
        "en": "OPEN",
        "vi": "MỞ"
    },
    "ĐÓNG": {
        "en": "CLOSED",
        "vi": "ĐÓNG"
    },
    "BỊ CHẶN": {
        "en": "FILTERED",
        "vi": "BỊ CHẶN"
    },
    "QUẢNG CÁO": {
        "en": "SPONSORED",
        "vi": "QUẢNG CÁO"
    },
    "Google Mobile Ads Mock": {
        "en": "Google Mobile Ads Mock",
        "vi": "Google Mobile Ads Mock"
    },
    "Banner 320x50 giả lập • Xem README để tích hợp SDK thật": {
        "en": "Mock 320x50 Banner • See README to integrate real SDK",
        "vi": "Banner 320x50 giả lập • Xem README để tích hợp SDK thật"
    },
    "Quảng cáo Toàn Màn Hình": {
        "en": "Interstitial Ad",
        "vi": "Quảng cáo Toàn Màn Hình"
    }
}

path = 'NetworkAnalyst/Resources/Localizable.xcstrings'
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

added_count = 0
for k, trans in translations.items():
    if k not in data['strings']:
        added_count += 1
    data['strings'][k] = {
        'extractionState': 'manual',
        'localizations': {
            'en': {'stringUnit': {'state': 'translated', 'value': trans['en']}},
            'vi': {'stringUnit': {'state': 'translated', 'value': trans['vi']}}
        }
    }

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Added/updated {added_count} translations in Localizable.xcstrings.")
print(f"New total keys: {len(data['strings'])}")
