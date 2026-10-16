set -e
cd oo/samples/hello_world
echo "== sample root"; ls -la
MK=$(find . -maxdepth 2 -name Makefile | head -1)
if [ -z "$MK" ]; then
  echo "NO MAKEFILE FOUND"; find . -maxdepth 3 | head -60; exit 1
fi
cd "$(dirname "$MK")"
echo "BUILD DIR: $(pwd)"
make || {
  echo "BUILD FAILED, retrying without notifications"
  M=$(find . -maxdepth 3 \( -name main.cpp -o -name main.c \) | head -1)
  sed -i 's/#define USE_NOTIFY 1/#define USE_NOTIFY 0/' "$M"
  make clean || true
  make
}
GP4=$(find . -maxdepth 3 -name '*.gp4' | head -1)
echo "GP4: $GP4"
if [ -z "$GP4" ]; then
  echo "NO GP4 FOUND"; find . -maxdepth 3 | head -60; exit 1
fi
PkgTool.Core pkg_build "$GP4" .
