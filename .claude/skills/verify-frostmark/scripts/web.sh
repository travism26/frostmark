#!/bin/bash
# Serves CI's web build of a commit on 127.0.0.1 and drives it in an isolated, throwaway Chrome
# through chrome-devtools-axi. Never the user's own Chrome: the browser save lives in that
# profile, and loading any save code overwrites it.
# usage: .claude/skills/verify-frostmark/scripts/web.sh <command> [args]
#   fetch [sha]          download CI's `frostmark-web` artifact for sha (default HEAD) once
#   serve [sha]          fetch, then serve it on a free port; prints the URL when index.html answers
#   doctor               read-only: our server is up, owns its port, serves the build we fetched,
#                        and the browser session is isolated. Exits 1 on any problem
#   open [query]         the session's one tab on the served build (query such as `?a=b`, from the code map),
#                        1440x900, waits for the canvas
#   import <ring>        on the open tab's title screen: pastes tools/ring_codes.txt's code for
#                        <ring> into Import code and clicks it (scripts/paste_import.js)
#   import --file <path> the same with the save code in <path> (the code map, an export)
#   continue             on the open tab's title screen with a browser save: clicks Continue
#                        (720, 320 at 1440x900) and waits for the game to load
#   shot <name>          screenshot plus console errors into the evidence folder
#   eval <js>            run JavaScript in the page (canvas input; see the Drive section)
#   stop                 stop the server and the browser session this script started
#
# The server's pid, port and sha are in $FROSTMARK_VERIFY_HOME/web/run/. Builds are cached in
# $FROSTMARK_VERIFY_HOME/web/<sha>/. Evidence goes to $FROSTMARK_VERIFY_HOME/web/evidence/<sha7>/
# and survives `stop`.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(git -C "$HERE" rev-parse --show-toplevel) || exit 1
HOME_DIR=${FROSTMARK_VERIFY_HOME:-${TMPDIR:-/tmp/}frostmark-verify-home}
WEB=$HOME_DIR/web
RUN=$WEB/run
export CHROME_DEVTOOLS_AXI_SESSION=frostmark-verify
unset CHROME_DEVTOOLS_AXI_AUTO_CONNECT CHROME_DEVTOOLS_AXI_USER_DATA_DIR CHROME_DEVTOOLS_AXI_BROWSER_URL

fail() {
  echo "web: $1" >&2
  exit 1
}

axi() {
  chrome-devtools-axi "$@"
}

full_sha() {
  git -C "$REPO" rev-parse --verify "${1:-HEAD}^{commit}" 2>/dev/null || fail "no commit ${1:-HEAD}"
}

fetch() {
  local sha run
  sha=$(full_sha "${1:-}")
  if [ -f "$WEB/$sha/index.html" ]; then
    echo "$WEB/$sha"
    return
  fi
  run=$(gh run list --repo travism26/frostmark --commit "$sha" --workflow ci.yml --status success \
    --json databaseId --jq '.[0].databaseId') || fail "gh could not list CI runs"
  [ -n "$run" ] || fail "no successful CI run for ${sha:0:7}: push it and wait for CI (there is no local web export)"
  mkdir -p "$WEB/$sha.partial"
  gh run download "$run" --repo travism26/frostmark -n frostmark-web -D "$WEB/$sha.partial" >&2 \
    || fail "cannot download frostmark-web from run $run"
  [ -f "$WEB/$sha.partial/index.html" ] || fail "the artifact of run $run has no index.html"
  echo "$run" >"$WEB/$sha.partial/.ci-run"
  mv "$WEB/$sha.partial" "$WEB/$sha"
  echo "$WEB/$sha"
}

port_owner() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | head -n 1
}

serve() {
  local sha dir port pid
  [ -f "$RUN/pid" ] && kill -0 "$(cat "$RUN/pid")" 2>/dev/null && fail "already serving on port $(cat "$RUN/port"): run stop first"
  sha=$(full_sha "${1:-}")
  dir=$(fetch "$sha") || exit 1
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  mkdir -p "$RUN"
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$dir" >"$RUN/server.log" 2>&1 &
  pid=$!
  echo "$pid" >"$RUN/pid"
  echo "$port" >"$RUN/port"
  echo "$sha" >"$RUN/sha"
  for _ in $(seq 1 50); do
    curl -fsS -o /dev/null "http://127.0.0.1:$port/index.html" 2>/dev/null && break
    sleep 0.2
  done
  curl -fsS -o /dev/null "http://127.0.0.1:$port/index.pck" || fail "the server on $port does not answer for index.pck"
  echo "url: http://127.0.0.1:$port/index.html (build ${sha:0:7}, pid $pid)"
}

