#!/bin/bash
REPO="20091211mn/PS4_PKG_Tool"
echo "جاري مسح سجلات GitHub..."
gh run list --repo "$REPO" --limit 1000 --json databaseId -q '.[].databaseId' | xargs -I {} gh run delete {} --repo "$REPO"
echo "تم الحذف بنجاح!"
