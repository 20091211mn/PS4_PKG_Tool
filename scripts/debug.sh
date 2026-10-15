#!/usr/bin/env bash
echo "=== release assets ==="
grep -E "tag_name|browser_download_url" release.json || true
echo "=== top of oo ==="
ls -la oo
echo "=== depth 2 ==="
find oo -maxdepth 2 | head -50
echo "=== any orbis dirs ==="
find oo -type d -name orbis | head
echo "=== any common.h ==="
find oo -name common.h | head
