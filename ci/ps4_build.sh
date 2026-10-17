S=/tmp/summary.txt
T=/lib/OpenOrbisSDK/bin/linux/create-fself
if [ ! -e "$T" ]; then
  F=$(find / -name 'create-fself' -type f -not -path '/proc/*' 2>/dev/null | head -1)
  if [ -n "$F" ]; then
    mkdir -p "$(dirname "$T")"
    ln -sf "$F" "$T"
  fi
fi
[ -e "$T" ] && chmod +x "$T"
{
  echo "@@ arch: $(uname -m)"
  echo "@@ expected path exists: $( [ -e "$T" ] && echo YES || echo NO )"
  echo "@@ found: $(find / -name 'create-fself*' -not -path '/proc/*' 2>/dev/null | head -3 | tr '\n' ' ')"
  echo "@@ bin/linux: $(ls /lib/OpenOrbisSDK/bin/linux 2>&1 | tr '\n' ' ')"
  echo "@@ ldd missing: $(ldd "$T" 2>&1 | grep -i 'not found' | tr '\n' ' ')"
  echo "@@ file head: $(head -c 4 "$T" 2>/dev/null | od -An -c)"
} > $S 2>&1
trap 'echo "######## SUMMARY"; cat /tmp/summary.txt' EXIT
set -e
cd oo/samples/hello_world
echo "@@ makefile line 77: $(sed -n '77p' Makefile)" >> $S
make
GP4=$(find . -maxdepth 3 -name '*.gp4' | head -1)
echo "GP4: $GP4"
[ -n "$GP4" ] || { echo "NO GP4 FOUND"; find . -maxdepth 3 | head -40; exit 1; }
PkgTool.Core pkg_build "$GP4" .
