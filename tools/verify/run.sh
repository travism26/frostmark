#!/bin/bash
# Verifies one ticket's acceptance criteria at the committed head and leaves a record (spec #144).
# usage: tools/verify/run.sh <ticket> [--fresh]
#        tools/verify/run.sh <ticket> --replay <record>
#
# It refuses a dirty tree. It fetches the ticket from GitHub and lints it, then makes a new
# record, never overwriting one: $FROSTMARK_VERIFY_HOME/<ticket>/<sha>-<stamp>/. Then:
#   - no criteria: INCONCLUSIVE; every criterion (look) or (playtest): a no-op PASS. Neither
#     starts a session;
#   - the ticket has frozen probes (its first session's) for the same criteria: it re-drives
#     them with no session, unless one errors on head;
#   - otherwise, or with --fresh, it starts the verifier: a headless `claude --print --model
#     sonnet` session from a temp folder outside any repo, with only HOME, PATH and a few
#     locale variables in its environment (so no GIT_*). It can read the head copy (which holds
#     the probe kit) and its work folder, write only its work folder, and run only `drive`. It is
#     capped at 15 minutes and 12 drive calls; hitting either makes the run INCONCLUSIVE. Its
#     probes are frozen for the ticket when it ends within the caps with a grades.json;
# then reads CI's conclusion for the head SHA, takes the test guard from the diff of tests/,
# writes the verdict (tools/verify/write_verdict.gd) and prints the report, the verdict and the
# record path.
#
# --replay <record> re-drives that record's probes with its grades at its head SHA and recomputes
# the verdict in a new record, re-reading only CI. It refuses when the head is another SHA or the
# ticket's criteria have been edited since (ticking a box is not an edit).
#
#   FROSTMARK_VERIFY_HOME  where records live (default ${TMPDIR}frostmark-verify-home)
#   VERIFY_HEAD            the commit to verify (default HEAD)
#   VERIFY_BASE            its base (default: git merge-base origin/main <head>)
#   VERIFY_SESSION_SECS    the session's time cap (default 900)
#   VERIFY_DRIVE_CAP       the session's drive-call cap (default 12)
#
# Exits 0 when it printed a verdict, 1 when it refused or could not finish.
set -u
KIT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$KIT/../.." && pwd)
cd "$REPO" || exit 1
MODEL=sonnet
SESSION_SECS=${VERIFY_SESSION_SECS:-900}
DRIVE_CAP=${VERIFY_DRIVE_CAP:-12}
STARTED=$SECONDS

fail() {
  echo "verify: $1" >&2
  exit 1
}

usage() {
  fail "usage: tools/verify/run.sh <ticket> [--fresh] | <ticket> --replay <record>"
}

limit() {
  perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]: $!\n"' "$@"
}

# Runs a Godot script and prints its output without the engine's banner line.
gd() {
  local out
  out=$(limit 60 godot --headless -s "$@" 2>/dev/null) || return 1
  sed '/^Godot Engine v/d' <<<"$out"
}

COPIES=""
SESS=""
CI=""
GUARD="{}"
CHANGED="[]"
EARLIER="[]"
VERIFIER_MODEL=none
cleanup() {
  [ -n "$COPIES" ] && rm -rf "$COPIES"
  [ -n "$SESS" ] && rm -rf "$SESS"
}
trap cleanup EXIT

TICKET=""
REPLAY=""
FRESH=0
while [ $# -gt 0 ]; do
  case $1 in
    --replay) [ $# -ge 2 ] || usage; REPLAY=$2; shift 2 ;;
    --fresh) FRESH=1; shift ;;
    -*) usage ;;
    *) [ -z "$TICKET" ] || usage; TICKET=$1; shift ;;
  esac
done
[[ $TICKET =~ ^[0-9]+$ ]] || usage
[ -z "$REPLAY" ] || [ "$FRESH" = 0 ] || usage
for tool in godot gh jq claude; do
  command -v "$tool" >/dev/null || fail "$tool is not on the PATH"
done

[ -z "$(git status --porcelain)" ] || fail "the tree is dirty: commit or drop the changes first"
HEAD_SHA=$(git rev-parse --verify "${VERIFY_HEAD:-HEAD}^{commit}") || fail "no head commit ${VERIFY_HEAD:-HEAD}"

