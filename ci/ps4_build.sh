#!/usr/bin/env bash
set -e

export OO_PS4_TOOLCHAIN="$(pwd)/oo"
export _OO_PS4_TOOLCHAIN="$(pwd)/oo"
export PATH="$OO_PS4_TOOLCHAIN/bin:$PATH"

echo "Building OpenOrbis sample..."
cd oo/samples/hello_world

make || {
  echo "BUILD FAILED, retrying without notifications"
  M=$(find . -maxdepth 2 \( -name main.cpp -o -name main.c \) | head -1)
  sed -i 's/#define USE_NOTIFY 1/#define USE_NOTIFY 0/' "$M"
  make clean || true
  make
}