doctor() {
  local bad=0 pid port sha
  pid=$(cat "$RUN/pid" 2>/dev/null) && port=$(cat "$RUN/port") && sha=$(cat "$RUN/sha") \
    || { echo "doctor: nothing served: run serve"; exit 1; }
  if kill -0 "$pid" 2>/dev/null; then echo "doctor: server pid $pid up"; else echo "doctor: server pid $pid is gone"; bad=1; fi
  if [ "$(port_owner "$port")" = "$pid" ]; then echo "doctor: port $port is ours"; else echo "doctor: port $port is not held by pid $pid"; bad=1; fi
  if curl -fsS -o /dev/null "http://127.0.0.1:$port/index.html"; then echo "doctor: index.html answers"; else echo "doctor: index.html does not answer"; bad=1; fi
  echo "doctor: build ${sha:0:7} from CI run $(cat "$WEB/$sha/.ci-run" 2>/dev/null || echo '?')"
  [ "$sha" = "$(git -C "$REPO" rev-parse HEAD)" ] || echo "doctor: note: HEAD is $(git -C "$REPO" rev-parse --short HEAD), not the served build"
  echo "doctor: browser session $CHROME_DEVTOOLS_AXI_SESSION, isolated profile (no auto-connect, no user data dir)"
  exit "$bad"
}

url() {
  [ -f "$RUN/port" ] || fail "nothing served: run serve"
  echo "http://127.0.0.1:$(cat "$RUN/port")/index.html${1:-}"
}

evidence_dir() {
  local d="$WEB/evidence/$(head -c 7 "$RUN/sha")"
  mkdir -p "$d" && echo "$d"
}

case ${1:-} in
  fetch) fetch "${2:-}" ;;
  serve) serve "${2:-}" ;;
  doctor) doctor ;;
  open)
    # One game tab at a time: a second WebGL tab starves the first, and newpage then loses the
    # bridge's selection. Close the game tabs, then navigate the session's blank first tab.
    for id in $(axi pages 2>/dev/null | grep -E '^ +[0-9]+,http' | cut -d, -f1 | tr -d ' '); do
      axi closepage "$id" >/dev/null 2>&1
    done
    first=$(axi pages 2>/dev/null | grep -E '^ +[0-9]+,' | head -n 1 | cut -d, -f1 | tr -d ' ')
    [ -n "$first" ] && axi selectpage "$first" >/dev/null
    axi open "$(url "${2:-}")" >/dev/null || fail "cannot open the build"
    axi resize 1440 900 >/dev/null
    axi wait 9000 >/dev/null
    axi eval "() => !!document.querySelector('canvas')" | grep -q true || fail "no canvas on the page"
    echo "opened $(url "${2:-}") at 1440x900"
    ;;
  import)
    case ${2:-} in
      "") fail "usage: web.sh import <ring> | --file <path>" ;;
      --file) code=$(tr -d ' \n\r\t' <"${3:?usage: web.sh import --file <path>}") || exit 1 ;;
      *) code=$(grep "^CODE $2 " "$REPO/tools/ring_codes.txt" | cut -d' ' -f3) ;;
    esac
    [ -n "$code" ] || fail "no save code for ${2}${3:+ $3}"
    axi eval "$(sed "s#\$CODE#$code#g" "$HERE/paste_import.js")" | grep -q 'clicked Import code' || fail "the paste did not run"
    axi wait 8000 >/dev/null
    echo "imported ${3:-$2}"
    ;;
  continue)
    # Continue only exists with a browser save; on a fresh profile this point is empty title screen.
    axi eval "() => { const c = document.querySelector('canvas'); for (const t of ['mousemove','mousedown','mouseup']) c.dispatchEvent(new MouseEvent(t, {bubbles:true, clientX:720, clientY:320, button:0, buttons: t==='mouseup'?0:1})); return 'clicked Continue'; }" \
      | grep -q 'clicked Continue' || fail "the click did not run"
    axi wait 8000 >/dev/null
    echo "clicked Continue"
    ;;
  shot)
    [ -n "${2:-}" ] || fail "usage: web.sh shot <name>"
    d=$(evidence_dir)
    axi screenshot "$d/$2.png" | tail -n 1
    axi console --type error >"$d/$2.console.txt" 2>&1
    if grep -q 'no console messages found' "$d/$2.console.txt"; then
      echo "console errors: none"
    else
      echo "console errors: see $d/$2.console.txt"
    fi
    ;;
  eval) axi eval "${2:?usage: web.sh eval <js>}" ;;
  stop)
    if [ -f "$RUN/pid" ]; then
      pid=$(cat "$RUN/pid")
      if [ "$(port_owner "$(cat "$RUN/port")")" = "$pid" ]; then kill "$pid"; fi
      rm -f "$RUN/pid" "$RUN/port" "$RUN/sha"
    fi
    axi stop >/dev/null 2>&1
    echo "stopped; evidence kept in $WEB/evidence/"
    ;;
  *) fail "usage: web.sh fetch|serve|doctor|open|import|continue|shot|eval|stop (see the header)" ;;
esac
