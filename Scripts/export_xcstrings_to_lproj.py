#!/usr/bin/env python3
"""
export_xcstrings_to_lproj.py

MỤC ĐÍCH:
Script này dùng để chuyển đổi tệp String Catalog (Localizable.xcstrings) sang các tệp
cổ điển vi.lproj/Localizable.strings và en.lproj/Localizable.strings (và .stringsdict nếu có plural).

LƯU Ý QUAN TRỌNG:
Script này được thiết kế ĐẶC BIỆT cho quy trình build không dùng Xcode (chẳng hạn như
cross-compilation qua SwiftPM trên Linux, WSL, xtool), nơi Xcode toolchain (xcstringstool)
không có sẵn để biên dịch String Catalog tự động.

NẾU BẠN BUILD BẰNG XCODE TRÊN MACOS:
KHÔNG chạy script này hoặc KHÔNG nhúng file .strings sinh ra vào Xcode target,
vì Xcode 15+ đã tự động biên dịch Localizable.xcstrings thành .strings trong quá trình build.
Việc copy đè có thể dẫn đến xung đột hoặc trùng lặp tài nguyên (duplicate output file).
"""

import sys
import os
import json
import argparse
from typing import Dict, Any, List, Tuple

def escape_strings_value(text: str) -> str:
    r"""
    Escape ký tự đặc biệt cho định dạng tệp .strings của Apple:
    - Ký tự gạch chéo ngược: \ -> \\
    - Dấu ngoặc kép: " -> \"
    - Xuống dòng: \n -> \\n, \r -> \\n
    - Dấu tab: \t -> \\t
    Giữ nguyên các định dạng format specifier (%lld, %@, %d, %1$@, %.1f, v.v.)
    """
    if text is None:
        return ""
    # 1. Escape backslash trước tiên
    escaped = text.replace('\\', '\\\\')
    # 2. Escape double quotes
    escaped = escaped.replace('"', '\\"')
    # 3. Escape newlines
    escaped = escaped.replace('\r\n', '\\n').replace('\r', '\\n').replace('\n', '\\n')
    # 4. Escape tab
    escaped = escaped.replace('\t', '\\t')
    return escaped

