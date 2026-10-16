#!/usr/bin/env bash
set -e

export OO_PS4_TOOLCHAIN="$(pwd)/oo"
export PATH="$OO_PS4_TOOLCHAIN/bin:$PATH"

echo "Building OpenOrbis sample with isolated headers..."
cd oo/samples/hello_world

make clean || true

# إضافة خيار لتجاهل ترويسات النظام المضيف وضبط الـ CXXFLAGS لمنع الانحراف إلى /usr/include
export CXXFLAGS="-nostdinc -isystem $OO_PS4_TOOLCHAIN/include -isystem $OO_PS4_TOOLCHAIN/include/c++/v1"
export CFLAGS="-nostdinc -isystem $OO_PS4_TOOLCHAIN/include"

make OO_PS4_TOOLCHAIN="$OO_PS4_TOOLCHAIN" || {
  echo "BUILD FAILED, retrying without notifications"
  M=$(find . -maxdepth 2 \( -name main.cpp -o -name main.c \) | head -1)
  if [ -n "$M" ]; then
    sed -i 's/#define USE_NOTIFY 1/#define USE_NOTIFY 0/' "$M"
  fi
  make clean || true
  make OO_PS4_TOOLCHAIN="$OO_PS4_TOOLCHAIN"
}
