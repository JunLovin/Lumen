#!/bin/sh
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

pnpm --filter @lumen/design-tokens test
pnpm generate
git diff --exit-code -- packages/design-tokens/generated packages/protocol/generated packages/LumenKit/Sources/LumenProtocol/Generated packages/LumenKit/Sources/LumenMacUI/Generated