VHOME=${FROSTMARK_VERIFY_HOME:-${TMPDIR:-/tmp/}frostmark-verify-home}
mkdir -p "$VHOME/$TICKET" || fail "cannot make $VHOME/$TICKET"
VHOME=$(cd "$VHOME" && pwd -P)
case $VHOME/ in "$(pwd -P)"/*) fail "FROSTMARK_VERIFY_HOME ($VHOME) is inside this worktree: records must outlive it" ;; esac
[ -n "${FROSTMARK_VERIFY_HOME:-}" ] || echo "verify: FROSTMARK_VERIFY_HOME is unset; records go in $VHOME"
TDIR=$VHOME/$TICKET

# The replayed record, checked before anything is fetched or made.
if [ -n "$REPLAY" ]; then
  [ -d "$REPLAY" ] || fail "no record at $REPLAY"
  REPLAY=$(cd "$REPLAY" && pwd -P)
  [ -f "$REPLAY/inputs.json" ] && [ -f "$REPLAY/verdict.json" ] || fail "$REPLAY is not a finished record"
  [ "$(jq -r .ticket "$REPLAY/inputs.json")" = "$TICKET" ] || fail "$REPLAY is a record for ticket $(jq -r .ticket "$REPLAY/inputs.json"), not $TICKET"
  was=$(jq -r .head_sha "$REPLAY/inputs.json")
  [ "$was" = "$HEAD_SHA" ] || fail "refused: $REPLAY was made at $was, and the head is $HEAD_SHA"
  BASE_SHA=$(jq -r .base_sha "$REPLAY/inputs.json")
else
  BASE_SHA=${VERIFY_BASE:-$(git merge-base origin/main "$HEAD_SHA")} || fail "no merge-base of origin/main and $HEAD_SHA"
  BASE_SHA=$(git rev-parse --verify "$BASE_SHA^{commit}") || fail "no base commit $BASE_SHA"
fi

# The ticket, fetched by number, never passed in.
TMP_TICKET=$(mktemp "${TMPDIR:-/tmp/}frostmark-ticket.XXXXXX")
gh issue view "$TICKET" --json number,title,body,url >"$TMP_TICKET.json" 2>/dev/null || { rm -f "$TMP_TICKET"*; fail "cannot fetch ticket #$TICKET"; }
jq -r '"# #\(.number) \(.title)\n\n\(.body | gsub("\r"; ""))"' "$TMP_TICKET.json" >"$TMP_TICKET"
CRITERIA=$(gd tools/verify/record.gd -- criteria "$TMP_TICKET") || { rm -f "$TMP_TICKET"*; fail "cannot read the ticket's criteria"; }
CRITERIA_HASH=$(jq -r .hash <<<"$CRITERIA")
if [ -n "$REPLAY" ]; then
  was=$(jq -r .binding.criteria_hash "$REPLAY/verdict.json")
  [ "$was" = "$CRITERIA_HASH" ] || { rm -f "$TMP_TICKET"*; fail "refused: the ticket's criteria have been edited since $REPLAY"; }
fi

stamp=$(date -u +%Y%m%dT%H%M%SZ)
RECORD=$TDIR/${HEAD_SHA:0:12}-$stamp
n=1
while ! mkdir "$RECORD" 2>/dev/null; do
  n=$((n + 1))
  [ "$n" -lt 100 ] || fail "cannot make a new record in $TDIR"
  RECORD=$TDIR/${HEAD_SHA:0:12}-$stamp-$n
done
mv "$TMP_TICKET" "$RECORD/ticket.md"
mv "$TMP_TICKET.json" "$RECORD/ticket.json"
echo "$CRITERIA" | jq . >"$RECORD/criteria.json"
echo "$HEAD_SHA" >"$RECORD/head.sha"
echo "$BASE_SHA" >"$RECORD/base.sha"
echo "verify: ticket #$TICKET at ${HEAD_SHA:0:7} (base ${BASE_SHA:0:7}), record $RECORD"

# Writes inputs.json from the variables gathered so far; $1 is the session.json content.
write_inputs() {
  jq -n --argjson ticket "$TICKET" --arg head "$HEAD_SHA" --arg base "$BASE_SHA" --arg ci "$CI" \
    --arg harness "$(git rev-parse "$HEAD_SHA:tools/verify" 2>/dev/null)" --arg model "$VERIFIER_MODEL" \
    --arg copy "${COPIES:+$COPIES/head}" --argjson guard "$GUARD" --argjson changed "$CHANGED" \
    --argjson earlier "$EARLIER" --arg replay_of "$(basename "${REPLAY:-}")" --arg mode "$MODE" \
    '{ticket: $ticket, head_sha: $head, base_sha: $base, ci: $ci, harness_version: $harness,
      verifier_model: $model, head_copy: $copy, test_guard: $guard, changed_since_fail: $changed,
      earlier: $earlier, mode: $mode} + (if $replay_of == "" then {} else {replay_of: $replay_of} end)' \
    >"$RECORD/inputs.json"
  echo "$1" | jq . >"$RECORD/session.json"
}

finish() {
  local out verdict
  out=$(gd tools/verify/write_verdict.gd -- "$RECORD") || fail "cannot write the verdict in $RECORD"
  verdict=$(jq -r .verdict "$RECORD/verdict.json")
  echo
  cat "$RECORD/report.md"
  echo
  if [ -n "$REPLAY" ]; then
    was=$(jq -r .verdict "$REPLAY/verdict.json")
    if [ "$was" = "$verdict" ]; then echo "replay: reproduces $(basename "$REPLAY")'s $was"; else echo "replay: differs from $(basename "$REPLAY"), which was $was"; fi
  fi
  echo "verdict: $verdict"
  echo "record: $RECORD"
  echo "verify: $((SECONDS - STARTED)) s"
  exit 0
}

# Ticket lint, before anything is spent.
MODE=lint
if [ "$(jq .count <<<"$CRITERIA")" = 0 ]; then
  write_inputs '{"started": false, "why": "the ticket has no acceptance criteria"}'
  finish
fi
if [ "$(jq .graded <<<"$CRITERIA")" = 0 ]; then
  write_inputs '{"started": false, "why": "every criterion is (look) or (playtest)"}'
  finish
fi

# What the script reads from git and CI, never shown to the verifier.
CI_RUNS=$(gh api "repos/{owner}/{repo}/commits/$HEAD_SHA/check-runs" --jq '[.check_runs[] | {name, status, conclusion}]' 2>/dev/null) || CI_RUNS=null
echo "$CI_RUNS" | jq . >"$RECORD/ci.json"
CI=$(jq -r 'if . == null then "unknown"
  elif any(.[]; .status == "completed" and (.conclusion | IN("success", "skipped", "neutral") | not)) then "failure"
  elif any(.[]; .status != "completed") then "pending"
  elif length == 0 then "none"
  else "success" end' <<<"$CI_RUNS")

if [ -n "$REPLAY" ]; then
  GUARD=$(jq -c .test_guard "$REPLAY/inputs.json")
  CHANGED=$(jq -c .changed_since_fail "$REPLAY/inputs.json")
  EARLIER=$(jq -c .earlier "$REPLAY/inputs.json")
else
  git diff -M -U0 "$BASE_SHA" "$HEAD_SHA" -- tests/ >"$RECORD/tests.diff"
  GUARD=$(gd tools/verify/record.gd -- guard "$RECORD/tests.diff") || fail "cannot read the test guard"
  # The ticket's earlier runs, replays aside, and the head of the latest one that failed.
  last_fail=""
  for d in $(cd "$TDIR" && ls -d */ 2>/dev/null | sed 's#/$##' | awk -F- '{print $2"-"$3" "$0}' | sort | cut -d' ' -f2); do
    [ "$TDIR/$d" != "$RECORD" ] && [ -f "$TDIR/$d/verdict.json" ] || continue
    jq -e 'has("replay_of")' "$TDIR/$d/inputs.json" >/dev/null 2>&1 && continue
    EARLIER=$(jq -c --arg d "$d" '. + [$d]' <<<"$EARLIER")
    jq -e 'any(.criteria[]?; .grade == "FAIL")' "$TDIR/$d/verdict.json" >/dev/null && last_fail=$(jq -r .binding.head_sha "$TDIR/$d/verdict.json")
  done
  if [ -n "$last_fail" ]; then
    # A failing head rebased away is gone; the whole change then stands in for what changed since.
    since=$last_fail
    git cat-file -e "$since^{commit}" 2>/dev/null || since=$BASE_SHA
    CHANGED=$(git diff --name-only "$since" "$HEAD_SHA" | jq -R -s -c 'split("\n") | map(select(length > 0))')
  fi
