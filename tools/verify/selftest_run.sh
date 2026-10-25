#!/bin/bash
# Proves tools/verify/run.sh against canned tickets, with stand-ins for gh and claude, so it
# spends no tokens. (tools/verify/selftest.sh proves drive; tools/verify/prove.sh, the real
# verifier.)
# usage: tools/verify/selftest_run.sh
# Run it on a clean tree, on any PR that touches tools/verify/. Records go in a temp
# FROSTMARK_VERIFY_HOME. It prints one ok/FAIL line per point and exits non-zero on any FAIL.
#
# The claude stand-in acts on the `selftest: <mode>` line of the ticket in its prompt:
#   pass    writes a probe, drives it once, and grades AC1 on it and AC2 on CI
#   drives  the same, but drives three times
#   hang    never returns
# and notes its cwd, arguments and GIT_* variables for the checks.
set -u
cd "$(dirname "$0")/../.." || exit 1
RUN=tools/verify/run.sh
WORK=$(mktemp -d "${TMPDIR:-/tmp/}frostmark-selftest-run.XXXXXX")
WORK=$(cd "$WORK" && pwd -P)
DATA=$WORK/data
SHIMS=$WORK/shims
export FROSTMARK_VERIFY_HOME=$WORK/home
failed=0

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

# Runs run.sh with the stand-ins first on the PATH, bounded.
run() {
  PATH="$SHIMS:$PATH" perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]: $!\n"' 120 "$RUN" "$@" 2>&1
}

sessions() {
  ls "$DATA" | grep -cE '^claude\.[0-9]+$'
}

record_of() {
  sed -n 's/^record: //p' <<<"$1"
}

[ -z "$(git status --porcelain)" ] || { echo "selftest_run: commit or drop your changes first (run.sh refuses a dirty tree)" >&2; exit 1; }
mkdir -p "$DATA" "$SHIMS"

ticket() {
  local n=$1 mode=$2 criteria=$3
  jq -n --argjson n "$n" --arg mode "$mode" --arg criteria "$criteria" \
    '{number: $n, title: "selftest \($mode)", url: "https://example.invalid/\($n)",
      body: "## What to build\r\nselftest: \($mode)\r\n\r\n## Acceptance criteria\r\n\($criteria)\r\n## Blocked by\r\n- [ ] not a criterion\r\n"}' \
    >"$DATA/ticket-$n.json"
}
TWO="- [ ] A probe passes.
- [ ] The suite passes."
ticket 901 none ""
ticket 902 none "- [ ] It reads well. (look)
- [ ] It is fun. (playtest)"
ticket 903 pass "$TWO"
ticket 904 hang "$TWO"
ticket 905 drives "$TWO"

cat >"$SHIMS/gh" <<EOF
#!/bin/bash
# selftest stand-in for gh: the canned tickets, and CI green for every SHA.
case "\$1 \$2" in
  "issue view") cat "$DATA/ticket-\$3.json" 2>/dev/null || { echo "no issue \$3" >&2; exit 1; } ;;
  "api "*) echo '[{"name":"Test and web export","status":"completed","conclusion":"success"}]' ;;
  *) echo "selftest gh: unexpected \$*" >&2; exit 1 ;;
esac
EOF
cat >"$SHIMS/claude" <<EOF
#!/bin/bash
# selftest stand-in for claude (see the top of selftest_run.sh).
prompt=\$(cat)
n=\$(ls "$DATA" | grep -cE '^claude\.[0-9]+\$')
note=$DATA/claude.\$((n + 1))
{
  echo "cwd=\$(pwd -P)"
  echo "in_repo=\$(git rev-parse --git-dir >/dev/null 2>&1 && echo yes || echo no)"
  echo "git_vars=\$(env | grep -c '^GIT_')"
  printf 'arg=%s\n' "\$@"
} >"\$note"
case \$(sed -n 's/^selftest: //p' <<<"\$prompt" | head -n 1) in
  hang) sleep 20; exit 0 ;;
  drives) times=3 ;;
  *) times=1 ;;
