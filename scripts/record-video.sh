#!/bin/bash
# Records the website's product video from the running Hush (developer tool, ADR-031). Like record-media.sh, Hush draws
# every frame itself (MediaRecorder, debug hooks): only Hush, its cards and a drawn desktop are in it, never a real
# window, tab or wallpaper. Agents, meetings and mail are simulated and removed afterwards; Hand it to Hush and Ask Hush
# run for real. Leave the Mac alone while it runs (about 2½ minutes). Your clipboard, look, Hush's spot and settings are
# put back. Output: site/media/hush-demo.mp4 (and a poster frame next to it).
set -u
cd "$(dirname "$0")/.."
REC="$HOME/Library/Application Support/Hush/recordings"
SOCK="$HOME/Library/Application Support/Hush/agent.sock"
# The command goes in as JSON, so captions can carry apostrophes.
post() { osascript -l JavaScript -e "ObjC.import('Foundation'); \$.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately('dev.hush.debug', $(printf '%s' "$1" | python3 -I -c 'import json,sys; print(json.dumps(sys.stdin.read()))'), \$(), true)" >/dev/null; }
agent() { python3 -I - "$SOCK" "$@" <<'PY'
import socket, sys, json
p, ev = sys.argv[1], json.loads(sys.argv[2])
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(p); s.sendall((json.dumps(ev) + "\n").encode()); s.close()
PY
}
# Scripted sessions use the demo prefix, so `cleandemo` takes them out of the journal afterwards.
S=0193aaaa-0000-0000-0000-00000000b00
ev() { agent "{\"v\":\"1\",\"event\":\"$1\",\"session\":\"$S$2\",\"cwd\":\"/Users/you/Developer/$3\",\"app\":\"com.googlecode.iterm2\"${4:-}}"; }
scene() { post "caption:$1"; sleep 0.3; }
# Dismiss, never shoo: a shoo teaches Hush to lower that kind of item.
reset() { post "dismiss"; post "envelope:close"; post "pose:live"; post "pile:0"; post "bubbles"; sleep 1.2; }

was_hooks=$(defaults read dev.hush.Hush HushDebugHooks 2>/dev/null || echo 0)
had_consent=$(defaults read dev.hush.Hush pouchConsent 2>/dev/null || echo none)
home_was=$(defaults read dev.hush.Hush homeX 2>/dev/null || echo 0.92)
saved=$(mktemp); pbpaste > "$saved"
defaults write dev.hush.Hush HushDebugHooks -bool YES
defaults write dev.hush.Hush pouchConsent -bool YES
pkill -x Hush; while pgrep -x Hush >/dev/null; do sleep 0.2; done; sleep 1; open /Applications/Hush.app; sleep 7
post "look:brand"; post "home:0.5"; sleep 6; reset

post "video:start:hush-demo"; sleep 0.5

scene "Meet Hush|A small, silent friend at the edge of your Mac"
post "seq:arrival"; sleep 4; post "react:hover"; sleep 2; post "react:unhover"; sleep 1.5

scene "It plays when you're idle|Pat it, poke it, fling it"
post "react:pat"; sleep 2.2; post "react:unpat"; sleep 1
for i in 1 2 3 4 5; do post "click"; sleep 0.25; done; sleep 3
post "react:lift"; for i in 1 2 3 4; do post "react:swing"; sleep 0.35; done; post "react:drop"; sleep 3.5

scene "It perches on your windows"
post "stage:open"; sleep 1; post "move:perch"; sleep 6; post "move:leave"; sleep 2.5; post "stage:close"; sleep 1

scene "It ducks while you type"
post "pose:09-hide"; sleep 3; post "pose:live"; sleep 1.5

scene "Hand it to Hush|Copy text, click Hush, pick Simpler, Shorter or Bullets. On your Mac."
printf '%s' "Pursuant to our previous correspondence, we are writing to inform you that the remittance for invoice 4471 has not been received and is now 14 days past the due date." | pbcopy
sleep 2.5; post "pouchopen"; sleep 2.2; post "pouch:simpler"; sleep 6; post "antic:blow"; sleep 2; reset