fi

"$KIT/drive.sh" "$RECORD" --prepare >"$RECORD/prepare.log" 2>&1 || { cat "$RECORD/prepare.log" >&2; fail "cannot prepare the head and base copies"; }
COPIES=$(cat "$RECORD/copies")

# Drives each probe file named on stdin from folder $1 into the record. Exits non-zero when one
# errors on head: refused by the lint, a non-zero exit, a SCRIPT ERROR or no PROBE line.
drive_all() {
  local from=$1 bad=0 p stem
  while read -r p; do
    [ -n "$p" ] || continue
    stem=${p%.gd}
    "$KIT/drive.sh" "$RECORD" "$from/$p" </dev/null 2>&1 | sed 's/^/  /'
    if [ "$(cat "$RECORD/drive/$stem.head.rc" 2>/dev/null)" != 0 ] || grep -q 'SCRIPT ERROR' "$RECORD/drive/$stem.head.log" \
      || ! grep -q '^PROBE ' "$RECORD/drive/$stem.head.log"; then
      echo "verify: the probe $p errors on head"
      bad=1
    fi
  done
  return $bad
}

# The probe files a grades.json cites, `*` read as every probe in folder $2.
cited() {
  gd tools/verify/record.gd -- probes "$1" | while read -r p; do
    if [ "$p" = "*" ]; then (cd "$2" && ls *.gd 2>/dev/null); elif [ -n "$p" ]; then echo "$p"; fi
  done | awk '!seen[$0]++'
}

