#!/bin/bash
# Runs feature probes on a copy of the current checkout (uncommitted changes included) and keeps
# what they printed as evidence.
# usage: .claude/skills/verify-frostmark/scripts/probe.sh <probe.gd>...
#
# It copies every tracked and untracked-but-not-ignored file to a temp folder outside any repo,
# imports that copy once (a second try if the import stops partway, as drive.sh does), then for
# each probe: lints it with tools/verify/lint.gd, runs it under a 60 s perl alarm and prints its
# PROBE lines and errors. The copy is deleted on exit; the evidence is not.
#
# Evidence goes to $FROSTMARK_VERIFY_HOME/features/<UTC stamp>-<sha7>[-dirty]/:
#   tree.txt      the commit, `git status --porcelain` and the sha256 of `git diff HEAD`
#   <probe>.gd    the probe as run
#   <probe>.log   its full output; <probe>.rc its exit code (142 is the alarm)
#   summary.txt   one line per probe: PASS, FAIL or ERROR, and the PROBE lines
#
#   FROSTMARK_VERIFY_HOME  default ${TMPDIR:-/tmp/}frostmark-verify-home, as tools/verify/run.sh
#   VERIFY_PROBE_SECS      the alarm on each probe run (default 60)
#
# Exits 0 when every probe ran, printed at least one PROBE line and passed every one; 1 otherwise.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(git -C "$HERE" rev-parse --show-toplevel) || exit 1
SECS=${VERIFY_PROBE_SECS:-60}
HOME_DIR=${FROSTMARK_VERIFY_HOME:-${TMPDIR:-/tmp/}frostmark-verify-home}

fail() {
  echo "probe: $1" >&2
  exit 1
}

limit() {
  perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]: $!\n"' "$@"
}

[ $# -ge 1 ] || fail "usage: probe.sh <probe.gd>..."
for p in "$@"; do
  [ -f "$p" ] || fail "no probe at $p"
done
command -v godot >/dev/null || fail "godot is not on the PATH"

sha=$(git -C "$REPO" rev-parse --short=7 HEAD)
dirty=""
[ -n "$(git -C "$REPO" status --porcelain)" ] && dirty="-dirty"
EVID="$HOME_DIR/features/$(date -u +%Y%m%dT%H%M%SZ)-$sha$dirty"
mkdir -p "$EVID" || fail "cannot make $EVID"
{
  echo "commit $(git -C "$REPO" rev-parse HEAD)"
  echo "diff-sha256 $(git -C "$REPO" diff HEAD | shasum -a 256 | cut -d' ' -f1)"
  echo "status:"
  git -C "$REPO" status --porcelain
} >"$EVID/tree.txt"

COPY=$(mktemp -d "${TMPDIR:-/tmp/}frostmark-feature.XXXXXX") || fail "cannot make a temp folder"
trap 'rm -rf "$COPY"' EXIT
if (cd "$COPY" && env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --git-dir >/dev/null 2>&1); then
  fail "the temp folder $COPY is inside a repo: set TMPDIR to a folder outside every repo"
fi
(cd "$REPO" && git ls-files -co --exclude-standard -z | while IFS= read -r -d '' f; do
  [ -e "$f" ] && printf '%s\0' "$f"
done | tar -c --null -T - -f -) | tar -x -C "$COPY" || fail "cannot copy the checkout to $COPY"
mkdir -p "$COPY/tools/verify/probes"

echo "probe: importing the copy in $COPY"
imported=0
for try in 1 2; do
  if limit 300 godot --headless --path "$COPY" --import >"$EVID/import.log" 2>&1; then
    imported=1
    break
  fi
  echo "probe: import try $try exited $?" >&2
done
[ "$imported" -eq 1 ] || fail "the import failed (log in $EVID/import.log)"

all_ok=1
: >"$EVID/summary.txt"
for p in "$@"; do
  name=$(basename -- "$p")
  stem=${name%.gd}
  cp "$p" "$EVID/$name"
  cp "$p" "$COPY/tools/verify/probes/$name"
  res=res://tools/verify/probes/$name
  if ! lint=$(limit 30 godot --headless --path "$COPY" -s res://tools/verify/lint.gd -- "$res" 2>&1); then
    echo "$lint" >"$EVID/$stem.log"
    echo "ERROR $name: lint refused it" | tee -a "$EVID/summary.txt"
    echo "$lint" | grep -E '^LINT |SCRIPT ERROR|Parse Error' | sed 's/^/  /'
    all_ok=0
    continue
  fi
  limit "$SECS" godot --headless --path "$COPY" -s "$res" >"$EVID/$stem.log" 2>&1
  rc=$?
  echo "$rc" >"$EVID/$stem.rc"
  lines=$(grep '^PROBE ' "$EVID/$stem.log")
  if [ "$rc" -ne 0 ] || [ -z "$lines" ] || grep -q -E 'SCRIPT ERROR|Parse Error' "$EVID/$stem.log"; then
    verdict=ERROR
  elif grep -q '"pass":false' <<<"$lines"; then
    verdict=FAIL
  else
    verdict=PASS
  fi
  [ "$verdict" = PASS ] || all_ok=0
  echo "$verdict $name (rc=$rc)" | tee -a "$EVID/summary.txt"
  [ -n "$lines" ] && sed 's/^/  /' <<<"$lines" | tee -a "$EVID/summary.txt"
  grep -E -A1 'SCRIPT ERROR|Parse Error' "$EVID/$stem.log" | grep -v '^--$' | sed 's/^/  /'
done
echo "evidence: $EVID"
[ "$all_ok" -eq 1 ]
