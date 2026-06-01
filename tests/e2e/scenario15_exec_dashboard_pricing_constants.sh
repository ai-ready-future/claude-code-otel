#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

jq -e '.templating.list[] | select(.name == "price_input_sonnet45" and .type == "constant" and .query == "3.00")' exec-roi-dashboard.json >/dev/null \
  || fail "missing price_input_sonnet45 constant"
jq -e '.templating.list[] | select(.name == "price_output_sonnet45" and .type == "constant" and .query == "15.00")' exec-roi-dashboard.json >/dev/null \
  || fail "missing price_output_sonnet45 constant"
jq -e '.templating.list[] | select(.name == "price_cacheread_sonnet45" and .type == "constant" and .query == "0.30")' exec-roi-dashboard.json >/dev/null \
  || fail "missing price_cacheread_sonnet45 constant"
jq -e '.templating.list[] | select(.name == "price_cachewrite_sonnet45" and .type == "constant" and .query == "3.75")' exec-roi-dashboard.json >/dev/null \
  || fail "missing price_cachewrite_sonnet45 constant"
jq -e '.templating.list[] | select(.name == "user" and .type == "query")' exec-roi-dashboard.json >/dev/null \
  || fail "missing user query variable"

echo "PASS: scenario15"

