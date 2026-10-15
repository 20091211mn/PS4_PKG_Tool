#!/usr/bin/env bash
set -e
echo "=== search orbis headers ==="
find "$GITHUB_WORKSPACE/oo" -type d -name orbis | head
find "$GITHUB_WORKSPACE/oo" -name "libkernel.h" | head

COMMON=$(find "$GITHUB_WORKSPACE/oo" -name common.h | head -n 1)
if [ -z "$COMMON" ]; then
  echo "ERROR: common.h not found anywhere in oo"
  ls -R "$GITHUB_WORKSPACE/oo" | head -80
  exit 1
fi
echo "common.h: $COMMON"