scene "Ask anything with ⌘⇧H|One answer, shaped to the question"
post "box:how many miles is 42 km"; sleep 2.5; post "ask:how many miles is 42 km"; sleep 1; post "boxclose"; sleep 4
post "caption:-"; sleep 6   # the answer card rises into the title's space
post "answer:close"; post "envelope:close"; reset

scene "It knows when your agents need you|Claude Code and Codex, through hooks you approve"
ev prompt 1 web; ev needsYou 1 web ',"tool":"Bash","detail":"npm test"'; sleep 3.5
ev prompt 2 api; ev needsYou 2 api ',"tool":"Bash","detail":"rm -rf build && ./migrate.sh --env prod"'; sleep 3; post "click"; sleep 3.5
post "envelope:close"
scene "Finished runs line up as flags|Click one to go straight to it"
# Runs under 2 minutes don't get a card, so these started "5 minutes ago" (the debug hook backdates them).
post "agent:prompt:${S}3:old:site"; post "agent:stop:${S}3:now:site"; sleep 3
post "agent:prompt:${S}4:old:docs"; post "agent:stop:${S}4:now:docs"; sleep 4
for i in 1 2 3 4; do ev end $i x; done; reset

scene "It remembers your meetings|A heads-up 5 minutes before, then it holds the door"
post "meeting:4"; sleep 4.5; post "click"; sleep 3.5; post "envelope:close"; reset
post "meeting:1"; sleep 5; post "seq:snooze"; sleep 2.5; reset

scene "Mail waits for a natural break|Simulated: the Apple Mail extension is next"
for m in ordinary ordinary bulk ordinary; do post "mail:$m"; sleep 0.6; done; reset
post "maildigest"; sleep 4.5; post "click"; sleep 3.5; reset

scene "Pause it, and it pulls the blind"
post "pause:quarterHour"; sleep 4.5; post "resume"; sleep 3.5

scene "Kind to your battery"
post "saver:on"; sleep 4.5; post "saver:off"; sleep 1.5

scene "Music, mornings, screenshots"
post "antic:groove"; sleep 3; post "antic:ungroove"; sleep 0.5; post "antic:morning"; sleep 3.5; post "antic:shot"; sleep 1.5

scene "Make it yours|Three bodies, nine colours, a wardrobe of 46 pieces"
# Every slot named, so only these pieces show (the preview starts from your saved look).
for look in "body=bean,palette=mint,head=nightcap,face=none,neck=none,carry=none,buddy=none" \
            "body=square,palette=sky,head=headphones,face=none,neck=scarf,carry=none,buddy=none" \
            "body=blob,palette=rose,head=crown,face=shades,neck=none,carry=none,buddy=none" \
            "body=bean,palette=butter,head=frogHat,face=none,neck=none,carry=coffee,buddy=none"; do
  post "wear:$look,topper=leaf,eyes=round"; sleep 1.6
done
post "look:brand"; sleep 1

scene "Flick it away, and it learns"
post "variant:08-bow"; sleep 1.6; post "pose:live"; post "variant:01-peek"; sleep 1.5

scene "At the end of the day|It tells you how much it spared you"
post "heldback:day"; sleep 5; post "bubbles"; reset

scene "Hush|Recorded from the app. Agents, meetings and mail are simulated."
sleep 3.5
post "video:stop"; sleep 3

# Leave no trace: simulated items, Hush's spot, your look, clipboard and settings.
post "dismiss"; post "cleandemo"; post "stage:close"; sleep 1
post "home:$home_was"; post "look:restore"; sleep 1
pbcopy < "$saved"; rm -f "$saved"
if [ "$had_consent" = none ]; then defaults delete dev.hush.Hush pouchConsent 2>/dev/null; else defaults write dev.hush.Hush pouchConsent -bool "$([ "$had_consent" = 1 ] && echo YES || echo NO)"; fi
if [ "$was_hooks" = 1 ]; then :; else defaults delete dev.hush.Hush HushDebugHooks 2>/dev/null; fi

mkdir -p site/media
if [ -f "$REC/hush-demo.mp4" ]; then
  cp "$REC/hush-demo.mp4" site/media/hush-demo.mp4
  echo "site/media/hush-demo.mp4 ($(du -h site/media/hush-demo.mp4 | cut -f1))"
else
  echo "no video was written; see ~/Library/Application Support/Hush/diagnostics.log" >&2; exit 1
fi
