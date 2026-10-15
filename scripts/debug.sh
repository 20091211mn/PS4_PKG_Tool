for D in $(find oo -type d -path "*samples/SDL2"); do echo "== $D"; ls "$D" | head -30; done
cat oo/OpenOrbis/PS4Toolchain/samples/SDL2/Makefile 2>/dev/null | head -80
ls oo/OpenOrbis/PS4Toolchain/lib | head -60
ls oo/OpenOrbis/PS4Toolchain/include | head -40
