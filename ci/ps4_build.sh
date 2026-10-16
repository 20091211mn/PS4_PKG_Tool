#!/usr/bin/env bash
set -e

export OO_PS4_TOOLCHAIN="$(pwd)/oo"
export PATH="$OO_PS4_TOOLCHAIN/bin:$PATH"

echo "Building OpenOrbis sample..."
cd oo/samples/hello_world

# تنظيف البناء السابق
make clean || true

# تعديل الـ Makefile الداخلي إذا وجد فراغ في مسارات الـ include لمنع خطأ لينكس
if [ -f "Makefile" ]; then
  sed -i 's|-isystem / include|-isystem $(OO_PS4_TOOLCHAIN)/include|g' Makefile || true
fi

make OO_PS4_TOOLCHAIN="$OO_PS4_TOOLCHAIN" || {
  echo "BUILD FAILED, retrying without notifications"
  M=$(find . -maxdepth 2 \( -name main.cpp -o -name main.c \) | head -1)
  if [ -n "$M" ]; then
    sed -i 's/#define USE_NOTIFY 1/#define USE_NOTIFY 0/' "$M"
  fi
  make clean || true
  make OO_PS4_TOOLCHAIN="$OO_PS4_TOOLCHAIN"
}
