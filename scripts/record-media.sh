#!/bin/bash
# Records the README's feature GIFs from the running Hush (developer tool). Hush draws them itself (MediaRecorder,
# debug hooks), so no screen-recording permission is needed. Leave the Mac alone while it runs (about 2 minutes):
# typing or moving the mouse near Hush changes what it does. Your clipboard is saved and put back.
#   ./scripts/record-media.sh            all scenarios → docs/media/*.gif
#   ./scripts/record-media.sh agents     just one
set -u
cd "$(dirname "$0")/.."
REC="$HOME/Library/Application Support/Hush/recordings"
SOCK="$HOME/Library/Application Support/Hush/agent.sock"
post() { osascript -l JavaScript -e "ObjC.import('Foundation'); \$.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately('dev.hush.debug', '$1', \$(), true)" >/dev/null; }
agent() { python3 -I - "$SOCK" "$@" <<'PY'
import socket, sys, json
p, ev = sys.argv[1], json.loads(sys.argv[2])
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(p); s.sendall((json.dumps(ev) + "\n").encode()); s.close()
PY
}
start() { post "record:start:$1"; sleep 0.6; }
stop() { sleep 0.4; post "record:stop"; sleep 1.5; cp "$REC/$1.gif" "docs/media/demo-$1.gif" && echo "docs/media/demo-$1.gif"; }
# Dismiss, never shoo: a shoo teaches Hush to lower that kind of item.
reset() { post "dismiss"; post "pose:live"; post "pile:0"; post "bubbles"; sleep 1.5; }

was_hooks=$(defaults read dev.hush.Hush HushDebugHooks 2>/dev/null || echo 0)
had_consent=$(defaults read dev.hush.Hush pouchConsent 2>/dev/null || echo none)
defaults write dev.hush.Hush HushDebugHooks -bool YES
pkill -x Hush; while pgrep -x Hush >/dev/null; do sleep 0.2; done; sleep 1; open /Applications/Hush.app; sleep 7
# The brand look for the README (preview only; your saved look is untouched).
# The brand look for the README; your own look is saved first and restored at the end.
post "look:brand"; sleep 1.5
only="${1:-}"
want() { [ -z "$only" ] || [ "$only" = "$1" ]; }

# Play first: after the pouch scenario copies text, clicks open the verb card for 2 minutes (ADR-020).
if want play; then
  reset; start play
  post "react:hover"; sleep 1.2; post "react:unhover"; sleep 0.6
  for i in 1 2 3 4 5; do post "click"; sleep 0.25; done
  sleep 3.5; post "react:pat"; sleep 2.2; post "react:unpat"; sleep 1.5
  stop play
fi

if want agents; then
  reset; start agents
  agent '{"v":"1","event":"prompt","session":"0193aaaa-0000-0000-0000-00000000a001","cwd":"/Users/you/Developer/web","app":"com.googlecode.iterm2"}'
  agent '{"v":"1","event":"needsYou","session":"0193aaaa-0000-0000-0000-00000000a001","cwd":"/Users/you/Developer/web","app":"com.googlecode.iterm2","tool":"Bash","detail":"npm test"}'
  sleep 1.5
  agent '{"v":"1","event":"needsYou","session":"0193aaaa-0000-0000-0000-00000000a002","cwd":"/Users/you/Developer/api","app":"com.googlecode.iterm2","tool":"Bash","detail":"rm -rf build && ./migrate.sh --env prod"}'
  sleep 2.5; post "click"; sleep 4.5
  stop agents
  agent '{"v":"1","event":"end","session":"0193aaaa-0000-0000-0000-00000000a001","cwd":"/Users/you/Developer/web"}'
  agent '{"v":"1","event":"end","session":"0193aaaa-0000-0000-0000-00000000a002","cwd":"/Users/you/Developer/api"}'
fi

if want meeting; then
  reset; start meeting
  post "meeting:4"; sleep 3; post "click"; sleep 5
  stop meeting
fi

if want digest; then
  reset
  for m in ordinary ordinary bulk ordinary; do post "mail:$m"; sleep 2.5; done
  start digest
  post "maildigest"; sleep 3; post "click"; sleep 4.5
  stop digest
fi

if want pause; then
  reset; start pause
  sleep 1; post "pause:quarterHour"; sleep 4; post "resume"; sleep 3
  stop pause
fi

if want pouch; then
  saved=$(mktemp); pbpaste > "$saved"
  defaults write dev.hush.Hush pouchConsent -bool YES
  reset; start pouch
  printf '%s' "Pursuant to our previous correspondence, we are writing to inform you that the remittance for invoice 4471 has not been received and is now 14 days past the due date." | pbcopy
  sleep 2; post "pouchopen"; sleep 2.2; post "pouch:simpler"; sleep 6
  stop pouch
  pbcopy < "$saved"; rm -f "$saved"
  if [ "$had_consent" = none ]; then defaults delete dev.hush.Hush pouchConsent 2>/dev/null; else defaults write dev.hush.Hush pouchConsent -bool "$([ "$had_consent" = 1 ] && echo YES || echo NO)"; fi
fi

# Leave no trace in the journal, counts or learning.
post "dismiss"; post "cleandemo"; sleep 1
post "pile:0"
post "look:restore"
if [ "$was_hooks" = 1 ]; then :; else defaults delete dev.hush.Hush HushDebugHooks 2>/dev/null; fi
