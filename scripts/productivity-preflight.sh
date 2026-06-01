#!/usr/bin/env bash
set -euo pipefail

LOKI_URL="${LOKI_URL:-http://localhost:3100}"
LOKI_CONTAINER="${LOKI_CONTAINER:-loki}"
LOKI_CONFIG_PATH="${LOKI_CONFIG_PATH:-/etc/loki/config.yaml}"

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

# 12.1a: schema store gate (local Loki container by default).
docker exec "$LOKI_CONTAINER" cat "$LOKI_CONFIG_PATH" > /tmp/loki-running-config.yaml
rg -q 'store: tsdb' /tmp/loki-running-config.yaml || rg -q 'store: boltdb-shipper' /tmp/loki-running-config.yaml || fail "Loki schema store is not shipper-based"
rg -q 'period:\s*24h' /tmp/loki-running-config.yaml || fail "Loki schema index period is not 24h"
pass "12.1a schema gate"

loki_query() {
  local q="$1"
  curl -fsG "${LOKI_URL}/loki/api/v1/query" --data-urlencode "query=${q}"
}

assert_non_empty() {
  local label="$1"
  local query="$2"
  local result
  result="$(loki_query "$query")"
  jq -e '.data.result | length > 0' <<<"$result" >/dev/null || fail "${label} returned empty result"
  pass "$label"
}

# 12.1b: structured metadata matcher + numeric comparator + unwrap gate.
assert_non_empty "12.1b matcher gate" 'sum(count_over_time({event="tool_decision"} | decision="accept" [1h]))'
assert_non_empty "12.1b numeric gate" 'sum(count_over_time({event="api_error"} | attempt > 1 [1h]))'
assert_non_empty "12.1b unwrap gate" 'sum(sum_over_time({event="tool_result"} | success="false" | unwrap duration_ms [1h]))'

# 12.1c: user_email scoping gate.
assert_non_empty "12.1c user_email gate" 'sum(count_over_time({event="tool_decision"} | user_email!="" [1h]))'

echo "PASS: all productivity dashboard pre-flight checks"
