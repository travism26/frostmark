#!/bin/bash
# Runs one verify probe on the head copy and the base copy of a record, and prints what each printed.
# usage: tools/verify/drive.sh <record> <probe.gd>
#        tools/verify/drive.sh <record> --prepare
#   <record>  a verify record folder; created if missing
#   <probe>   a probe script that extends res://tools/verify/probe_base.gd
# --prepare only sets up the copies and prints where they are (tools/verify/run.sh calls it
# before the verifier starts, to hand it the head copy).
#
# On the first call for a record it exports the head and base commits with `git archive` to a
# temp folder outside any repo (so neither copy has a .git) and imports each once; later calls
# reuse them. It refuses a dirty tree. It lints the probe, copies it into both copies and the
# record, runs it on each under a perl alarm and prints each side's PROBE lines and errors.
# The record keeps every run's raw output, appended to head.log and base.log, and the latest
# run of each probe in drive/<probe>.head.log and .head.rc (and .base.*), which the verdict
# reads (tools/verify/write_verdict.gd). An rc of 142 is a run the alarm killed.
#
#   VERIFY_HEAD        the head commit (default HEAD)
#   VERIFY_BASE        the base commit (default: git merge-base origin/main <head>)
#   VERIFY_PROBE_SECS  the alarm on each probe run (default 60)
#   VERIFY_REPO        the repo to export from (default: the one this script is in)
# A record that already holds head.sha and base.sha keeps them; the variables only seed a new one.
#
# Exits 0 when the probe ran on both sides, whatever it graded or however it ended; 1 when the
# record could not be set up or the lint refused the probe.
set -u
KIT=$(cd "$(dirname "$0")" && pwd)
REPO=${VERIFY_REPO:-$(cd "$KIT/../.." && pwd)}
SECS=${VERIFY_PROBE_SECS:-60}

# Called in a subshell, which exec replaces, so the alarm kills the run itself. A background run
# goes in braces too, whose stderr takes the shell's "Alarm clock" notice for the killed run.
limit() {
  exec perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]: $!\n"' "$@"
}

fail() {
  echo "drive: $1" >&2
  exit 1
}

[ $# -eq 2 ] || fail "usage: tools/verify/drive.sh <record> <probe.gd>|--prepare"
[ "$2" = --prepare ] || [ -f "$2" ] || fail "no probe at $2"
mkdir -p "$1" || fail "cannot make the record at $1"
RECORD=$(cd "$1" && pwd)
PROBE=$2
NAME=$(basename -- "$PROBE")
STEM=${NAME%.gd}
command -v godot >/dev/null || fail "godot is not on the PATH"

# Exports <sha> to <dir> and puts this kit's probe base and lint in it, so a base commit from
# before the kit existed still runs probes, and both sides run the same kit.
export_copy() {
  local sha=$1 dir=$2
  mkdir -p "$dir" && git -C "$REPO" archive --format=tar "$sha" | tar -x -C "$dir" || return 1
  mkdir -p "$dir/tools/verify/probes" && cp "$KIT/probe_base.gd" "$KIT/lint.gd" "$dir/tools/verify/" || return 1
  [ ! -e "$dir/.git" ]
}

copies_ready() {
  local dir
  dir=$(cat "$RECORD/copies" 2>/dev/null) || return 1
  [ -f "$dir/head/.verify-imported" ] && [ -f "$dir/base/.verify-imported" ] && COPIES=$dir
}

if copies_ready; then
  echo "drive: reusing the copies in $COPIES"
else
  [ -z "$(git -C "$REPO" status --porcelain)" ] || fail "the tree at $REPO is dirty: commit or drop the changes first"
  if [ ! -f "$RECORD/head.sha" ]; then
    head=$(git -C "$REPO" rev-parse --verify "${VERIFY_HEAD:-HEAD}^{commit}") || fail "no head commit ${VERIFY_HEAD:-HEAD}"
    base=${VERIFY_BASE:-$(git -C "$REPO" merge-base origin/main "$head")} || fail "no merge-base of origin/main and $head"
    base=$(git -C "$REPO" rev-parse --verify "$base^{commit}") || fail "no base commit $base"
    echo "$head" >"$RECORD/head.sha"
    echo "$base" >"$RECORD/base.sha"
  fi
  COPIES=$(mktemp -d "${TMPDIR:-/tmp/}frostmark-verify.XXXXXX") || fail "cannot make a temp folder"
  if (cd "$COPIES" && env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --git-dir >/dev/null 2>&1); then
    fail "the temp folder $COPIES is inside a repo: set TMPDIR to a folder outside every repo"
  fi
  for side in head base; do
    export_copy "$(cat "$RECORD/$side.sha")" "$COPIES/$side" || fail "cannot export the $side commit to $COPIES/$side"
  done
  echo "drive: importing the head and base copies in $COPIES"
  # Now and then an import exits partway with no error (its log just stops), so each side gets a
  # second try; the exit codes go in import.retries.
  import_copy() {
    local try
    for try in 1 2; do
      { (limit 300 godot --headless --path "$COPIES/$1" --import >"$COPIES/$1.import.log" 2>&1); } 2>/dev/null && return 0
      echo "$1 import try $try exited $?" >>"$COPIES/import.retries"
    done
    return 1
  }
  for side in head base; do
    import_copy "$side" &
    eval "pid_$side=$!"
  done
  for side in head base; do
    eval "wait \$pid_$side" || fail "the $side import failed (log in $COPIES/$side.import.log)"
  done
  touch "$COPIES/head/.verify-imported" "$COPIES/base/.verify-imported"
  echo "$COPIES" >"$RECORD/copies"
fi
if [ "$PROBE" = --prepare ]; then
  echo "drive: copies ready: $COPIES/head and $COPIES/base"
  exit 0
fi

mkdir -p "$RECORD/probes" "$RECORD/drive"
cp "$PROBE" "$RECORD/probes/$NAME"
for side in head base; do
  cp "$PROBE" "$COPIES/$side/tools/verify/probes/$NAME"
done
RES=res://tools/verify/probes/$NAME

lint=$(limit 30 godot --headless --path "$COPIES/head" -s res://tools/verify/lint.gd -- "$RES" 2>&1)
if [ $? -ne 0 ]; then
  echo "drive: lint refused $NAME:" >&2
  echo "$lint" | grep -E '^LINT |SCRIPT ERROR|Parse Error|ERROR:' >&2
  exit 1
fi

for side in head base; do
  { (limit "$SECS" godot --headless --path "$COPIES/$side" -s "$RES" >"$COPIES/$side.out" 2>&1); } 2>/dev/null &
  eval "pid_$side=$!"
done
for side in head base; do
  eval "wait \$pid_$side"
  rc=$?
  sha=$(cat "$RECORD/$side.sha")
  if [ "$rc" -eq 142 ]; then end="timeout after $SECS s"; else end="rc=$rc"; fi
  cp "$COPIES/$side.out" "$RECORD/drive/$STEM.$side.log"
  echo "$rc" >"$RECORD/drive/$STEM.$side.rc"
  {
    echo "== drive $NAME on $side $sha at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    cat "$COPIES/$side.out"
    echo "== end $NAME $end"
  } >>"$RECORD/$side.log"
  echo "$side ${sha:0:7}: $end"
  grep '^PROBE ' "$COPIES/$side.out" | sed 's/^/  /'
  grep -E -A1 'SCRIPT ERROR|Parse Error|ERROR:' "$COPIES/$side.out" | grep -v '^--$' | sed 's/^/  /'
  grep -q '^PROBE ' "$COPIES/$side.out" || echo "  (no PROBE lines)"
done
