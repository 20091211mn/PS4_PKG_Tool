#!/usr/bin/env bash
set -e
mkdir -p oo
U=https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/download/v0.5.4/toolchain-llvm-18.tar.gz
curl -L -o toolchain.tar.gz "$U"
tar -xzf toolchain.tar.gz -C oo
ls oo
S=https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/download/v0.5.3/samples-pkg-llvm-18.zip
curl -L -o samples.zip "$S"
mkdir -p oo/samples && unzip -q samples.zip -d oo/samples
S=https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/download/v0.5.3/samples-pkg-llvm-18.zip
curl -L -o samples.zip "$S"
mkdir -p oo/samples && unzip -q samples.zip -d oo/samples
find oo -maxdepth 3 -type d | head -40
