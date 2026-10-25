#!/bin/bash
# Proves the whole verify harness, the verifier included, against a planted bug (spec #144).
# usage: tools/verify/prove.sh
# Run it on a clean tree, once when a PR touches the verifier brief, drive, the probe base or the
# verdict rules. It starts two real Sonnet sessions (a few minutes and about 100k tokens each).
#
# The fixed case is ticket #107 at commit c40cacb, which shipped it, with its parent as the base.
# The ticket is the snapshot in tools/verify/fixtures/ticket-107.md, served by a stand-in for
# `gh issue view 107`; every other gh call goes to the real gh. In order:
#   1. tools/verify/selftest.sh and selftest_run.sh, so a broken drive spends no tokens;
#   2. the planted copy: c40cacb exported with fixtures/plant-107.patch applied, which skips the
#      gate's save on an empty-pack return and edits the matching unit test. Its own unit suite
#      must pass as the shipped copy's does: no FAIL, and no SCRIPT ERROR the shipped one lacks;
#   3. run.sh twice at once, each with its own FROSTMARK_VERIFY_HOME, so each run has its own
#      record, its own session and no earlier runs or frozen probes:
#        shipped  the commit as shipped: must be PASS;
#        planted  VERIFY_HEAD_PATCH=fixtures/plant-107.patch, so only its head copy is patched:
#                 must be FAIL, with AC2 failing on a probe whose observation names the save;
#   4. neither session saw the patch or the other run's record: every path its tools touched is
#      in its own head copy or work folder, and its transcript never names the patch, the other
#      run's home or the fixtures.
# It prints one ok/FAIL line per point, each run's wall time and tokens and the two record paths
# (which go in the PR's record), and exits non-zero on any FAIL. The runs' homes are
# $FROSTMARK_VERIFY_HOME/prove/<stamp>/shipped and planted.
set -u
cd "$(dirname "$0")/../.." || exit 1
KIT=tools/verify
FIX=$(pwd -P)/$KIT/fixtures
HEAD_SHA=c40cacb9137c72a5b430f1c0522db0319b69b697
TICKET=107
failed=0

limit() {
  perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]: $!\n"' "$@"
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

[ -z "$(git status --porcelain)" ] || { echo "prove: commit or drop your changes first (run.sh refuses a dirty tree)" >&2; exit 1; }
for tool in godot gh jq claude; do
  command -v "$tool" >/dev/null || { echo "prove: $tool is not on the PATH" >&2; exit 1; }
done
git cat-file -e "$HEAD_SHA^{commit}" 2>/dev/null || { echo "prove: no commit $HEAD_SHA here: fetch main" >&2; exit 1; }
BASE_SHA=$(git rev-parse "$HEAD_SHA~1")

VHOME=${FROSTMARK_VERIFY_HOME:-${TMPDIR:-/tmp/}frostmark-verify-home}
PROVE=$VHOME/prove/$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$PROVE/shipped" "$PROVE/planted" || { echo "prove: cannot make $PROVE" >&2; exit 1; }
PROVE=$(cd "$PROVE" && pwd -P)
WORK=$(mktemp -d "${TMPDIR:-/tmp/}frostmark-prove.XXXXXX")
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
echo "prove: ticket #$TICKET at ${HEAD_SHA:0:7} (base ${BASE_SHA:0:7}), homes in $PROVE"

echo "== the drive and run.sh selftests"
limit 120 "$KIT/selftest.sh" >"$WORK/selftest.log" 2>&1
check $? "tools/verify/selftest.sh passes"
limit 600 "$KIT/selftest_run.sh" >"$WORK/selftest_run.log" 2>&1
check $? "tools/verify/selftest_run.sh passes"
if [ "$failed" != 0 ]; then
  grep -h '^FAIL' "$WORK"/selftest*.log
  echo "prove: FAIL before any session" >&2
  exit 1
fi

echo "== the planted copy's own unit suite"
for side in shipped planted; do
  mkdir -p "$WORK/$side" && git archive "$HEAD_SHA" | tar -x -C "$WORK/$side"
