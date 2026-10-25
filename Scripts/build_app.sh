#!/usr/bin/env bash
# Build wrapper for Network Analyst iOS (via xtool in WSL/Linux)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

echo "=== [1/3] XUẤT VÀ KIỂM TRA BẢN DỊCH (.XCSTRINGS -> .LPROJ) ==="
python3 Scripts/export_xcstrings_to_lproj.py

echo "=== [2/3] BIÊN DỊCH VÀ ĐÓNG GÓI ỨNG DỤNG BẰNG XTOOL ==="
xtool dev build --sign --ipa "$@"

echo "=== [3/3] INJECT VÀ XÁC THỰC LẠI BUNDLE SAU BUILD ==="
python3 Scripts/export_xcstrings_to_lproj.py
echo "=== BUILD VÀ BẢN ĐỊA HÓA HOÀN TẤT THÀNH CÔNG ==="
