#!/bin/sh
set -eu

PROTOCOL_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$PROTOCOL_DIR/../.." && pwd)
KIT_DIR="$REPO_ROOT/packages/LumenKit"
SWIFT_OUT="$KIT_DIR/Sources/LumenProtocol/Generated"
TS_OUT="$PROTOCOL_DIR/generated"

swift build --package-path "$KIT_DIR" --product protoc-gen-swift
SWIFT_PLUGIN="$(swift build --package-path "$KIT_DIR" --show-bin-path)/protoc-gen-swift"

protoc \
  --proto_path="$PROTOCOL_DIR/proto" \
  --plugin=protoc-gen-swift="$SWIFT_PLUGIN" \
  --swift_out="$SWIFT_OUT" \
  --swift_opt=Visibility=Public \
  --plugin=protoc-gen-ts_proto="$REPO_ROOT/node_modules/.bin/protoc-gen-ts_proto" \
  --ts_proto_out="$TS_OUT" \
  --ts_proto_opt=outputServices=false,esModuleInterop=true,exportCommonSymbols=false,annotateFilesWithVersion=false \
  "$PROTOCOL_DIR"/proto/*.proto
