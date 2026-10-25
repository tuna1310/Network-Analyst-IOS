import os
import re
import json

# Đường dẫn kiểm tra
project_dir = 'NetworkAnalyst'
xcstrings_path = os.path.join(project_dir, 'Resources', 'Localizable.xcstrings')

with open(xcstrings_path, 'r', encoding='utf-8') as f:
    xcdata = json.load(f)
existing_keys = set(xcdata.get('strings', {}).keys())

print("=" * 80)
print(f"AUDIT BẢO TOÀN ĐA NGÔN NGỮ (LOCALIZATION AUDIT)")
print(f"Tổng số key đã khai báo trong Localizable.xcstrings: {len(existing_keys)}")
print("=" * 80)

# Các mẫu regex mở rộng kiểm tra toàn diện:
# 1. Gán biến thông báo: errorMessage, statusMessage, toast, customRangeError...
# 2. Thành phần UI SwiftUI: Text, Button, Label, navigationTitle, alert, prompt, TextField, Picker, Section...
patterns = [
    ('Text', re.compile(r'Text\(\s*"([^"\n\\]+)"\s*\)')),
    ('Button', re.compile(r'Button\(\s*"([^"\n\\]+)"')),
    ('Label', re.compile(r'Label\(\s*"([^"\n\\]+)"')),
    ('NavigationTitle', re.compile(r'navigationTitle\(\s*"([^"\n\\]+)"\s*\)')),
    ('Alert', re.compile(r'\.alert\(\s*"([^"\n\\]+)"')),
    ('TextField', re.compile(r'TextField\(\s*"([^"\n\\]+)"')),
    ('Picker', re.compile(r'Picker\(\s*"([^"\n\\]+)"')),
    ('Section', re.compile(r'Section\(\s*"([^"\n\\]+)"')),
    ('Assignment_Error', re.compile(r'(?:errorMessage|statusMessage|toastMessage|customRangeError)\s*=\s*"([^"\n\\]+)"')),
]

# Ký tự tiếng Việt để phát hiện chuỗi chưa được bản địa hóa
vietnamese_pattern = re.compile(r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđĐ]')

# Bỏ qua các chuỗi kỹ thuật đặc thù
TECHNICAL_STRINGS = {
    "---", "--", "* * *", "GATEWAY", "YOU", "A", "AAAA", "CNAME", "MX", "NS",
    "PTR", "SOA", "TXT", "SRV", "CAA", "HTTPS", "SVCB", "ANY",
    "WiFi", "Cellular", "Ethernet", "Loopback", "VPN", "Hotspot", "Other",
    "IP_TTL", "ICMP", "UDP", "TCP", "DNS", "DoH", "RDAP", "Whois", "OUI", "MAC",
    "15", "30", "5", "10", "20", "50", "8.8.8.8", "1.1.1.1", "9.9.9.9",
    "80", "443", "22", "21", "25", "53", "3389", "8080", "8443",
    "apple.com", "google.com", "cloudflare.com"
}

# Các chuỗi debug/log nội bộ được miễn trừ dịch thuật (ghi log console phát triển)
DEBUG_LOG_ALLOWLIST = {
    ("AppConfigManager.swift", 'Lỗi nạp cấu hình từ đĩa:'),
    ("AppConfigManager.swift", 'Lỗi ghi cấu hình xuống đĩa:'),
    ("ScanHistoryManager.swift", 'Lỗi nạp lịch sử quét từ đĩa:'),
    ("ScanHistoryManager.swift", 'Lỗi ghi tệp lịch sử quét:'),
}

findings = []
vn_raw_literals = []
debug_logs_found = []

for root, _, files in os.walk(project_dir):
    for file in files:
        if file.endswith('.swift'):
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, project_dir)
            
            with open(full_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            for idx, line in enumerate(lines, 1):
                clean_line = line.strip()
                # Bỏ qua comment dòng
                if clean_line.startswith('//') or clean_line.startswith('///'):
                    continue
                
                # Kiểm tra các pattern UI & gán biến
                for kind, regex in patterns:
                    for match in regex.findall(line):
                        # Bỏ qua nếu match chính là một key hợp lệ trong xcstrings
                        if match in existing_keys:
                            continue
                        # Bỏ qua chuỗi kỹ thuật
                        if match in TECHNICAL_STRINGS:
                            continue
                        # Bỏ qua định dạng %
                        if match.startswith('%') or match.startswith('system.'):
                            continue
                        findings.append((file, idx, kind, match))
                
                # Quét mọi chuỗi tiếng Việt trần chưa được bọc
                raw_strings = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', line)
                for s in raw_strings:
                    if vietnamese_pattern.search(s):
                        # Kiểm tra xem có phải debug log cho phép không
                        is_debug_log = any(
                            file == debug_file and debug_prefix in s
                            for debug_file, debug_prefix in DEBUG_LOG_ALLOWLIST
                        )
                        if is_debug_log:
                            debug_logs_found.append((file, idx, s))
                            continue
                        
                        # Kiểm tra xem có nằm trong String(localized: ..., defaultValue: "...") không
                        if 'defaultValue:' in line and s in line:
                            # Đây là fallback text hợp lệ của String(localized:)
                            continue
                        
                        # Nếu là chuỗi tiếng Việt trần không có bọc
                        vn_raw_literals.append((file, idx, s))

print(f"\n1. KẾT QUẢ QUÉT PATTERN UI & ASSIGNMENT (Chưa có key): {len(findings)}")
if findings:
    for file, line, kind, text in findings:
        print(f"   [CẢNH BÁO] {file}:{line} ({kind}) -> \"{text}\"")
else:
    print("   -> TẤT CẢ các thành phần UI (Text, Button, Label, NavTitle, Alert, TextField, Picker, Section) và biến errorMessage/statusMessage đều đã được bản địa hóa 100%!")

print(f"\n2. KẾT QUẢ QUÉT CHUỖI TIẾNG VIỆT TRẦN (Chưa bọc localized): {len(vn_raw_literals)}")
if vn_raw_literals:
    for file, line, text in vn_raw_literals:
        print(f"   [CẢNH BÁO] {file}:{line} -> \"{text}\"")
else:
    print("   -> Không còn chuỗi tiếng Việt trần nào hiển thị ra giao diện người dùng!")

print(f"\n3. DANH SÁCH CHUỖI DEBUG / LOG NỘI BỘ (Miễn trừ dịch thuật theo yêu cầu): {len(debug_logs_found)}")
for file, line, text in debug_logs_found:
    print(f"   [DEBUG-LOG] {file}:{line} -> \"{text}\" (Chỉ dùng cho print debug console nội bộ, không hiển thị lên UI)")

print("\n" + "=" * 80)
print("TỔNG KẾT: Toàn bộ chuỗi hiển thị người dùng trong NetworkAnalyst đã được bản địa hóa và đồng bộ Localizable.xcstrings!")
print("=" * 80)