esac
printf 'extends "res://tools/verify/probe_base.gd"\n\n\nfunc run() -> void:\n\tgrade("AC1", true, "selftest")\n' >p.gd
for i in \$(seq \$times); do drive p.gd >>"\$note.drive" 2>&1; done
cat >grades.json <<'JSON'
{"criteria": [
  {"id": "AC1", "kind": "sim", "new": false, "grade": "PASS", "evidence": "p.gd:AC1", "observed": "selftest"},
  {"id": "AC2", "kind": "gate", "new": false, "grade": "PASS", "evidence": "ci", "observed": ""}
], "flags": [], "notes": []}
JSON
echo '{"type":"result","num_turns":1,"total_cost_usd":0,"modelUsage":{"selftest-model":{"inputTokens":1,"outputTokens":1}}}'
EOF
chmod +x "$SHIMS/gh" "$SHIMS/claude"

echo "== the ticket lint"
out=$(run 901)
echo "$out" | grep -E '^(verify|verdict|record):' | sed 's/^/  | /'
check "$(holds grep -qx 'verdict: INCONCLUSIVE' <<<"$out")" "no criteria: INCONCLUSIVE"
out=$(run 902)
check "$(holds grep -qx 'verdict: PASS' <<<"$out")" "only (look) and (playtest) criteria: a no-op PASS"
check "$(holds grep -q 'AC2 (playtest): It is fun' "$(record_of "$out")/report.md")" "  with the criteria listed as residue"
check "$(holds test "$(sessions)" = 0)" "neither starts a session"

echo "== a first run"
export GIT_SELFTEST=1
out=$(run 903)
unset GIT_SELFTEST
echo "$out" | grep -E '^(verify|verdict|record):' | sed 's/^/  | /'
REC1=$(record_of "$out")
check "$(holds grep -qx 'verdict: PASS' <<<"$out")" "prints the verdict"
check "$(holds test -d "$REC1")" "and the record path"
case $REC1 in "$FROSTMARK_VERIFY_HOME/903/$(git rev-parse --short=12 HEAD)-"*) at=0 ;; *) at=1 ;; esac
check "$at" "the record is \$FROSTMARK_VERIFY_HOME/<ticket>/<sha>-<stamp>"
missing=""
for f in ticket.md criteria.json probes/p.gd head.log base.log grades.json verdict.json report.md inputs.json session.json transcript.jsonl; do
  [ -s "$REC1/$f" ] || missing="$missing $f"
done
check "$(holds test -z "$missing")" "it holds the ticket and hash, probe, head and base output, grades, verdict and report${missing:+ (missing:$missing)}"
check "$(holds test "$(jq -r .hash "$REC1/criteria.json")" = "$(jq -r .binding.criteria_hash "$REC1/verdict.json")")" "the verdict is bound to the criteria hash"
check "$(holds test "$(sessions)" = 1)" "one session started"
NOTE=$DATA/claude.1
check "$(holds grep -qx 'in_repo=no' "$NOTE")" "the session starts outside any repo"
check "$(holds grep -qx 'git_vars=0' "$NOTE")" "  with no GIT_* variables"
check "$(holds grep -qx "cwd=$(jq -r .cwd "$REC1/session.json")" "$NOTE")" "  and the record notes its cwd"
check "$(holds test "$(jq -r .model "$REC1/session.json")" = sonnet -a "$(jq -r .verifier_model "$REC1/inputs.json")" = selftest-model)" "  and its model"
for a in --print --restricted "Bash(drive *)" "Edit(./**)" --strict-mcp-config; do
  check "$(holds grep -qxF "arg=$a" "$NOTE")" "  claude gets $a"
