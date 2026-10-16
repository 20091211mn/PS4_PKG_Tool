#!/usr/bin/env bash
set -e

export OO_PS4_TOOLCHAIN="$(pwd)/oo"
export PATH="$OO_PS4_TOOLCHAIN/bin:$PATH"

D="oo/samples/hello_world"
cd "$D"

echo "Replacing source code with our Splitter app..."
M="hello_world/main.cpp"
if [ ! -f "$M" ]; then
  M=$(find . -maxdepth 3 \( -name main.cpp -o -name main.c \) | head -1)
fi
cp ../../../app/main_v2.cpp "$M"

# تحديث الأيقونة إذا توفرت
IM=$(command -v magick || command -v convert)
for f in $(find . -name icon0.png); do
  if [ -f "../../../assets/icon.png" ]; then
    $IM ../../../assets/icon.png -resize 512x512! PNG24:$f
  fi
done

echo "Compiling directly with OpenOrbis Clang..."
# استخدام مسارات ترويسات OpenOrbis الصريحة وتجنب ترويسات لينكس تماماً
TARGET_INC="$OO_PS4_TOOLCHAIN/include"
CLANG="$OO_PS4_TOOLCHAIN/bin/clang++"

if [ ! -f "$CLANG" ]; then
  CLANG="clang++"
fi

# ترجمة الكود البرمجي مباشرة إلى ملف كائنات (Object file)
$CLANG --target=x86_64-pc-freebsd12-elf -fPIC -funwind-tables -c \
  -nostdinc \
  -isystem "$TARGET_INC" \
  -isystem "$TARGET_INC/c++/v1" \
  "$M" -o main.o

# ربط الملفات وإنشاء eboot.bin
echo "Linking eboot.bin..."
# استخدام أداة الـ linker أو الـ makefile المخصص للارتباط إذا توفرت، أو بناء الـ pkg مباشرة
if [ -f "pkg/pkg.gp4" ]; then
  # بناء الحزمة باستخدام PkgTool إذا كانت متوفرة
  if command -v PkgTool.Core &> /dev/null; then
    PkgTool.Core pkg_build pkg/pkg.gp4 .
  else
    echo "Trying standard make package target..."
    make package || make || true
  fi
else
  make || true
fi
