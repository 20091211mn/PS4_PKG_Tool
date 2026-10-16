#!/usr/bin/env bash
set -e

export OO_PS4_TOOLCHAIN="$(pwd)/oo"
export PATH="$OO_PS4_TOOLCHAIN/bin:$PATH"

# تضمين بيئة العمل إذا توفرت
if [ -f "$OO_PS4_TOOLCHAIN/env.sh" ]; then
  source "$OO_PS4_TOOLCHAIN/env.sh"
fi

echo "Building OpenOrbis sample..."
cd oo/samples/hello_world

make clean || true

make OO_PS4_TOOLCHAIN="$OO_PS4_TOOLCHAIN" || {
  echo "BUILD FAILED, retrying without notifications"
  M=$(find . -maxdepth 2 \( -name main.cpp -o -name main.c \) | head -1)
  if [ -n "$M" ]; then
    sed -i 's/#define USE_NOTIFY 1/#define USE_NOTIFY 0/' "$M"
  fi
  make clean || true
  make OO_PS4_TOOLCHAIN="$OO_PS4_TOOLCHAIN"
}