if [ -n "$REPLAY" ]; then
  MODE=replay
  echo "verify: replaying the probes of $(basename "$REPLAY")"
  cited "$REPLAY/grades.json" "$REPLAY/probes" | drive_all "$REPLAY/probes"
  cp "$REPLAY/grades.json" "$RECORD/grades.json"
  VERIFIER_MODEL=$(jq -r .verifier_model "$REPLAY/inputs.json")
  write_inputs "$(jq -n --arg r "$(basename "$REPLAY")" '{started: false, why: "a replay of \($r)"}')"
  finish
fi

FROZEN=""
if [ "$FRESH" = 0 ] && [ -f "$TDIR/frozen" ]; then
  FROZEN=$TDIR/$(cat "$TDIR/frozen")
  if [ "$(jq -r .hash "$FROZEN/criteria.json" 2>/dev/null)" != "$CRITERIA_HASH" ]; then
    echo "verify: the criteria have been edited since the probes were frozen in $(basename "$FROZEN"); starting a verifier"
    FROZEN=""
  fi
fi
WHY_SESSION="the ticket has no frozen probes"
[ "$FRESH" = 1 ] && WHY_SESSION="--fresh"
if [ -n "$FROZEN" ]; then
  echo "verify: re-driving the frozen probes of $(basename "$FROZEN")"
  if cited "$FROZEN/grades.json" "$FROZEN/probes" | drive_all "$FROZEN/probes"; then
    MODE=redrive
    gd tools/verify/record.gd -- redrive "$FROZEN/grades.json" >"$RECORD/grades.json" || fail "cannot read $FROZEN/grades.json"
    VERIFIER_MODEL=$(jq -r .verifier_model "$FROZEN/inputs.json")
    write_inputs "$(jq -n --arg f "$(basename "$FROZEN")" '{started: false, why: "re-drove the frozen probes of \($f)", frozen_from: $f}')"
    finish
  fi
  WHY_SESSION="a frozen probe of $(basename "$FROZEN") errors on head"
  mv "$RECORD/drive" "$RECORD/frozen-drive"
  mv "$RECORD/probes" "$RECORD/frozen-probes"
