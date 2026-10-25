#!/usr/bin/env bash
#
# Scripts/mac_first_build.sh
# Kịch bản tự động thực hiện lần build đầu tiên trên máy macOS
#

set -o pipefail

LOG_DIR="build_logs"
mkdir -p "$LOG_DIR"

echo "================================================================="
echo "   NETWORK ANALYST - KỊCH BẢN BUILD & TEST ĐẦU TIÊN TRÊN MAC   "
echo "================================================================="
echo "Thời gian bắt đầu: $(date)"
echo "Thư mục log: $LOG_DIR/"
echo ""

# -------------------------------------------------------------
# BƯỚC 0: KIỂM TRA MÔI TRƯỜNG & CÔNG CỤ CẦN THIẾT
# -------------------------------------------------------------
echo "[0/4] Kiểm tra công cụ cần thiết trên Mac..."

if ! command -v xcodebuild &> /dev/null; then
    echo "❌ LỖI: Không tìm thấy 'xcodebuild'. Vui lòng cài đặt Xcode và chạy:"
    echo "       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi
echo "  ✓ xcodebuild: $(xcodebuild -version | tr '\n' ' ')"

if ! command -v swift &> /dev/null; then
    echo "❌ LỖI: Không tìm thấy Swift toolchain."
    exit 1
fi
echo "  ✓ swift: $(swift --version | head -1)"

if ! command -v xcodegen &> /dev/null; then
    echo "⚠️ Chưa có 'xcodegen'. Đang cài đặt qua Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "❌ LỖI: Không tìm thấy Homebrew để cài xcodegen. Vui lòng cài đặt brew hoặc xcodegen thủ công."
        exit 1
    fi
fi
echo "  ✓ xcodegen: $(xcodegen --version)"

# -------------------------------------------------------------
# BƯỚC 1: SINH DỰ ÁN XCODE BẰNG XCODEGEN
# -------------------------------------------------------------
echo ""
echo "[1/4] Chạy 'xcodegen generate'..."
XCODEGEN_LOG="$LOG_DIR/01_xcodegen.log"

if xcodegen generate 2>&1 | tee "$XCODEGEN_LOG"; then
    echo "  ✓ Sinh dự án thành công: NetworkAnalyst.xcodeproj"
else
    echo "❌ LỖI ở Bước 1 (xcodegen). Vui lòng xem log chi tiết tại: $XCODEGEN_LOG"
    exit 1
fi

# -------------------------------------------------------------
# BƯỚC 2: CHẠY UNIT TEST SWIFT PACKAGE (NETWORKCORE)
# -------------------------------------------------------------
echo ""
echo "[2/4] Chạy unit test NetworkCore độc lập (swift test)..."
PACKAGE_TEST_LOG="$LOG_DIR/02_networkcore_test.log"

if swift test --package-path NetworkCore 2>&1 | tee "$PACKAGE_TEST_LOG"; then
    echo "  ✓ Toàn bộ 13 bộ test NetworkCore PASS thành công!"
else
    echo "❌ LỖI ở Bước 2 (NetworkCore swift test). Xem log chi tiết tại: $PACKAGE_TEST_LOG"
    exit 1
fi

# -------------------------------------------------------------
# TÌM SIMULATOR PHÙ HỢP CÓ SẴN (KHÔNG HARDCODE)
# -------------------------------------------------------------
echo ""
echo "Đang dò tìm iOS Simulator khả dụng trên máy..."
# Lấy UDID của một iPhone Simulator khả dụng bất kỳ
SIMULATOR_ID=$(xcrun simctl list devices available | grep -E "iPhone" | head -1 | grep -oE "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}" | head -1)

if [ -z "$SIMULATOR_ID" ]; then
    echo "⚠️ Không tìm thấy UDID iPhone simulator khả dụng, dự phòng dùng 'platform=iOS Simulator,name=iPhone 15'"
    DESTINATION="platform=iOS Simulator,name=iPhone 15"
else
    SIM_NAME=$(xcrun simctl list devices available | grep "$SIMULATOR_ID" | sed -E 's/^[ ]+//' | cut -d'(' -f1 | tr -d '\n')
    echo "  ✓ Đã chọn Simulator: $SIM_NAME (ID: $SIMULATOR_ID)"
    DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
fi

# -------------------------------------------------------------
# BƯỚC 3: BIÊN DỊCH APP TARGET CHO SIMULATOR
# -------------------------------------------------------------
echo ""
echo "[3/4] Biên dịch NetworkAnalyst app target..."
BUILD_LOG="$LOG_DIR/03_xcodebuild_build.log"

if xcodebuild clean build \
    -project NetworkAnalyst.xcodeproj \
    -scheme NetworkAnalyst \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "$BUILD_LOG"; then
    echo "  ✓ Biên dịch App Target thành công!"
else
    echo "❌ LỖI ở Bước 3 (xcodebuild build). Xem log chi tiết tại: $BUILD_LOG"
    exit 1
fi

# -------------------------------------------------------------
# BƯỚC 4: CHẠY UNIT TEST TRÊN IOS SIMULATOR
# -------------------------------------------------------------
echo ""
echo "[4/4] Chạy Unit Test suite trên iOS Simulator..."
TEST_LOG="$LOG_DIR/04_xcodebuild_test.log"

if xcodebuild test \
    -project NetworkAnalyst.xcodeproj \
    -scheme NetworkAnalystTests \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "$TEST_LOG"; then
    echo "  ✓ Toàn bộ bài kiểm thử trên iOS Simulator PASS thành công!"
else
    echo "❌ LỖI ở Bước 4 (xcodebuild test). Xem log chi tiết tại: $TEST_LOG"
    exit 1
fi

echo ""
echo "================================================================="
echo "   🎉 CHÚC MỪNG: DỰ ÁN ĐÃ BUILD VÀ TEST THÀNH CÔNG 100%!       "
echo "================================================================="
echo "Toàn bộ file log chi tiết được lưu trữ tại:"
echo "  1. $XCODEGEN_LOG"
echo "  2. $PACKAGE_TEST_LOG"
echo "  3. $BUILD_LOG"
echo "  4. $TEST_LOG"
echo "================================================================="
