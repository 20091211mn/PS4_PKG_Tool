S=/tmp/summary.txt
B=/lib/OpenOrbisSDK/bin/linux
: > $S
trap 'echo "######## SUMMARY"; cat /tmp/summary.txt' EXIT

cd oo/samples/font || exit 1
echo "@@ tools: $(ls $B | tr '\n' ' ')" >> $S
cp Makefile /tmp/Makefile.orig
cp font/main.cpp /tmp/main.merged

try() {
  cp /tmp/Makefile.orig Makefile
  { printf '%s' "$2"; cat /tmp/main.merged; } > font/main.cpp
  if [ -n "$3" ]; then sed -i "/^LIBS/ s/\$/ $3/" Makefile; fi
  make clean > /dev/null 2>&1 || true
  if make COMMONDIR=/workspace/oo/samples/_common > /tmp/mk_$1.log 2>&1; then
    echo "@@ variant $1: BUILD OK" >> $S
    return 0
  fi
  echo "@@ variant $1: FAILED" >> $S
  grep -n 'error:\|undefined' /tmp/mk_$1.log | head -12 | sed 's/^/@@ /' >> $S
  return 1
}

PADLIBS="-lScePad -lSceUserService"
try full "" "$PADLIBS" \
 || try nogd "#define PS4UI_NOGD
" "$PADLIBS" \
 || try noft "#define PS4UI_NOGD
#define PS4UI_NOFT
" "$PADLIBS" \
 || try nopad "#define PS4UI_NOGD
#define PS4UI_NOFT
#define PS4UI_NOPAD
" "" \
 || try nodir "#define PS4UI_NOGD
#define PS4UI_NOFT
#define PS4UI_NOPAD
#define PS4UI_NODIR
" "" \
 || exit 1

GP4=$(find . -maxdepth 3 -name '*.gp4' | head -1)
echo "@@ gp4: $GP4" >> $S
[ -n "$GP4" ] || { echo "NO GP4 FOUND"; exit 1; }
if ! PkgTool.Core pkg_build "$GP4" . > /tmp/pkg.log 2>&1; then
  echo "@@ PKGTOOL FAILED" >> $S
  head -n 25 /tmp/pkg.log | sed 's/^/@@ /' >> $S
  exit 1
fi
echo "@@ pkgs: $(find . -name '*.pkg' | tr '\n' ' ')" >> $S
