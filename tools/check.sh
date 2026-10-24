#!/bin/bash
# The local gate: run it from anywhere before opening a PR; it exits non-zero on any failure.
# usage: tools/check.sh
#   1. doctor: the Godot on the PATH and its version
#   2. import, to build the .godot/ cache
#   3. the unit suite, failing on any SCRIPT ERROR even when it reports no FAIL
#   4. a headless smoke of the main scene (3600 frames), failing on any SCRIPT ERROR or ERROR: line
# macOS has no `timeout`, so every step runs under a perl alarm (exit 142 means it timed out).
# There is no local web export: CI (Godot 4.5.1) is the only web-export authority, so check the
# web build from the PR's CI artifact.
set -u
cd "$(dirname "$0")/.." || exit 1
LOGS=$(mktemp -d "${TMPDIR:-/tmp/}frostmark-check.XXXXXX")
CI_GODOT=4.5.1

limit() {
  local secs=$1
  shift
  perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]: $!\n"' "$secs" "$@"
}

fail() {
  echo "check: FAIL: $1 (logs in $LOGS)" >&2
  exit 1
}

echo "== doctor"
command -v godot >/dev/null || fail "godot is not on the PATH"
version=$(limit 30 godot --headless --version 2>/dev/null | tail -n 1)
echo "godot $version at $(command -v godot)"
case $version in
  "$CI_GODOT".stable.*) ;;
  *) echo "CI runs Godot $CI_GODOT; unit tests and the smoke match it, but the web build differs." ;;
esac
echo "No local web export: for the web check, use the CI artifact (gh run download <run> -n frostmark-web)."

echo "== import"
limit 300 godot --headless --import >"$LOGS/import.log" 2>&1 || fail "import exited $?"

echo "== unit tests"
limit 120 godot --headless -s tests/run.gd >"$LOGS/unit.log" 2>&1
rc=$?
grep -E '^(FAIL|PASS) ' "$LOGS/unit.log"
[ "$rc" -eq 142 ] && fail "the unit suite timed out after 120 s, in $(grep '^RUN ' "$LOGS/unit.log" | tail -n 1)"
[ "$rc" -eq 0 ] || fail "the unit suite exited $rc"
if grep -n -A1 'SCRIPT ERROR' "$LOGS/unit.log"; then
  fail "the unit suite logged a SCRIPT ERROR"
fi

echo "== smoke"
limit 180 godot --headless --quit-after 3600 >"$LOGS/smoke.log" 2>&1
rc=$?
[ "$rc" -eq 0 ] || fail "the smoke run exited $rc"
if grep -E 'SCRIPT ERROR|ERROR:' "$LOGS/smoke.log"; then
  fail "the main scene logged errors"
fi

echo "check: OK"
rm -rf "$LOGS"