fi

# The verifier session.
MODE=session
echo "verify: starting the verifier ($WHY_SESSION)"
SESS=$(mktemp -d "${TMPDIR:-/tmp/}frostmark-verifier.XXXXXX") || fail "cannot make a temp folder"
SESS=$(cd "$SESS" && pwd -P)
if (cd "$SESS" && env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --git-dir >/dev/null 2>&1); then
  fail "the temp folder $SESS is inside a repo: set TMPDIR to a folder outside every repo"
fi
WORK=$SESS/work
HEAD_COPY=$(cd "$COPIES/head" && pwd -P)
mkdir -p "$SESS/bin" "$WORK"
touch "$SESS/calls.log"

# The verifier's one command. It lives outside every folder the verifier can read or write.
cat >"$SESS/bin/drive" <<EOF
#!/bin/bash
# drive <probe.gd>: runs a probe from the work folder on the head and base copies.
n=\$((\$(wc -l <"$SESS/calls.log") + 1))
echo "\$n cwd=\$(pwd -P) git_vars=\$(env | grep -c '^GIT_') \$*" >>"$SESS/calls.log"
if [ "\$n" -gt $DRIVE_CAP ]; then
  touch "$SESS/capped-drive"
  echo "drive: refused: the cap of $DRIVE_CAP drive calls is reached, so this run is INCONCLUSIVE. Write grades.json and finish."
  exit 1
