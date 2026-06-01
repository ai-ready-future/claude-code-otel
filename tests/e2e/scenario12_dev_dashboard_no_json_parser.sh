#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

! rg -q '\| json' dev-productivity-dashboard.json \
  || fail "dev dashboard must not contain | json queries"

rg -q 'decision=\\"accept\\"' dev-productivity-dashboard.json \
  || fail "missing Loki matcher for acceptance panel"
rg -q 'attempt > 1' dev-productivity-dashboard.json \
  || fail "missing Loki numeric comparator query"
rg -q 'success=\\"false\\".*unwrap duration_ms' dev-productivity-dashboard.json \
  || fail "missing unwrap duration_ms query"
rg -q 'decision=\\"reject\\"' dev-productivity-dashboard.json \
  || fail "missing reject matcher for interruption panel"

echo "PASS: scenario12"

