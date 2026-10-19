#!/bin/sh
# `swift` with the fixes this toolchain needs (ADR-017):  ./scripts/swift.sh test
. "$(dirname "$0")/sdk.sh"
CLT=/Library/Developer/CommandLineTools
case "${1:-}" in
  build|test|run)
    cmd=$1; shift
    # SwiftPM's build system records the deployment target (15.0) as the SDK version, so macOS would treat Hush as a
    # macOS 15 app (no new system look). Record the SDK actually used. Happens with Xcode too.
    v=$(xcrun ${SDKROOT:+--sdk "$SDKROOT"} --show-sdk-version 2>/dev/null)
    [ -n "$v" ] && set -- -Xlinker -platform_version -Xlinker macos -Xlinker 15.0 -Xlinker "$v" "$@"
    # CLT only: swift-testing's macro plugin sometimes goes missing ("plugin for module 'TestingMacros' not found")
    # and stays missing until a clean build; naming its folder fixes it.
    if [ "$(xcode-select -p 2>/dev/null)" = "$CLT" ]; then
      set -- -Xswiftc -plugin-path -Xswiftc "$CLT/usr/lib/swift/host/plugins/testing" "$@"
    fi
    exec swift "$cmd" "$@" ;;
esac
exec swift "$@"