done
(cd "$WORK/planted" && env -u GIT_DIR -u GIT_WORK_TREE git apply) <"$FIX/plant-$TICKET.patch"
check $? "plant-$TICKET.patch applies to the exported copy"
check "$(holds test -z "$(git status --porcelain)")" "  and the repo is untouched"
suite() {
  limit 300 godot --headless --path "$WORK/$1" --import >"$WORK/$1.import.log" 2>&1 \
    && limit 120 godot --headless --path "$WORK/$1" -s tests/run.gd >"$WORK/$1.unit.log" 2>&1
}
suite shipped &
pid_shipped=$!
suite planted &
pid_planted=$!
wait $pid_shipped
check $? "the shipped copy's suite exits 0"
wait $pid_planted
check $? "the planted copy's suite exits 0"
for side in shipped planted; do
  echo "  $side: $(grep -E '^PASS [0-9]+ / FAIL' "$WORK/$side.unit.log")"
done
check "$(holds grep -qE '^PASS [0-9]+ / FAIL 0 ' "$WORK/planted.unit.log")" "  with no FAIL"
errors() { grep -A1 'SCRIPT ERROR' "$WORK/$1.unit.log" | grep -v '^--$' | sort -u; }
extra=$(comm -13 <(errors shipped) <(errors planted))
check "$(holds test -z "$extra")" "  and no SCRIPT ERROR the shipped suite does not log${extra:+: $extra}"

echo "== the two runs"
REAL_GH=$(command -v gh)
mkdir -p "$WORK/shims"
cat >"$WORK/shims/gh" <<EOF
#!/bin/bash
# prove.sh's stand-in for gh: ticket #$TICKET from its fixture, everything else from the real gh.
if [ "\$1 \$2 \$3" = "issue view $TICKET" ]; then
  # The fixture is "# #<n> <title>", a blank line, then the body and a newline.
  exec jq -Rs 'index("\n") as \$i | {number: $TICKET, title: (.[0:\$i] | ltrimstr("# #$TICKET ")),
    body: .[\$i + 2:-1], url: "https://github.com/travism26/frostmark/issues/$TICKET"}' "$FIX/ticket-$TICKET.md"
fi
exec "$REAL_GH" "\$@"
EOF
chmod +x "$WORK/shims/gh"
check "$(holds cmp <(PATH="$WORK/shims:$PATH" gh issue view $TICKET --json number,title,body,url | jq -r '"# #\(.number) \(.title)\n\n\(.body)"') "$FIX/ticket-$TICKET.md")" "the stand-in serves the fixture ticket as run.sh writes it"

verify() {
  env PATH="$WORK/shims:$PATH" FROSTMARK_VERIFY_HOME="$PROVE/$1" VERIFY_HEAD=$HEAD_SHA VERIFY_BASE=$BASE_SHA ${2:+VERIFY_HEAD_PATCH="$2"} \
    perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]: $!\n"' 1500 "$KIT/run.sh" "$TICKET" >"$WORK/$1.log" 2>&1
}
started=$SECONDS
verify shipped "" &
pid_shipped=$!
verify planted "$FIX/plant-$TICKET.patch" &
pid_planted=$!
wait $pid_shipped
rc_shipped=$?
wait $pid_planted
rc_planted=$?
runs_wall=$((SECONDS - started))
for side in shipped planted; do
  echo "-- run.sh, $side"
  sed 's/^/  | /' "$WORK/$side.log"
done
check "$(holds test "$rc_shipped" = 0 -a "$rc_planted" = 0)" "both runs print a verdict (exits $rc_shipped and $rc_planted)"
REC_SHIPPED=$(sed -n 's/^record: //p' "$WORK/shipped.log")
REC_PLANTED=$(sed -n 's/^record: //p' "$WORK/planted.log")

