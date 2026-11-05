#!/bin/sh
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$REPO_ROOT/apps/macos/build"

xcodebuild build \
  -project "$REPO_ROOT/apps/macos/Lumen.xcodeproj" \
  -scheme Lumen \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$BUILD_DIR" \
  -quiet

pkill -f "$BUILD_DIR/Build/Products/Debug/Lumen.app" || true
open "$BUILD_DIR/Build/Products/Debug/Lumen.app"
