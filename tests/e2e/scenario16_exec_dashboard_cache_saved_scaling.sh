#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

jq -e '.panels[] | select(.title == "Cache $ saved") | .targets[] | select(.expr | contains("cacheRead") and contains("/ 1e6") and contains("($price_input_sonnet45 - $price_cacheread_sonnet45)"))' exec-roi-dashboard.json >/dev/null \
  || fail "Cache $ saved must include / 1e6 scaling and expected price delta"

echo "PASS: scenario16"

