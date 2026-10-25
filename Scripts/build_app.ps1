# Build wrapper for Network Analyst iOS (via PowerShell)
$ErrorActionPreference = "Stop"

Write-Host "=== [1/3] XUẤT VÀ KIỂM TRA BẢN DỊCH (.XCSTRINGS -> .LPROJ) ===" -ForegroundColor Cyan
python Scripts/export_xcstrings_to_lproj.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== [2/3] BIÊN DỊCH VÀ ĐÓNG GÓI ỨNG DỤNG BẰNG XTOOL (WSL) ===" -ForegroundColor Cyan
wsl -e bash -c "cd '/mnt/c/Users/Admin/OneDrive/Desktop/Network AnalystIOS' && xtool dev build --sign --ipa $args"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== [3/3] INJECT VÀ XÁC THỰC LẠI BUNDLE SAU BUILD ===" -ForegroundColor Cyan
python Scripts/export_xcstrings_to_lproj.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== BUILD VÀ BẢN ĐỊA HÓA HOÀN TẤT THÀNH CÔNG ===" -ForegroundColor Green
