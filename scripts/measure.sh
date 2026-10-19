#!/bin/bash
# Measures Hush's real cost for a while: CPU time used by Hush and its WebKit helpers (from `ps` CPU-time deltas, not
# the decaying %CPU column), and their memory. Leave the Mac alone while it runs; moving the mouse near Hush wakes it.
#   ./scripts/measure.sh            40 s in whatever state Hush is in now
#   ./scripts/measure.sh 120
# States to measure (docs/performance.md): idle, alerting (Settings ▸ Developer ▸ Meeting in 2 min), battery mode
# (Low Power Mode on), paused (menu bar ▸ Pause), locked (lock the screen; run with a delay: sleep 5; …).
set -eu
SECS=${1:-40}
HUSH=$(pgrep -x Hush) || { echo "Hush isn't running"; exit 1; }
started() { date -j -f "%a %b %d %T %Y" "$(ps -o lstart= -p "$1" | xargs)" +%s; }
hstart=$(started "$HUSH")
pids="$HUSH"
# Hush's WebKit helpers start within a few seconds of it.
for p in $(pgrep -f 'com.apple.WebKit' || true); do
  s=$(started "$p" 2>/dev/null) || continue
  d=$((s - hstart)); if [ $d -ge 0 ] && [ $d -le 15 ]; then pids="$pids $p"; fi
done
list=$(echo $pids | tr ' ' ',')
cpu() { ps -o time= -p "$list" | awk -F'[:.]' '{ s += $1*60 + $2 + $3/100 } END { printf "%.2f", s }'; }
a=$(cpu); sleep "$SECS"; b=$(cpu)
rss=$(ps -o rss= -p "$list" | awk '{ s += $1 } END { printf "%.0f", s/1024 }')
idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ { printf "%.0f", $NF/1e9; exit }')
echo "$(echo "$b $a $SECS" | awk '{ printf "%.2f", ($1-$2)/$3*100 }')% CPU (one core = 100%) · ${rss} MB · $(echo $pids | wc -w | tr -d ' ') processes · ${SECS}s · no input for the last ${idle}s"
