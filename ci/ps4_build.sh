S=/tmp/summary.txt
B=/lib/OpenOrbisSDK/bin/linux
: > $S
trap 'echo "######## SUMMARY"; cat /tmp/summary.txt' EXIT
set -e
cd oo/samples/hello_world
echo "@@ tools: $(ls $B | tr '\n' ' ')" >> $S
echo "@@ makefile tool lines: $(grep -n 'CDIR)/' Makefile | tr '\n' '|')" >> $S
if grep -q 'create-fself' Makefile && [ ! -e $B/create-fself ] && [ -e $B/create-eboot ]; then
  sed -i 's#create-fself#create-eboot#; s# --eboot "eboot.bin"##' Makefile
  echo "@@ patched create-fself -> create-eboot" >> $S
fi
if grep -q 'create-gp4' Makefile && [ ! -e $B/create-gp4 ]; then
  echo "@@ WARNING: Makefile needs create-gp4 which is missing" >> $S
fi
make
GP4=$(find . -maxdepth 3 -name '*.gp4' | head -1)
echo "@@ gp4: $GP4" >> $S
[ -n "$GP4" ] || { echo "NO GP4 FOUND"; find . -maxdepth 3 | head -40; exit 1; }
PkgTool.Core pkg_build "$GP4" .
echo "@@ pkgs: $(find . -name '*.pkg' | tr '\n' ' ')" >> $S
(
  set -e
  cd ../hello_ui
  if grep -q 'create-fself' Makefile && [ ! -e $B/create-fself ] && [ -e $B/create-eboot ]; then
    sed -i 's#create-fself#create-eboot#; s# --eboot "eboot.bin"##' Makefile
  fi
  make
  GP4=$(find . -maxdepth 3 -name '*.gp4' | head -1)
  PkgTool.Core pkg_build "$GP4" .
) > /tmp/ui_build.log 2>&1 && echo "@@ ui build: OK" >> $S || { echo "@@ ui build: FAILED" >> $S; tail -n 20 /tmp/ui_build.log | sed 's/^/@@ ui: /' >> $S; }
(
  set -e
  cd ../hello_ui
  make
  GP4=$(find . -maxdepth 3 -name '*.gp4' | head -1)
  PkgTool.Core pkg_build "$GP4" .
) > /tmp/ui_build.log 2>&1 && echo "@@ ui build: OK" >> $S || { echo "@@ ui build: FAILED" >> $S; tail -n 20 /tmp/ui_build.log | sed 's/^/@@ ui: /' >> $S; }
(
  set -e
  cd ../hello_ui
  make
  GP4=$(find . -maxdepth 3 -name '*.gp4' | head -1)
  PkgTool.Core pkg_build "$GP4" .
) > /tmp/ui_build.log 2>&1 && echo "@@ ui build: OK" >> $S || { echo "@@ ui build: FAILED" >> $S; tail -n 20 /tmp/ui_build.log | sed 's/^/@@ ui: /' >> $S; }
