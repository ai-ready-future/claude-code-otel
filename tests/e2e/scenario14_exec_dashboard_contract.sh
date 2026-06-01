#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

jq -e '.uid == "claude-code-exec-roi"' exec-roi-dashboard.json >/dev/null \
  || fail "unexpected exec dashboard uid"
jq -e '.title == "Executive / ROI"' exec-roi-dashboard.json >/dev/null \
  || fail "unexpected exec dashboard title"
jq -e '(.version | type) == "number" and (.version == (.version | floor))' exec-roi-dashboard.json >/dev/null \
  || fail "exec dashboard version must be an integer"

echo "PASS: scenario14"
