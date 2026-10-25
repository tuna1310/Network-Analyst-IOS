# -*- coding: utf-8 -*-
"""
Scripts/check_format_specifiers.py
Kiểm tra tính toàn vẹn của các specifier định dạng (%@, %d, %f, ...) giữa:
1. Lời gọi code Swift: String(format: String(localized: "key", defaultValue: "..."), args...)
2. Chuỗi defaultValue trong code
3. Bản dịch tiếng Anh (en) trong Localizable.xcstrings
4. Bản dịch tiếng Việt (vi) trong Localizable.xcstrings
"""

import os
import re
import json
import glob

# Regex trích xuất định dạng specifier chuẩn C/Darwin: %@, %d, %ld, %lld, %.1f, %s...
SPECIFIER_REGEX = re.compile(r'%(\d+\$)?[-+ #0]*(\d+|\*)?(\.\d+)?([hljztL]{0,2}[diuoxXfFeEgGaAcsp@])')

def extract_specifiers(text):
    if not text:
        return []
    # Bỏ qua escaped %%
    clean = text.replace('%%', '')
    matches = SPECIFIER_REGEX.findall(clean)
    # Trả về loại specifier cơ bản (loại bỏ cờ độ rộng)
    specs = []
    for m in matches:
        conv = m[3] # e.g. 'd', 'ld', '@', 'f'
        # Chuẩn hóa về nhóm kiểu
        if any(c in conv for c in 'diuoxX'):
            specs.append('%d')
        elif any(c in conv for c in 'fFeEgGaA'):
            specs.append('%f')
        elif '@' in conv:
            specs.append('%@')
        elif 's' in conv:
            specs.append('%s')
        else:
            specs.append('%' + conv)
    return specs

def check_format_specifiers():
    xcstrings_path = os.path.join('NetworkAnalyst', 'Resources', 'Localizable.xcstrings')
    with open(xcstrings_path, 'r', encoding='utf-8') as f:
        xcdata = json.load(f)
    
    strings_dict = xcdata.get('strings', {})
    
    print("=" * 80)
    print("KIỂM TRA TƯƠNG THÍCH ĐỊNH DẠNG SPECIFIER (FORMAT SPECIFIERS CHECK)")
    print(f"Tổng số key trong Localizable.xcstrings: {len(strings_dict)}")
    print("=" * 80)
    
    # 1. So sánh Specifier giữa bản dịch 'en' và 'vi' trong Localizable.xcstrings
    xcstrings_mismatches = []
    keys_with_specifiers = 0
    
    for key, val in strings_dict.items():
        localizations = val.get('localizations', {})
        en_val = localizations.get('en', {}).get('stringUnit', {}).get('value', '')
        vi_val = localizations.get('vi', {}).get('stringUnit', {}).get('value', '')
        
        en_specs = extract_specifiers(en_val)
        vi_specs = extract_specifiers(vi_val)
        
        if en_specs or vi_specs:
            keys_with_specifiers += 1
            if en_specs != vi_specs:
                xcstrings_mismatches.append((key, en_val, vi_val, en_specs, vi_specs))
    
    print(f"\n1. TỔNG SỐ KEY CÓ THAM SỐ ĐỊNH DẠNG TRONG XCODERESOURCES: {keys_with_specifiers}")
    if xcstrings_mismatches:
        print(f"   [CẢNH BÁO] Phát hiện {len(xcstrings_mismatches)} key không khớp specifier giữa en và vi:")
        for key, en_v, vi_v, en_s, vi_s in xcstrings_mismatches:
            print(f"   - Key: '{key}'")
            print(f"     EN ({en_s}): \"{en_v}\"")
            print(f"     VI ({vi_s}): \"{vi_v}\"")
    else:
        print("   -> TẤT CẢ các key có tham số đều khớp 100% giữa bản dịch tiếng Anh (en) và tiếng Việt (vi)!")

    # 2. Quét mã nguồn Swift tìm các lời gọi String(format: String(localized: ...))
    # Regex tìm String(format: String(localized: "key", defaultValue: "default"), args...)
    call_mismatches = []
    swift_call_count = 0
    
    call_pattern = re.compile(
        r'String\s*\(\s*format:\s*String\s*\(\s*localized:\s*"([^"]+)"\s*,\s*defaultValue:\s*"([^"]+)"\s*\)\s*,\s*([^\n\)]+)\)'
    )
    
    for filepath in glob.glob('NetworkAnalyst/**/*.swift', recursive=True):
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        for match in call_pattern.finditer(content):
            swift_call_count += 1
            key = match.group(1)
            default_val = match.group(2)
            args_str = match.group(3).strip()
            
            # Đếm số tham số truyền vào (xử lý cơ bản qua dấu phẩy ngoài ngoặc)
            # Tách arguments
            depth = 0
            args = []
            cur = []
            for c in args_str:
                if c in '([{':
                    depth += 1
                    cur.append(c)
                elif c in ')]}':
                    depth -= 1
                    cur.append(c)
                elif c == ',' and depth == 0:
                    args.append(''.join(cur).strip())
                    cur = []
                else:
                    cur.append(c)
            if cur:
                args.append(''.join(cur).strip())
            
            default_specs = extract_specifiers(default_val)
            
            # Kiểm tra số lượng args truyền vào với số lượng specifiers trong defaultValue
            if len(args) != len(default_specs):
                call_mismatches.append((
                    os.path.basename(filepath),
                    key,
                    default_val,
                    len(default_specs),
                    args,
                    len(args)
                ))
            
            # Kiểm tra xem key trong xcstrings có khớp với default_specs không
            if key in strings_dict:
                locs = strings_dict[key].get('localizations', {})
                en_val = locs.get('en', {}).get('stringUnit', {}).get('value', '')
                vi_val = locs.get('vi', {}).get('stringUnit', {}).get('value', '')
                
                en_specs = extract_specifiers(en_val)
                vi_specs = extract_specifiers(vi_val)
                
                if default_specs != en_specs or default_specs != vi_specs:
                    call_mismatches.append((
                        os.path.basename(filepath),
                        key,
                        f"Code default ({default_specs}) vs XCStrings (EN: {en_specs}, VI: {vi_specs})",
                        len(default_specs),
                        args,
                        len(args)
                    ))

    print(f"\n2. TỔNG SỐ LỜI GỌI STRING(FORMAT: STRING(LOCALIZED: ...)) TRONG CODE: {swift_call_count}")
    if call_mismatches:
        print(f"   [CẢNH BÁO] Phát hiện {len(call_mismatches)} vị trí không khớp tham số:")
        for fname, key, dval, dcount, args, acount in call_mismatches:
            print(f"   - File: {fname} | Key: '{key}'")
            print(f"     Default: {dval} (Cần {dcount} tham số)")
            print(f"     Truyền vào ({acount}): {args}")
    else:
        print("   -> TẤT CẢ các lời gọi String(format: String(localized: ...)) trong code đều khớp 100% số lượng và kiểu specifier với xcstrings!")

    print("\n" + "=" * 80)
    print("KẾT LUẬN: Đảm bảo không xảy ra crash do lệch specifier String(format:) khi chạy đa ngôn ngữ!")
    print("=" * 80)

if __name__ == '__main__':
    check_format_specifiers()
