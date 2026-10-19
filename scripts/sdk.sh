# Sourced by the build scripts: picks the SDK when building with Command Line Tools only (ADR-017).
# CLT 27's macOS 27 SDK turns SwiftUI's @State (and swift-testing's @Suite/@Test) into macros whose plugins ship only
# with Xcode, so builds fail with "plugin for module 'SwiftUIMacros' not found". The macOS 26 SDK that comes with the
# same CLT doesn't, and still has glassEffect and FoundationModels. With Xcode selected, or SDKROOT set, nothing changes.
if [ -z "${SDKROOT:-}" ] && [ "$(xcode-select -p 2>/dev/null)" = /Library/Developer/CommandLineTools ] &&
   [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk ] && [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX27.sdk ]; then
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
  export SDKROOT
fi
