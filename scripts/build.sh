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
export CLR_OPENSSL_VERSION_OVERRIDE=3
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
cd "$SAMPLE" && make
mkdir -p "$WS/out"
find "$SAMPLE" -name "*.pkg" -exec cp {} "$WS/out/" \;
