#!/bin/zsh
# Screenshot the game in each ring from a served web build, through chrome-devtools-axi.
# usage: tools/chrome_shoot.sh <url> <out_prefix> <rings...>
#   e.g. tools/chrome_shoot.sh http://127.0.0.1:8012/index.html /tmp/fm-after outpost inner_ring ring_one ring_two
# For each ring: open the build in a NEW tab (other tabs, such as a Lavish board, are left
# alone), type the ring's save code from ring_codes.txt into the title screen's import box,
# click Import, settle, screenshot, then close that tab. Keep one other tab open: the bridge
# loses its selection when the last tab closes. The outpost shot also measures fps at CPU x1
# and x4. Prints console errors, if any, per ring. The eval that types the code reports
# "timed out" but completes.
URL=$1; OUT=$2; shift 2
HERE=${0:a:h}
export CHROME_DEVTOOLS_AXI_HEADED=1
for ring in "$@"; do
  CODE=$(grep "^CODE $ring " "$HERE/ring_codes.txt" | cut -d' ' -f3)
  JS=$(sed "s#'\$CODE'#'$CODE'#" "$HERE/chrome_type_import.js")
  BEFORE=$(chrome-devtools-axi pages 2>/dev/null | grep -E '^\s+[0-9]+,' | cut -d, -f1 | tr -d ' ')
  chrome-devtools-axi newpage "$URL" >/dev/null 2>&1
  PAGE=$(chrome-devtools-axi pages 2>/dev/null | grep -E '^\s+[0-9]+,.*true$' | cut -d, -f1 | tr -d ' ')
  chrome-devtools-axi resize 1440 900 >/dev/null 2>&1
  sleep 9
  chrome-devtools-axi eval "$JS" 2>&1 | grep -E 'result|error'
  sleep 6
  chrome-devtools-axi screenshot "${OUT}_${ring}.png" 2>&1 | tail -1
  if [ "$ring" = "outpost" ]; then
    for rate in 1 4; do
      chrome-devtools-axi emulate --cpu $rate >/dev/null 2>&1
      sleep 2
      echo "fps cpu x$rate: $(chrome-devtools-axi eval "() => new Promise(r => { let n = 0; const t0 = performance.now(); const f = () => { n++; if (performance.now() - t0 < 5000) requestAnimationFrame(f); else r((n / ((performance.now() - t0) / 1000)).toFixed(1)); }; requestAnimationFrame(f); })" 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    done
    chrome-devtools-axi emulate --cpu 1 >/dev/null 2>&1
  fi
  echo "console errors ($ring): $(chrome-devtools-axi console --type error 2>&1 | head -2 | tr '\n' ' ')"
  if [ -n "$PAGE" ] && ! echo "$BEFORE" | grep -qx "$PAGE"; then
    chrome-devtools-axi closepage "$PAGE" >/dev/null 2>&1
  fi
done
