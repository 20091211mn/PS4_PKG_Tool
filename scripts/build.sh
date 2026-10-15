#!/usr/bin/env bash
set -e
COMMON=$(find "$GITHUB_WORKSPACE/oo" -name common.h -path "*include/orbis/*" | head -n 1)
echo "common.h: $COMMON"
ROOT=$(dirname "$(dirname "$(dirname "$COMMON")")")
export OO_PS4_TOOLCHAIN="$ROOT"
echo "Toolchain root: $ROOT"

IM=$(command -v magick || command -v convert)
for f in $(find "$ROOT/samples/hello_world" -name icon0.png); do
  $IM assets/icon.png -resize 512x512! PNG24:"$f"
done

cd "$ROOT/samples/hello_world"
make

mkdir -p "$GITHUB_WORKSPACE/out"
find "$ROOT/samples/hello_world" -name "*.pkg" -exec cp {} "$GITHUB_WORKSPACE/out/" \;
ls -la "$GITHUB_WORKSPACE/out"
