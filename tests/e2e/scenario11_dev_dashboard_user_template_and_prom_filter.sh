#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

jq -e '.templating.list[] | select(.name == "user" and .type == "query" and ((.query.query // .query) == "label_values(claude_code_cost_usage_USD_total, user_email)") and .includeAll == true)' dev-productivity-dashboard.json >/dev/null \
  || fail "dashboard must define query variable user with includeAll=true"

jq -e '[
  .panels[]
  | select((.datasource.uid // .datasource) == "prometheus")
  | .targets[]?
  | select(((.datasource.uid // .datasource // "prometheus") == "prometheus"))
  | .expr
  | contains("user_email=~\"$user\"")
] | all' dev-productivity-dashboard.json >/dev/null \
  || fail 'all Prometheus targets must use user_email=~"$user"'

echo "PASS: scenario11"
