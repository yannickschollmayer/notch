#!/bin/bash
# Writes the current build state to the ci-status branch so it can be read without a login.
# Usage: ci/report.sh <status>
set -u
STATUS="$1"
LOG="${LOG:-$GITHUB_WORKSPACE/build.log}"
DIR="$RUNNER_TEMP/status"
rm -rf "$DIR" && mkdir -p "$DIR" && cd "$DIR" || exit 0
git init -q -b ci-status
{
  echo "run: $GITHUB_RUN_NUMBER"
  echo "commit: $GITHUB_SHA"
  echo "status: $STATUS"
  echo "url: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
  echo "time: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > status.txt
if [ -f "$LOG" ]; then
  grep -nE "error:|: warning: .*(NotchIsland|FourFingerTap|RecorderUIManager|LanguageDictionary)|\*\* BUILD|fatal:|Patch failed|does not apply" "$LOG" | head -250 > errors.txt || true
  tail -n 150 "$LOG" > tail.txt
fi
git add -A
git -c user.name="ci" -c user.email="ci@users.noreply.github.com" commit -qm "Build $GITHUB_RUN_NUMBER: $STATUS"
git push -q -f "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" ci-status || true
