#!/usr/bin/env python3
"""
build_oui.py
Parses the official IEEE oui.csv file (or fallback sample_oui.csv)
and produces a compact JSON dictionary for OUIDatabase.swift.

Output locations:
  - NetworkAnalyst/Resources/oui.json
  - NetworkCore/Sources/NetworkCore/Resources/oui.json
"""

import csv
import json
import os
import sys

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    
    official_csv = os.path.join(script_dir, "data", "oui.csv")
    sample_csv = os.path.join(script_dir, "data", "sample_oui.csv")
    
    csv_to_use = official_csv
    is_sample = False
    
    if not os.path.isfile(official_csv):
        if os.path.isfile(sample_csv):
            print(f"[THÔNG BÁO] Không tìm thấy '{official_csv}'. Đang sử dụng dữ liệu mẫu '{sample_csv}' cho mục đích test.")
            csv_to_use = sample_csv
            is_sample = True
        else:
            print(f"[LỖI] Không tìm thấy '{official_csv}' hoặc '{sample_csv}'. Vui lòng đặt file oui.csv vào thư mục Scripts/data/")
            sys.exit(1)
    else:
        print(f"[XÁC NHẬN] Đang xử lý file OUI chính thức từ IEEE: {official_csv}")

    oui_dict = {}
    
    with open(csv_to_use, mode='r', encoding='utf-8', errors='ignore') as f:
        reader = csv.reader(f)
        header = next(reader, None)
        
        for row in reader:
            if not row or len(row) < 3:
                continue
            
            # Format IEEE oui.csv: Registry,Assignment,Organization Name,Organization Address
            # Example: MA-L,E043DB,Shenzhen ViewAt Technology Co., Ltd.,...
            assignment = row[1].strip().replace(":", "").replace("-", "").upper()
            org_name = row[2].strip()
            
            if len(assignment) >= 6 and org_name:
                oui_dict[assignment] = org_name

    print(f"Tổng số bản ghi OUI đã phân tích: {len(oui_dict)} mục (Nguồn: {'DỮ LIỆU MẪU' if is_sample else 'IEEE CHÍNH THỨC'}).")

    output_paths = [
        os.path.join(project_root, "NetworkAnalyst", "Resources", "oui.json"),
        os.path.join(project_root, "NetworkCore", "Sources", "NetworkCore", "Resources", "oui.json")
    ]

    for path in output_paths:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, mode='w', encoding='utf-8') as out:
            json.dump(oui_dict, out, ensure_ascii=False, indent=2)
        print(f"Đã ghi: {path}")

    if is_sample:
        print("\n[CHÚ Ý] Bạn đang dùng DỮ LIỆU MẪU. Khi có file oui.csv đầy đủ từ IEEE (https://standards-oui.ieee.org/oui/oui.csv), hãy copy vào Scripts/data/oui.csv và chạy lại script này.")

if __name__ == "__main__":
    main()
