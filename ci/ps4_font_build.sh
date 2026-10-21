S=/tmp/summary.txt
B=/lib/OpenOrbisSDK/bin/linux
: > $S
trap 'echo "######## SUMMARY"; cat /tmp/summary.txt' EXIT
set -e
cd oo/samples/font
echo "@@ tools: $(ls $B | tr '\n' ' ')" >> $S
echo "@@ makefile tool lines: $(grep -n 'CDIR)/' Makefile | tr '\n' '|')" >> $S
if grep -q 'create-fself' Makefile && [ ! -e $B/create-fself ] && [ -e $B/create-eboot ]; then
  sed -i 's#create-fself#create-eboot#; s# --eboot "eboot.bin"##' Makefile
  echo "@@ patched create-fself -> create-eboot" >> $S
fi
make COMMONDIR=/workspace/oo/samples/_common
GP4=$(find . -maxdepth 3 -name '*.gp4' | head -1)
echo "@@ gp4: $GP4" >> $S
[ -n "$GP4" ] || { echo "NO GP4 FOUND"; find . -maxdepth 3 | head -40; exit 1; }
PkgTool.Core pkg_build "$GP4" .
echo "@@ pkgs: $(find . -name '*.pkg' | tr '\n' ' ')" >> $S
