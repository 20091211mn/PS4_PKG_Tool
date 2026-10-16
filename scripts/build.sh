#!/usr/bin/env bash
set -e
WS="$GITHUB_WORKSPACE"
ROOT="$WS/oo/OpenOrbis/PS4Toolchain"
export OO_PS4_TOOLCHAIN="$ROOT"
chmod +x "$ROOT"/bin/linux/*
B="$WS/build/SDL2"
rm -rf "$WS/build"; mkdir -p "$WS/build"
cp -r "$ROOT/samples/SDL2" "$B"
rm -f "$B"/SDL2/*.cpp "$B"/SDL2/*.h
cp "$WS/ps4ui/main.cpp" "$B/SDL2/main.cpp"
sed -i "s/^TITLE .*/TITLE       := Split Merge/; s/^TITLE_ID .*/TITLE_ID    := SPLT00001/; s/^CONTENT_ID .*/CONTENT_ID  := IV0000-SPLT00001_00-SPLITMERGE000000/" "$B/Makefile"
IM=$(command -v magick || command -v convert)
$IM "$WS/assets/icon.png" -resize 512x512! PNG24:"$B/sce_sys/icon0.png"
wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
cd "$B" && make
mkdir -p "$WS/out"
find "$B" -maxdepth 1 -name "*.pkg" -exec cp {} "$WS/out/" \;
ls -lh "$WS/out"
E=$(find "$B" -name eboot.bin | head -1)
echo "marker store.txt: $(grep -c -a 'store.txt' "$E" || true)"
