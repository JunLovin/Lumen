#!/bin/sh
set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
KIT_DIR="$REPO_ROOT/packages/LumenKit"
DOMAIN_FILE="$KIT_DIR/Sources/LumenDomain/ProtocolVersion.swift"
BACKUP=$(mktemp)
FAILED=0
cp "$DOMAIN_FILE" "$BACKUP"
trap 'cp "$BACKUP" "$DOMAIN_FILE"; rm -f "$BACKUP"' EXIT

expect_eslint_rejects() {
  file=$1
  source=$2
  if printf '%s\n' "$source" | (cd "$REPO_ROOT/apps/ios" && pnpm exec eslint --stdin --stdin-filename "$file" >/dev/null 2>&1); then
    echo "NOT REJECTED: $file <- $source"
    FAILED=1
  fi
}

expect_eslint_rejects src/domain/violation.ts "import { Text } from 'react-native'; export const x = Text;"
expect_eslint_rejects src/domain/violation.ts "import { createLoadDiagnostics } from '../application/load-diagnostics'; export const x = createLoadDiagnostics;"
expect_eslint_rejects src/application/violation.ts "import { createRuntimeInfoAdapter } from '../adapters/runtime-info-adapter'; export const x = createRuntimeInfoAdapter;"
expect_eslint_rejects src/ui/violation.ts "import { createRuntimeInfoAdapter } from '../adapters/runtime-info-adapter'; export const x = createRuntimeInfoAdapter;"

printf 'import LumenProtocol\n' | cat - "$BACKUP" > "$DOMAIN_FILE"
if swift build --package-path "$KIT_DIR" --explicit-target-dependency-import-check error >/dev/null 2>&1; then
  echo "NOT REJECTED: LumenDomain imports LumenProtocol"
  FAILED=1
fi

[ "$FAILED" -eq 0 ] && echo "All boundary violations were rejected."
exit "$FAILED"
