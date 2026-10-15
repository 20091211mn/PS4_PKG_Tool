#!/usr/bin/env bash
set -e
WS="$GITHUB_WORKSPACE"
COMMON=$(find "$WS/oo" -name common.h -path "*orbis*" | head -n 1)
[ -z "$COMMON" ] && { echo "common.h not found"; ls -R "$WS/oo" | head -80; exit 1; }
echo "common.h: $COMMON"
ROOT=$(dirname "$(dirname "$(dirname "$COMMON")")")
export OO_PS4_TOOLCHAIN="$ROOT"
SAMPLE=$(find "$ROOT" -type d -name hello_world | head -n 1)
echo "Sample: $SAMPLE"
IM=$(command -v magick || command -v convert)
for f in $(find "$SAMPLE" -name icon0.png); do $IM "$WS/assets/icon.png" -resize 512x512! PNG24:"$f"; done
cd "$SAMPLE" && make
mkdir -p "$WS/out"
find "$ROOT" -name "*.pkg" -exec cp {} "$WS/out/" \;
ls -la "$WS/out"
