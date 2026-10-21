#!/bin/sh
# Publishes a release:  ./scripts/release.sh 0.2.0
# Sets the app's version, turns the changelog's "## Unreleased" into this version, commits, tags, pushes, and publishes
# a GitHub release with those notes. Hush's update check compares itself against these releases (ADR-036).
set -eu
cd "$(dirname "$0")/.."
V="${1:?usage: ./scripts/release.sh X.Y.Z}"
case "$V" in *[!0-9.]* | .* | *. | *..*) echo "A version is numbers and dots, like 0.2.0" >&2; exit 1 ;; esac
[ "$(git branch --show-current)" = main ] || { echo "Release from main." >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Commit or stash your changes first." >&2; exit 1; }
git pull --ff-only -q
grep -q '^## Unreleased$' CHANGELOG.md || { echo "CHANGELOG.md has no '## Unreleased' section to release." >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/v$V" >/dev/null; then echo "v$V already exists." >&2; exit 1; fi
CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/Hush/Info.plist)
LATEST=$(printf '%s\n%s\n' "$CURRENT" "$V" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
[ "$LATEST" = "$V" ] && [ "$V" != "$CURRENT" ] || { echo "$V isn't newer than $CURRENT." >&2; exit 1; }

BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Sources/Hush/Info.plist)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $V" -c "Set :CFBundleVersion $((BUILD + 1))" Sources/Hush/Info.plist
sed -i '' "s/^## Unreleased\$/## $V ($(date +%Y-%m-%d))/" CHANGELOG.md
NOTES=$(mktemp)
awk -v head="## $V " 'index($0, head) == 1 { f = 1; next } /^## / { f = 0 } f' CHANGELOG.md > "$NOTES"
printf '\n**Update:** click Update in the menu bar panel, or run `git pull --ff-only && ./scripts/bundle.sh` in the folder you cloned.\n' >> "$NOTES"

git commit -qam "Hush $V"
git tag -a "v$V" -m "Hush $V"
git push -q --follow-tags
gh release create "v$V" --title "Hush $V" --notes-file "$NOTES"
rm -f "$NOTES"
