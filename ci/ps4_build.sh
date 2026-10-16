set -e
echo "== toolchain env"
echo "OO_PS4_TOOLCHAIN=$OO_PS4_TOOLCHAIN"
ls -la /lib/OpenOrbisSDK/bin 2>&1 | head -30
ls -la /lib/OpenOrbisSDK/bin/linux 2>&1 | head -30
echo "== find create-fself"
find /lib /usr /opt /home -name 'create-fself*' 2>/dev/null | head
T=/lib/OpenOrbisSDK/bin/linux/create-fself
if [ ! -e "$T" ]; then
  F=$(find /lib /usr /opt /home -name 'create-fself' -type f 2>/dev/null | head -1)
  if [ -n "$F" ]; then
    mkdir -p "$(dirname "$T")"
    ln -sf "$F" "$T"
    echo "linked $F"
  fi
fi
if [ -e "$T" ]; then
  chmod +x "$T" || true
  ldd "$T" 2>&1 | head -10 || true
  head -c 4 "$T" | od -c | head -1
fi
echo "== sample"
cd oo/samples/hello_world
ls -la
MK=$(find . -maxdepth 2 -name Makefile | head -1)
if [ -z "$MK" ]; then
  echo "NO MAKEFILE FOUND"; find . -maxdepth 3 | head -60; exit 1
fi
cd "$(dirname "$MK")"
echo "BUILD DIR: $(pwd)"
make
GP4=$(find . -maxdepth 3 -name '*.gp4' | head -1)
echo "GP4: $GP4"
if [ -z "$GP4" ]; then
  echo "NO GP4 FOUND"; find . -maxdepth 3 | head -60; exit 1
fi
PkgTool.Core pkg_build "$GP4" .
