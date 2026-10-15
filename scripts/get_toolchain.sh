#!/usr/bin/env bash
set -e
mkdir -p oo
U=https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/download/v0.5.3/toolchain-llvm-18.2.zip
curl -L -o toolchain.zip "$U"
unzip -o -q toolchain.zip -d oo
S=https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/download/v0.5.3/samples-pkg-llvm-18.zip
curl -L -o samples.zip "$S"
mkdir -p oo/samples && unzip -o -q samples.zip -d oo/samples
