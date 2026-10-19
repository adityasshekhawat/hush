#!/bin/sh
# `swift` with the SDK this Mac can build with (scripts/sdk.sh, ADR-017):  ./scripts/swift.sh test
# On a CLT-only Mac it also adds two fixes for build/test/run (ADR-017); with Xcode selected it's plain `swift`.
. "$(dirname "$0")/sdk.sh"
CLT=/Library/Developer/CommandLineTools
case "${1:-}" in
  build|test|run)
    if [ "$(xcode-select -p 2>/dev/null)" = "$CLT" ]; then
      cmd=$1; shift
      # swift-testing's macro plugin sometimes goes missing ("plugin for module 'TestingMacros' not found") and stays
      # missing until a clean build; naming its folder fixes it.
      set -- -Xswiftc -plugin-path -Xswiftc "$CLT/usr/lib/swift/host/plugins/testing" "$@"
      # The linker records the deployment target (15.0) as the SDK version, so macOS would treat Hush as a macOS 15 app
      # (no new system look). Record the SDK actually used.
      if [ -n "${SDKROOT:-}" ]; then
        v=$(sed -n 's/.*"Version"[[:space:]]*:[[:space:]]*"\([0-9.]*\)".*/\1/p' "$SDKROOT/SDKSettings.json" | head -1)
        [ -n "$v" ] && set -- -Xlinker -platform_version -Xlinker macos -Xlinker 15.0 -Xlinker "$v" "$@"
      fi
      exec swift "$cmd" "$@"
    fi ;;
esac
exec swift "$@"