fi
[[ \$# -eq 1 && \$1 =~ ^[A-Za-z0-9_-]+\.gd\$ && -f "$WORK/\$1" ]] || { echo "drive: usage: drive <probe.gd>, a probe file in your work folder"; exit 1; }
exec "$KIT/drive.sh" "$RECORD" "$WORK/\$1"
EOF
# The hook that holds Bash to `drive <probe.gd>`, one call at a time.
cat >"$SESS/bin/only-drive" <<'EOF'
#!/bin/bash
perl -MJSON::PP -e '
  my $in = decode_json(join("", <STDIN>));
  my $cmd = $in->{tool_input}{command} // "";
  exit 0 if $cmd =~ m{\A\s*drive [A-Za-z0-9_-]+\.gd\s*\z};
  print STDERR "Bash runs only `drive <probe.gd>`, one call at a time, with nothing chained to it.\n";
  exit 2;'
EOF
chmod +x "$SESS/bin/drive" "$SESS/bin/only-drive"
jq -n --arg hook "$SESS/bin/only-drive" \
  '{hooks: {PreToolUse: [{matcher: "Bash", hooks: [{type: "command", command: $hook}]}]}}' >"$SESS/settings.json"

{
  cat "$KIT/verifier-brief.md"
  echo
  echo "## Your session"
  echo
  echo "- The head copy: \`$HEAD_COPY\`"
  echo "- Your work folder (the current folder): \`$WORK\`"
  echo "- The caps: $((SESSION_SECS / 60)) minutes and $DRIVE_CAP drive calls."
  echo
  echo "## The ticket: $(head -n 1 "$RECORD/ticket.md" | sed 's/^# //')"
  echo
  awk '/^##? /{h = tolower($0); keep = (h ~ /^## +what to build/ || h ~ /^## +acceptance criteria/)} keep' "$RECORD/ticket.md"
  echo
  echo "## The criteria, numbered"
  echo
  jq -r '.criteria[] | "- \(.id)\(if .tag != "" then " (\(.tag): not graded)" else "" end): \(.text)"' "$RECORD/criteria.json"
} >"$RECORD/prompt.md"

TOOLS="Read,Write,Glob,Grep,Bash"
session_start=$SECONDS
(
  cd "$WORK" || exit 1
  exec env -i HOME="$HOME" USER="${USER:-}" LOGNAME="${LOGNAME:-${USER:-}}" SHELL=/bin/bash \
    TMPDIR="${TMPDIR:-/tmp/}" LANG="${LANG:-en_US.UTF-8}" PATH="$SESS/bin:$PATH" \
    ${ANTHROPIC_API_KEY:+ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"} \
    perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]: $!\n"' "$SESSION_SECS" \
    claude --print --model "$MODEL" --restricted --tools "$TOOLS" \
    --allowedTools "Read" "Glob" "Grep" "Edit(./**)" "Bash(drive *)" \
    --settings "$SESS/settings.json" --permission-mode dontAsk --permission-prompts none \
    --add-dir "$HEAD_COPY" --strict-mcp-config --no-session-persistence --disable-slash-commands \
    --output-format stream-json --verbose <"$RECORD/prompt.md"
) >"$RECORD/transcript.jsonl" 2>"$RECORD/session.err"
rc=$?
wall=$((SECONDS - session_start))
cp "$SESS/calls.log" "$RECORD/drive-calls.log"
cp -R "$WORK" "$RECORD/work"

capped=""
[ "$rc" -eq 142 ] && capped="time"
[ -e "$SESS/capped-drive" ] && capped=${capped:-drive}
RESULT=$(jq -c -R 'fromjson? | select(.type == "result")' "$RECORD/transcript.jsonl" 2>/dev/null | tail -n 1)
[ -n "$RESULT" ] || RESULT="{}"
VERIFIER_MODEL=$(jq -r '(.modelUsage // {}) | keys | join(",") | if . == "" then "'"$MODEL"'" else . end' <<<"$RESULT")

FREEZE=0
if [ -n "$capped" ]; then
  [ -f "$WORK/grades.json" ] && cp "$WORK/grades.json" "$RECORD/grades.verifier.json"
  if [ "$capped" = time ]; then cap="its $((SESSION_SECS / 60))-minute cap"; else cap="its cap of $DRIVE_CAP drive calls"; fi
  jq -n --arg n "the verifier session hit $cap, so no criterion is graded" '{criteria: [], flags: [], notes: [$n]}' >"$RECORD/grades.json"
elif jq -e 'type == "object"' "$WORK/grades.json" >/dev/null 2>&1; then
  cp "$WORK/grades.json" "$RECORD/grades.json"
  FREEZE=1
else
  jq -n --arg n "the verifier session ended (exit $rc) without a readable grades.json" '{criteria: [], flags: [], notes: [$n]}' >"$RECORD/grades.json"
fi

write_inputs "$(jq -n --arg cwd "$WORK" --arg model "$MODEL" --arg tools "$TOOLS" --arg head "$HEAD_COPY" \
  --arg why "$WHY_SESSION" --argjson rc "$rc" --argjson wall "$wall" --arg capped "$capped" \
  --argjson secs "$SESSION_SECS" --argjson cap "$DRIVE_CAP" --argjson freeze "$FREEZE" \
  --argjson calls "$(wc -l <"$RECORD/drive-calls.log" | tr -d ' ')" \
  --argjson git_vars "$(awk '{sub("git_vars=", "", $3); if ($3 + 0 > m) m = $3 + 0} END {print m + 0}' "$RECORD/drive-calls.log")" \
  --argjson result "$RESULT" \
  '{started: true, why: $why, cwd: $cwd, model: $model, models_used: (($result.modelUsage // {}) | keys),
    tools: $tools, readable: [$cwd, $head], writable: [$cwd], bash: "drive <probe.gd> only",
    git_vars_seen_by_drive: $git_vars, exit: $rc, wall_secs: $wall, drive_calls: $calls,
    caps: {secs: $secs, drive_calls: $cap}, capped: (if $capped == "" then null else $capped end),
    frozen: ($freeze == 1), num_turns: $result.num_turns, cost_usd: $result.total_cost_usd,
    tokens: (($result.modelUsage // {}) | [.[]] | {
      input: (map(.inputTokens // 0) | add // 0), output: (map(.outputTokens // 0) | add // 0),
      cache_read: (map(.cacheReadInputTokens // 0) | add // 0),
      cache_creation: (map(.cacheCreationInputTokens // 0) | add // 0)}),
    permission_denials: (($result.permission_denials // []) | length)}')"
[ "$FREEZE" = 1 ] && basename "$RECORD" >"$TDIR/frozen"
echo "verify: the session took $wall s, $(jq -r .drive_calls "$RECORD/session.json") drive calls${capped:+, and hit its $capped cap}"
finish
