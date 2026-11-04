#!/bin/sh
# One-shot: removes obsolete PS4 build files, keeps everything the remaining workflows use, commits and pushes.
cd "$(dirname "$0")/.." || exit 1
git rev-parse --show-toplevel > /dev/null 2>&1 || { echo "not a git repo"; exit 1; }

git tag -f before-ps4-cleanup > /dev/null 2>&1 || true
KEEP_WF=".github/workflows/build-official.yml .github/workflows/build-dev.yml .github/workflows/build_ios.yml .github/workflows/build-ps4.yml"

CANDIDATES=".github/workflows/build.yml
.github/workflows/build-ps4-app.yml
.github/workflows/build-ps4-splitter.yml
.github/workflows/build-ps4-font.yml
.github/workflows/build-ps4-ui.yml
.github/workflows/build-ps4-ui2.yml
ci/ps4_build.sh
ci/ps4_font_build.sh
ci/ps4_ui_build.sh
ci/ps4_ui2_build.sh
ci/prepare_android.sh
app/main.cpp
app/main_v2.cpp
app/main_ui.cpp
app/main_ui2.cpp
buildozer.spec
repomix-output.xml
auto_deploy.sh
clean_logs.sh
add_github_release.sh
rebuild_android_and_workflows.sh
update_and_push.sh
update_full_app.sh"
for f in fix_*.sh; do [ -e "$f" ] && CANDIDATES="$CANDIDATES
$f"; done

removed=0; kept=0
echo "$CANDIDATES" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -e "$f" ] || continue
  used=""
  for w in $KEEP_WF; do
    [ -f "$w" ] && grep -qF "$f" "$w" && used="$w"
  done
  if [ -n "$used" ]; then
    echo "KEPT   $f  (used by $used)"
  else
    git rm -q -f --ignore-unmatch -- "$f" 2> /dev/null || rm -f "$f"
    echo "REMOVED $f"
  fi
done

git add app/main_ui3.cpp ci/make_ui_main.py ci/ps4_app_build.sh .github/workflows/build-ps4.yml tools/setup.sh
if git diff --cached --quiet; then
  echo "nothing to commit"
else
  git commit -q -m "PS4 app: UI v3 build, remove obsolete build files"
  echo "committed"
fi
if [ -n "$NOPUSH" ]; then echo "NOPUSH set - skipping push"; exit 0; fi
git pull --rebase origin main && git push origin main
echo "SETUP DONE"
