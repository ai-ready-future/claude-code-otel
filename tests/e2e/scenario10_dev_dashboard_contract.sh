#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

jq -e '.uid == "claude-code-dev-productivity"' dev-productivity-dashboard.json >/dev/null \
  || fail "unexpected dev dashboard uid"
jq -e '.title == "Developer Productivity"' dev-productivity-dashboard.json >/dev/null \
  || fail "unexpected dev dashboard title"
jq -e '(.version | type) == "number" and (.version == (.version | floor))' dev-productivity-dashboard.json >/dev/null \
  || fail "dev dashboard version must be an integer"

echo "PASS: scenario10"