def process_xcstrings(xcstrings_path: str) -> Tuple[Dict[str, Dict[str, str]], List[str], Dict[str, Any]]:
    """
    Đọc và phân tích file Localizable.xcstrings:
    - Trích xuất bản dịch từng ngôn ngữ
    - Phát hiện các key có plural / variations
    - Liệt kê các key không chuyển được (nếu có)
    """
    with open(xcstrings_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    strings_map = data.get('strings', {})
    total_keys = len(strings_map)
    print(f"[*] Đọc thành công {xcstrings_path}: tổng cộng {total_keys} keys.")

    # Kết quả: { 'vi': { key: value }, 'en': { key: value } }
    translations: Dict[str, Dict[str, str]] = {'vi': {}, 'en': {}}
    plural_keys: List[str] = []
    failed_keys: List[str] = []

    for key, item in sorted(strings_map.items()):
        localizations = item.get('localizations', {})
        
        # Kiểm tra plural / variations
        has_variation = False
        for lang in ['vi', 'en']:
            lang_data = localizations.get(lang, {})
            if 'variations' in lang_data:
                has_variation = True
                plural_keys.append(f"{key} [{lang}]")
        
        if has_variation:
            print(f"  [!] Phát hiện key có variations (plural): {key}")

        for lang in ['vi', 'en']:
            lang_data = localizations.get(lang, {})
            string_unit = lang_data.get('stringUnit', {})
            val = string_unit.get('value')
            
            if val is not None:
                translations[lang][key] = val
            else:
                # Nếu không có stringUnit, kiểm tra variation plural hoặc fallback sourceLanguage
                if 'variations' in lang_data:
                    # Tạm lấy dạng plural đầu tiên hoặc note lại
                    plural_dict = lang_data['variations'].get('plural', {})
                    fallback_val = plural_dict.get('other', {}).get('stringUnit', {}).get('value')
                    if fallback_val:
                        translations[lang][key] = fallback_val
                    else:
                        failed_keys.append(f"{key} (thiếu value trong variation {lang})")
                else:
                    failed_keys.append(f"{key} (thiếu stringUnit {lang})")

    if plural_keys:
        print(f"[!] Tổng số key có plural/variations ({len(plural_keys)}):")
        for pk in plural_keys:
            print(f"    - {pk}")
    else:
        print("[+] Không có key nào sử dụng plural/variations.")

    if failed_keys:
        print(f"[ERROR] Có {len(failed_keys)} key KHÔNG THỂ CHUYỂN ĐỔI:")
        for fk in failed_keys:
            print(f"    - {fk}")
        print("[ERROR] Không bỏ qua im lặng các key lỗi. Thoát script!")
        sys.exit(1)

    return translations, plural_keys, strings_map

def write_strings_file(out_path: str, trans_dict: Dict[str, str], lang: str):
    """
    Ghi dữ liệu sang file Localizable.strings UTF-8 chuẩn Apple
    """
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(f"/* \n  Localizable.strings ({lang})\n  Tự động sinh từ Localizable.xcstrings bởi export_xcstrings_to_lproj.py\n  KHÔNG SỬA TAY FILE NÀY\n*/\n\n")
        for key in sorted(trans_dict.keys()):
            val = trans_dict[key]
            escaped_key = escape_strings_value(key)
            escaped_val = escape_strings_value(val)
            f.write(f'"{escaped_key}" = "{escaped_val}";\n')

def verify_strings_count(xcstrings_map: Dict[str, Any], strings_file: str, lang: str):
    """
    Xác thực nghiêm ngặt sau khi ghi file:
    - Đếm số lượng entry trong .strings
    - So sánh với số key trong .xcstrings
    - Thoát lỗi exit(1) nếu số lượng bị lệch
    """
    import re
    if not os.path.exists(strings_file):
        print(f"[ERROR] File không tồn tại: {strings_file}")
        sys.exit(1)

    # Đọc lại và đếm số cặp "key" = "val";
    key_count = 0
    parsed_keys = set()
    pat = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";')

    with open(strings_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            m = pat.match(line)
            if m:
                key_count += 1
                # Unescape key để so khớp
                k = m.group(1).replace('\\"', '"').replace('\\\\', '\\')
                parsed_keys.add(k)

    expected_count = len(xcstrings_map)
    print(f"[*] Xác thực {strings_file} [{lang}]: có {key_count} keys / kỳ vọng {expected_count} keys.")

    missing_in_strings = set(xcstrings_map.keys()) - parsed_keys
    if missing_in_strings:
        print(f"[ERROR] Phát hiện {len(missing_in_strings)} keys có trong xcstrings nhưng thiếu trong {strings_file}:")
        for mk in list(missing_in_strings)[:10]:
            print(f"    - {mk}")
        sys.exit(1)

    if key_count != expected_count:
        print(f"[ERROR] LỆCH SỐ LƯỢNG KEY: .strings có {key_count} nhưng .xcstrings có {expected_count}!")
        sys.exit(1)

    print(f"[OK] Xác thực hoàn tất cho {lang}: 100% khớp {key_count}/{expected_count} keys.")

def main():
    parser = argparse.ArgumentParser(description="Chuyển Localizable.xcstrings sang .lproj/Localizable.strings")
    parser.add_argument('--xcstrings', default="NetworkAnalyst/Resources/Localizable.xcstrings", help="Đường dẫn tới Localizable.xcstrings")
    parser.add_argument('--res-dir', default="NetworkAnalyst/Resources", help="Thư mục Resources nguồn để sinh vi.lproj và en.lproj")
    parser.add_argument('--app-dirs', nargs='*', default=["build_output/NetworkAnalyst.app", "xtool/NetworkAnalyst.app"], help="Các thư mục .app đích cần inject")
    args = parser.parse_args()

    if not os.path.exists(args.xcstrings):
        print(f"[ERROR] Không tìm thấy file {args.xcstrings}")
        sys.exit(1)

    translations, _, strings_map = process_xcstrings(args.xcstrings)

    # 1. Ghi vào thư mục Resources nguồn
    for lang in ['vi', 'en']:
        out_file = os.path.join(args.res_dir, f"{lang}.lproj", "Localizable.strings")
        write_strings_file(out_file, translations[lang], lang)
        verify_strings_count(strings_map, out_file, lang)

    # 2. Inject trực tiếp vào các thư mục app bundle nếu thư mục tồn tại
    for app_dir in args.app_dirs:
        if os.path.exists(app_dir):
            print(f"[*] Đang inject .lproj vào app bundle: {app_dir}")
            for lang in ['vi', 'en']:
                dest_file = os.path.join(app_dir, f"{lang}.lproj", "Localizable.strings")
                write_strings_file(dest_file, translations[lang], lang)
                verify_strings_count(strings_map, dest_file, lang)

    print("\n[SUCCESS] Hoàn thành chuyển đổi và xác thực toàn bộ file bản dịch!")

if __name__ == '__main__':
    main()
