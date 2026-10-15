#!/usr/bin/env bash
set -e
WS="$GITHUB_WORKSPACE"
ROOT="$WS/oo/OpenOrbis/PS4Toolchain"
export OO_PS4_TOOLCHAIN="$ROOT"
chmod +x "$ROOT"/bin/linux/*
ls "$ROOT/include" | head -30
ls "$ROOT/samples"
SAMPLE="$ROOT/samples/hello_world"
IM=$(command -v magick || command -v convert)
for f in $(find "$SAMPLE" -name icon0.png); do $IM "$WS/assets/icon.png" -resize 512x512! PNG24:"$f"; done
wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
for f in $(find "$SAMPLE" -name main.cpp); do cp "$WS/app/main.cpp" "$f"; done
cd "$SAMPLE" && make
mkdir -p "$WS/out"
find "$SAMPLE" -name "*.pkg" -exec cp {} "$WS/out/" \;
ls -lh "$WS/out"
find "$SAMPLE" -name eboot.bin -exec ls -l {} \;
md5sum "$WS/app/main.cpp"
