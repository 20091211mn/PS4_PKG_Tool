#!/usr/bin/env bash
set -e
mkdir -p oo
API=https://api.github.com/repos/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/latest
curl -s "$API" > release.json
cat release.json | grep -E "tag_name|browser_download_url" || true

URL=$(grep browser_download_url release.json | grep -iE "linux|\.tar\.gz|\.zip" | head -n 1 | cut -d '"' -f 4)

if [ -z "$URL" ]; then
  echo "No release asset found, falling back to git clone"
  git clone --recursive --depth 1 https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain.git oo/src
  exit 0
fi

echo "Downloading: $URL"
curl -L -o toolchain_file "$URL"
case "$URL" in
  *.zip) unzip -q toolchain_file -d oo ;;
  *) tar -xf toolchain_file -C oo ;;
esac
ls oo
