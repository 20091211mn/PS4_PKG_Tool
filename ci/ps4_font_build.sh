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
if ! PkgTool.Core pkg_build "$GP4" . > /tmp/pkg.log 2>&1; then
  echo "@@ PKGTOOL FAILED (first lines):" >> $S
  head -n 25 /tmp/pkg.log | sed 's/^/@@ /' >> $S
  GD=$(dirname "$GP4")
  grep -o 'orig_path="[^"]*"' "$GP4" | sed 's/orig_path="//; s/"$//' | while read p; do
    if [ ! -e "$p" ] && [ ! -e "$GD/$p" ]; then echo "@@ MISSING FILE: $p" >> $S; fi
  done
  exit 1
fi
echo "@@ pkgs: $(find . -name '*.pkg' | tr '\n' ' ')" >> $S
