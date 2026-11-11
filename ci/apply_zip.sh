#!/bin/bash
# Applies the newest ps4_vN.zip from the repo root. With "commit" it also writes the files into the
# repository so the Android / iOS workflows (which read the repository) pick them up.
Z=$(ls ps4_v*.zip 2>/dev/null | sort -V | tail -1 || true)
if [ -z "$Z" ]; then echo "No update zip - using the sources already in the repository"; exit 0; fi
LAST=$(cat .applied_zip 2>/dev/null || true)
if [ "$Z" = "$LAST" ]; then echo "$Z was already applied to the repository"; exit 0; fi
echo "Applying $Z"
PY=$(command -v python3 || command -v python)
"$PY" - "$Z" << 'PYEOF'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for m in z.namelist():
    if m.startswith('.github/') or m.endswith('/'):
        continue
    z.extract(m, '.')
    print('  extracted', m)
PYEOF
echo "$Z" > .applied_zip
if [ "$1" = "commit" ]; then
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git add -A -- app ci pc lib .applied_zip 2>/dev/null
  if git diff --cached --quiet; then
    echo "repository already has these sources"
  else
    git commit -q -m "Apply $Z" && (git push || echo "push failed - the build continues with the unpacked files")
  fi
fi
