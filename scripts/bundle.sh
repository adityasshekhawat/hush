#!/bin/sh
# Builds build/Hush.app from the SwiftPM executable, without Xcode, then installs it to /Applications
# (quits the running copy, replaces it, relaunches). `./scripts/bundle.sh --no-install` only builds.
# A real bundle is needed for TCC: a bare `swift run` binary can't get its own Calendar permission prompt.
# Ad-hoc signed (no Developer ID yet), so it runs only on this Mac. See docs/decisions.md ADR-001.
set -eu

cd "$(dirname "$0")/.."

# Say what's missing in plain words, before a long build fails on it.
if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 15 ]; then
  echo "Hush needs macOS 15 or later; this Mac has $(sw_vers -productVersion)." >&2; exit 1
fi
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Hush is built with Swift. Install the Command Line Tools first:  xcode-select --install" >&2; exit 1
fi
. scripts/sdk.sh
INSTALL=1
CONFIG=release
for arg in "$@"; do
  case "$arg" in
    --no-install) INSTALL=0 ;;
    debug|release) CONFIG="$arg" ;;
  esac
done

scripts/swift.sh build -c "$CONFIG" --product Hush
scripts/swift.sh build -c "$CONFIG" --product hushctl
BINDIR="$(scripts/swift.sh build -c "$CONFIG" --show-bin-path)"
BIN="$BINDIR/Hush"

APP=build/Hush.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/assets"
cp "$BIN" "$APP/Contents/MacOS/Hush"
cp "$BINDIR/hushctl" "$APP/Contents/MacOS/hushctl"
cp Sources/Hush/Info.plist "$APP/Contents/Info.plist"
cp -R assets/character assets/renderer assets/brand assets/ui "$APP/Contents/Resources/assets/"

# App icon (design guide, logo/app-icon: lilac is primary). With Xcode: the layered Icon Composer icon
# (assets/brand/Hush.icon, v1 art), which macOS 26 draws in glass and actool flattens for older systems.
# Command Line Tools only: the flat PNGs.
if xcrun --find actool >/dev/null 2>&1 && xcrun actool assets/brand/Hush.icon --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 15.0 --app-icon Hush \
    --output-partial-info-plist "$(mktemp -d)/icon.plist" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string Hush" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconName Hush" "$APP/Contents/Info.plist"
else
  ICONSET="$(mktemp -d)/Hush.iconset"; mkdir -p "$ICONSET"; P=assets/brand/app-icon/hush-app-icon-lilac
  for s in 16 32 128 256 512; do
    cp "$P-$s.png" "$ICONSET/icon_${s}x${s}.png"
    cp "$P-$((s * 2)).png" "$ICONSET/icon_${s}x${s}@2x.png"
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Hush.icns"
fi

# The helper first: Apple silicon's linker signs every binary, Intel's doesn't, and an unsigned helper inside fails
# the check below.
codesign --force --sign - --timestamp=none "$APP/Contents/MacOS/hushctl"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"
echo "Built $APP"

if [ "$INSTALL" = 1 ]; then
  DEST=/Applications/Hush.app
  # Quit the running Hush (wherever it runs from) so the copy isn't replaced underneath it.
  if pgrep -x Hush >/dev/null; then
    pkill -x Hush
    while pgrep -x Hush >/dev/null; do sleep 0.2; done
  fi
  rm -rf "$DEST"
  ditto "$APP" "$DEST"
  echo "Installed $DEST"
  # On launch Hush points its Claude Code hooks at this copy (HookInstaller.migratePath).
  open "$DEST"
else
  echo "Run:  open $APP"
fi
