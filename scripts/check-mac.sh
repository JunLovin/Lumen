#!/bin/sh
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
KIT_DIR="$REPO_ROOT/packages/LumenKit"
cd "$REPO_ROOT"

swiftformat --lint .
swiftlint lint --quiet
swift build --package-path "$KIT_DIR" --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors
swift test --package-path "$KIT_DIR" --explicit-target-dependency-import-check error
xcodebuild build \
  -project apps/macos/Lumen.xcodeproj \
  -scheme Lumen \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  -quiet
