#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

jq -e '.panels[] | select(.title == "Total cost (daily)") | .targets[] | select(.expr | contains("cc:cost_usd:daily"))' exec-roi-dashboard.json >/dev/null \
  || fail "total cost panel must use cc:cost_usd:daily"
jq -e '.panels[] | select(.title == "Cost per active hour") | .targets[] | select(.expr | contains("cc:cost_per_active_hour:daily"))' exec-roi-dashboard.json >/dev/null \
  || fail "cost per active hour must use cc:cost_per_active_hour:daily"
jq -e '.panels[] | select(.title == "Active time by type + adoption") | .targets[] | select(.expr | contains("cc:sessions:daily"))' exec-roi-dashboard.json >/dev/null \
  || fail "adoption panel must use cc:sessions:daily"

jq -e '.panels[] | select(.title == "Accepted edits over time") | ((.datasource.uid // .datasource) == "loki")' exec-roi-dashboard.json >/dev/null \
  || fail "Accepted edits panel must be Loki"

jq -e '.panels[] | select(.title == "Cost of rejected work ($)") | .targets[] | select(.refId == "A" and (.expr | contains("claude_code_cost_usage_USD_total")))' exec-roi-dashboard.json >/dev/null \
  || fail "cost of rejected work panel missing cost target"
jq -e '.panels[] | select(.title == "Cost of rejected work ($)") | .targets[] | select(.refId == "B" and (.expr | contains("decision=\"reject\"")))' exec-roi-dashboard.json >/dev/null \
  || fail "cost of rejected work panel missing reject-rate target"

! rg -q '\| json' exec-roi-dashboard.json \
  || fail "exec dashboard must not contain | json queries"

echo "PASS: scenario17"

