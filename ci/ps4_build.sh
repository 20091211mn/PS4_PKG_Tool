#!/usr/bin/env bash
set -e

# ضبط مسارات بيئة OpenOrbis Toolchain رسمياً
export OO_PS4_TOOLCHAIN="$(pwd)/oo"
export PATH="$OO_PS4_TOOLCHAIN/bin:$PATH"

echo "Building OpenOrbis sample with proper environment..."
cd oo/samples/hello_world

# تنظيف أي ملفات بناء سابقة قد تحتوي على إعدادات خاطئة
make clean || true

# تنفيذ البناء مع تمرير مسار الـ Toolchain صراحةً ليتجنب الاعتماد على ملفات لينكس المضيفة
make OO_PS4_TOOLCHAIN="$OO_PS4_TOOLCHAIN" || {
  echo "BUILD FAILED, retrying without notifications"
  M=$(find . -maxdepth 2 \( -name main.cpp -o -name main.c \) | head -1)
  if [ -n "$M" ]; then
    sed -i 's/#define USE_NOTIFY 1/#define USE_NOTIFY 0/' "$M"
  fi
  make clean || true
  make OO_PS4_TOOLCHAIN="$OO_PS4_TOOLCHAIN"
}
