#!/usr/bin/env bash
set -e
mkdir -p oo
URL=$(curl -s https://api.github.com/repos/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/latest | grep browser_download_url | grep -i linux | head -n 1 | cut -d '"' -f 4)
echo "Downloading: $URL"
curl -L -o toolchain.tar.gz "$URL"
tar -xzf toolchain.tar.gz -C oo
ls oo
