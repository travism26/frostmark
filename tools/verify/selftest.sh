#!/bin/bash
# Proves tools/verify/drive.sh against the fixture probes in tools/verify/fixtures/probes/.
# usage: tools/verify/selftest.sh
# Run it on a clean tree (drive refuses a dirty one), on any PR that touches tools/verify/.
# It drives the committed HEAD and its merge-base with origin/main into a temp record, prints
# one ok/FAIL line per point and exits non-zero on any FAIL or if it takes 30 s or more.
set -u
cd "$(dirname "$0")/../.." || exit 1
DRIVE=tools/verify/drive.sh
FIX=tools/verify/fixtures/probes
WORK=$(mktemp -d "${TMPDIR:-/tmp/}frostmark-selftest.XXXXXX")
RECORD=$WORK/record
failed=0

# Bounds the selftest's own call to drive, which bounds every Godot run inside it.
drive() {
  perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]: $!\n"' 60 "$DRIVE" "$@"
}

check() {
  if [ "$1" = 0 ]; then
    echo "ok    $2"
  else
    echo "FAIL  $2"
    failed=1
  fi
}

holds() {
  "$@" >/dev/null 2>&1
  echo $?
}

[ -z "$(git status --porcelain)" ] || { echo "selftest: commit or drop your changes first (drive refuses a dirty tree)" >&2; exit 1; }

echo "== a fixture probe"
out=$(drive "$RECORD" "$FIX/probe_ok.gd" 2>&1)
echo "$out" | sed 's/^/  | /'
check "$(holds grep -q 'PROBE {"id":"AC1"' <(echo "$out" | sed -n '/^head /,/^base /p'))" "the head PROBE lines are printed"
check "$(holds grep -q 'PROBE {"id":"AC1"' <(echo "$out" | sed -n '/^base /,$p'))" "the base PROBE lines are printed"
check "$(holds grep -q '^PROBE {"id":"AC2"' "$RECORD/head.log")" "the head output is saved in the record"
check "$(holds grep -q '^PROBE {"id":"AC2"' "$RECORD/base.log")" "the base output is saved in the record"
check "$(holds grep -q '^PROBE {"id":"AC2"' "$RECORD/drive/probe_ok.head.log")" "the latest head output is saved where the verdict reads it"
check "$(holds test "$(cat "$RECORD/drive/probe_ok.head.rc" "$RECORD/drive/probe_ok.base.rc")" = "0
0")" "with each side's exit code"
check "$(holds cmp "$FIX/probe_ok.gd" "$RECORD/probes/probe_ok.gd")" "the probe is saved in the record"

echo "== the copies"
COPIES=$(cat "$RECORD/copies")
check "$(holds test -d "$COPIES/head/sim" -a -d "$COPIES/base/sim")" "head and base copies exist"
check "$(holds test ! -e "$COPIES/head/.git" -a ! -e "$COPIES/base/.git")" "neither copy has a .git"
check "$(holds test -z "$(find "$COPIES" -name .git)")" "nothing under the copies has a .git"
check "$(holds sh -c "cd '$COPIES/head' && ! env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --git-dir")" "the copies are outside any repo"
case $COPIES in "$(pwd)"/*) inside=1 ;; *) inside=0 ;; esac
check "$inside" "the copies are outside this worktree"

echo "== a dirty tree"
DIRTY=$WORK/dirty
mkdir -p "$DIRTY" && git -C "$DIRTY" init -q && touch "$DIRTY/a" && git -C "$DIRTY" add a \
  && git -C "$DIRTY" -c user.name=selftest -c user.email=selftest@invalid commit -qm a && touch "$DIRTY/b"
out=$(VERIFY_REPO=$DIRTY drive "$WORK/dirty-record" "$FIX/probe_ok.gd" 2>&1)
rc=$?
echo "$out" | sed 's/^/  | /'
check "$(holds test "$rc" -ne 0)" "drive exits non-zero"
check "$(holds grep -q dirty <<<"$out")" "and says the tree is dirty"
check "$(holds test ! -e "$WORK/dirty-record/copies")" "and makes no copies"

echo "== a later drive on the same record"
touch "$COPIES/head/.selftest-sentinel"
out=$(drive "$RECORD" "$FIX/probe_ok.gd" 2>&1)
check "$(holds grep -q 'reusing the copies' <<<"$out")" "says it reuses the copies"
check "$(holds test "$(cat "$RECORD/copies")" = "$COPIES" -a -e "$COPIES/head/.selftest-sentinel")" "and the copies are the same, not re-exported"
check "$(holds test "$(grep -c '^== drive probe_ok.gd on head' "$RECORD/head.log")" = 2)" "and appends the second run to the record"

echo "== a probe with a script error"
out=$(drive "$RECORD" "$FIX/probe_error.gd" 2>&1)
echo "$out" | sed 's/^/  | /'
check "$(holds test -z "$(grep 'PROBE {' <<<"$out")")" "yields no PROBE line"
check "$(holds grep -q "SCRIPT ERROR: Invalid call. Nonexistent function 'walk'" <<<"$out")" "prints the error"
check "$(holds grep -q 'SCRIPT ERROR' <(sed -n '/^== drive probe_error.gd/,/^== end/p' "$RECORD/head.log"))" "records the error"
check "$(holds grep -q 'SCRIPT ERROR' "$RECORD/drive/probe_error.head.log")" "where the verdict reads it"

echo "== a probe that never quits"
out=$(VERIFY_PROBE_SECS=2 drive "$RECORD" "$FIX/probe_hang.gd" 2>&1)
echo "$out" | sed 's/^/  | /'
check "$(holds grep -q '^head .*: timeout after 2 s' <<<"$out")" "is killed by the alarm (2 s here, 60 s by default)"
check "$(holds grep -q '^== end probe_hang.gd timeout after 2 s' "$RECORD/head.log")" "is recorded as a timeout"
check "$(holds test "$(cat "$RECORD/drive/probe_hang.head.rc")" = 142)" "with the alarm's exit code, 142"
check "$(holds test -z "$(grep -i 'alarm clock' "$RECORD/head.log" - <<<"$out")")" "and neither the record nor the output has shell noise"

echo "== probe lint"
while read -r f why; do
  before=$(wc -l <"$RECORD/head.log")
  out=$(drive "$RECORD" "$FIX/$f.gd" 2>&1)
  rc=$?
  echo "$out" | sed 's/^/  | /'
  check "$(holds test "$rc" -ne 0 -a "$(wc -l <"$RECORD/head.log")" = "$before")" "$f.gd is refused and not run"
  check "$(holds grep -q "^LINT .*$why" <<<"$out")" "  because it $why"
done <<'EOF'
lint_extends must start with: extends
lint_load loads a path off the allowed list
lint_file_access uses FileAccess
lint_dir_access uses DirAccess
lint_os_execute uses OS.execute
EOF

rm -rf "$COPIES" "$WORK"
echo "selftest: ${SECONDS} s"
check "$(holds test "$SECONDS" -lt 30)" "the selftest takes under 30 s"
[ "$failed" = 0 ] && echo "selftest: OK" || { echo "selftest: FAIL" >&2; exit 1; }
