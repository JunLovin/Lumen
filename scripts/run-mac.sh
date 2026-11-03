#!/bin/sh
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$REPO_ROOT/apps/macos/build"

xcodebuild build \
  -project "$REPO_ROOT/apps/macos/Lumen.xcodeproj" \
  -scheme Lumen \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$BUILD_DIR" \
  -allowProvisioningUpdates \
  -quiet

APP_PATH="$BUILD_DIR/Build/Products/Debug/Lumen.app"
pkill -f "$APP_PATH" || true
while pgrep -f "$APP_PATH" >/dev/null; do
  sleep 0.1
done
open "$APP_PATH"
