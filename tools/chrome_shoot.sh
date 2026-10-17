#!/bin/zsh
# usage: fm-shoot.sh <url> <out_prefix> <rings...>
URL=$1; OUT=$2; shift 2
export CHROME_DEVTOOLS_AXI_HEADED=1
for ring in "$@"; do
  CODE=$(grep "^CODE $ring " /tmp/fm-ring-codes.txt | cut -d' ' -f3)
  sed "s#'\$CODE'#'$CODE'#" /tmp/fm-type-template.js > /tmp/fm-type-$ring.js
  for id in $(chrome-devtools-axi pages 2>/dev/null | grep -E '^\s+[0-9]+,' | cut -d, -f1 | tr -d ' '); do chrome-devtools-axi closepage $id >/dev/null 2>&1; done
  chrome-devtools-axi open "$URL" >/dev/null 2>&1
  chrome-devtools-axi resize 1440 900 >/dev/null 2>&1
  sleep 9
  chrome-devtools-axi eval "$(cat /tmp/fm-type-$ring.js)" 2>&1 | grep -E 'result|error'
  sleep 6
  chrome-devtools-axi screenshot "${OUT}_${ring}.png" 2>&1 | tail -1
  if [ "$ring" = "outpost" ]; then
    for rate in 1 4; do
      chrome-devtools-axi emulate --cpu $rate >/dev/null 2>&1
      sleep 2
      echo "fps cpu x$rate: $(chrome-devtools-axi eval "() => new Promise(r => { let n = 0; const t0 = performance.now(); const f = () => { n++; if (performance.now() - t0 < 5000) requestAnimationFrame(f); else r((n / ((performance.now() - t0) / 1000)).toFixed(1)); }; requestAnimationFrame(f); })" 2>&1 | grep result)"
    done
    chrome-devtools-axi emulate --cpu 1 >/dev/null 2>&1
  fi
  chrome-devtools-axi console --type error 2>&1 | grep -E 'Showing|error' | head -3
done