done
check "$(holds test "$(grep -A1 -xF 'arg=--model' "$NOTE" | tail -n 1)" = arg=sonnet)" "  claude gets --model sonnet"
check "$(holds test "$(grep -A1 -xF 'arg=--add-dir' "$NOTE" | tail -n 1)" = "arg=$(jq -r '.readable[1]' "$REC1/session.json")")" "  and only the head copy beyond its work folder"
check "$(holds test "$(cat "$FROSTMARK_VERIFY_HOME/903/frozen")" = "$(basename "$REC1")")" "its probes are frozen for the ticket"
sum1=$(cat "$REC1"/*.json | shasum)

echo "== a second run"
out=$(run 903)
echo "$out" | grep -E '^(verify|verdict|record):' | sed 's/^/  | /'
REC2=$(record_of "$out")
check "$(holds grep -q 're-driving the frozen probes' <<<"$out")" "re-drives the frozen probes"
check "$(holds test "$(sessions)" = 1)" "  with no session"
check "$(holds grep -qx 'verdict: PASS' <<<"$out")" "  and the same verdict"
check "$(holds test -n "$REC2" -a "$REC2" != "$REC1" -a -s "$REC2/drive/p.head.log")" "in a new record"
check "$(holds test "$(cat "$REC1"/*.json | shasum)" = "$sum1")" "the first record is untouched"

echo "== --replay"
out=$(run 903 --replay "$REC1")
echo "$out" | grep -E '^(replay|verdict):' | sed 's/^/  | /'
check "$(holds grep -q '^replay: reproduces' <<<"$out")" "reproduces the record's verdict at its SHA"
check "$(holds test "$(sessions)" = 1)" "  with no session"
out=$(VERIFY_HEAD=HEAD~1 run 903 --replay "$REC1")
check "$(holds grep -q 'refused: .* was made at' <<<"$out")" "refuses another SHA"
cp "$DATA/ticket-903.json" "$DATA/ticket-903.orig"
jq '.body |= sub("- \\[ \\] A probe"; "- [x] A probe")' "$DATA/ticket-903.orig" >"$DATA/ticket-903.json"
out=$(run 903 --replay "$REC1")
check "$(holds grep -q '^replay: reproduces' <<<"$out")" "a ticked box is not an edit"
jq '.body |= sub("A probe passes"; "A probe passes twice")' "$DATA/ticket-903.orig" >"$DATA/ticket-903.json"
out=$(run 903 --replay "$REC1")
check "$(holds grep -q 'refused: the ticket.s criteria have been edited' <<<"$out")" "refuses edited criteria"
mv "$DATA/ticket-903.orig" "$DATA/ticket-903.json"

echo "== a frozen probe that errors"
cp tools/verify/fixtures/probes/probe_error.gd "$REC1/probes/p.gd"
out=$(run 903)
echo "$out" | grep -E '^(verify|verdict|drive):' | sed 's/^/  | /'
REC3=$(record_of "$out")
check "$(holds grep -q 'errors on head' <<<"$out")" "is noticed on the re-drive"
check "$(holds test "$(sessions)" = 2)" "  and starts a fresh session"
check "$(holds test "$(cat "$FROSTMARK_VERIFY_HOME/903/frozen")" = "$(basename "$REC3")")" "  whose probes are frozen instead"

echo "== the caps"
out=$(VERIFY_SESSION_SECS=2 run 904)
echo "$out" | grep -E '^(verify|verdict|drive):' | sed 's/^/  | /'
check "$(holds grep -qx 'verdict: INCONCLUSIVE' <<<"$out")" "a session past its time cap is INCONCLUSIVE"
check "$(holds test "$(jq -r .capped "$(record_of "$out")/session.json")" = time)" "  and noted as capped"
check "$(holds test ! -e "$FROSTMARK_VERIFY_HOME/904/frozen")" "  and its probes are not frozen"
out=$(VERIFY_DRIVE_CAP=2 run 905)
echo "$out" | grep -E '^(verify|verdict|drive):' | sed 's/^/  | /'
check "$(holds grep -qx 'verdict: INCONCLUSIVE' <<<"$out")" "a third drive past a cap of 2 is refused and INCONCLUSIVE"
check "$(holds grep -q 'refused: the cap of 2 drive calls' "$DATA/claude.$(sessions).drive")" "  the session is told why"
check "$(holds grep -q 'cap of 2 drive calls' "$(record_of "$out")/report.md")" "  and so is the report"

echo "== a dirty tree"
before=$(ls "$FROSTMARK_VERIFY_HOME/903" | wc -l)
git clone -q . "$WORK/clone" && touch "$WORK/clone/untracked"
out=$(PATH="$SHIMS:$PATH" "$WORK/clone/$RUN" 903 2>&1)
check "$(holds grep -q 'dirty' <<<"$out")" "run.sh refuses it"
check "$(holds test "$(ls "$FROSTMARK_VERIFY_HOME/903" | wc -l)" = "$before")" "  and makes no record"

rm -rf "$WORK"
echo "selftest_run: ${SECONDS} s"
[ "$failed" = 0 ] && echo "selftest_run: OK" || { echo "selftest_run: FAIL" >&2; exit 1; }