echo "== run 1: the commit as shipped"
check "$(holds grep -qx 'verdict: PASS' "$WORK/shipped.log")" "is PASS"
check "$(holds test ! -e "$REC_SHIPPED/head.patch" -a "$(jq -r '.binding.head_patch // ""' "$REC_SHIPPED/verdict.json" 2>/dev/null)" = "")" "  with no patch on its head copy"

echo "== run 2: the planted bug"
check "$(holds grep -qx 'verdict: FAIL' "$WORK/planted.log")" "is FAIL"
AC2=$(jq -c '.criteria[] | select(.id == "AC2")' "$REC_PLANTED/verdict.json" 2>/dev/null)
echo "  AC2: $(jq -r '"\(.grade) (\(.kind), \(.evidence)): \(.observed)"' <<<"${AC2:-null}" 2>/dev/null)"
check "$(holds test "$(jq -r .grade <<<"${AC2:-null}")" = FAIL)" "  with AC2 failing"
check "$(holds jq -e '.kind | IN("sim", "data")' <<<"${AC2:-null}")" "  on a probe"
check "$(holds grep -qi 'sav' <<<"$(jq -r .observed <<<"${AC2:-null}")")" "  whose observation names the save"
check "$(holds cmp "$REC_PLANTED/head.patch" "$FIX/plant-$TICKET.patch")" "the patch went on its head copy"
check "$(holds test "$(jq -r .binding.head_patch "$REC_PLANTED/verdict.json")" = "$(shasum -a 256 "$FIX/plant-$TICKET.patch" | cut -d' ' -f1)")" "  and its verdict is bound to it"

echo "== what each session saw"
# Every path a session's tools named, with macOS's /private prefix dropped.
touched() {
  jq -r -R 'fromjson? | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")
    | .input | (.file_path // .path // .notebook_path // empty)' "$1/transcript.jsonl" | sed 's#^/private/#/#'
}
for side in shipped planted; do
  rec=$REC_SHIPPED other=planted
  [ "$side" = planted ] && rec=$REC_PLANTED other=shipped
  if [ ! -f "$rec/session.json" ] || [ "$(jq -r .started "$rec/session.json")" != true ]; then
    check 1 "the $side run started a session"
    continue
  fi
  outside=""
  while read -r p; do
    [ -n "$p" ] || continue
    case $p in /*) ;; *) continue ;; esac
    inside=0
    for dir in $(jq -r '.readable[]' "$rec/session.json" | sed 's#^/private/#/#'); do
      case $p/ in "$dir"/*) inside=1 ;; esac
    done
    [ "$inside" = 1 ] || outside="$outside $p"
  done < <(touched "$rec")
  check "$(holds test -z "$outside")" "the $side session's tools touched only its head copy and work folder${outside:+:$outside}"
  check "$(holds test "$(grep -c -e "plant-$TICKET" -e "$KIT/fixtures" -e "${PROVE#/private}/$other" "$rec/transcript.jsonl" "$rec/prompt.md" | awk -F: '{s += $NF} END {print s}')" = 0)" \
    "  and its prompt and transcript never name the patch, the fixtures or the $other run's home"
done

echo "== the cost"
for side in shipped planted; do
  rec=$REC_SHIPPED
  [ "$side" = planted ] && rec=$REC_PLANTED
  jq -r --arg side "$side" '"\($side): session \(.wall_secs) s, \(.drive_calls) drive calls, \(.num_turns) turns, tokens in \(.tokens.input) out \(.tokens.output) cache read \(.tokens.cache_read) cache write \(.tokens.cache_creation) (\(.tokens | add) in all), $\(.cost_usd)"' \
    "$rec/session.json" 2>/dev/null || echo "$side: no session.json"
  sed -n "s/^verify: \([0-9]*\) s$/  run.sh $side: \1 s/p" "$WORK/$side.log"
done
echo "the two runs, side by side: $runs_wall s; prove.sh in all: $SECONDS s"
echo "record (shipped): $REC_SHIPPED"
echo "record (planted): $REC_PLANTED"
[ "$failed" = 0 ] && echo "prove: OK" || { echo "prove: FAIL" >&2; exit 1; }
