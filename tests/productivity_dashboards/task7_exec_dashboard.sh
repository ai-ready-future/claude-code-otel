#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

test -f exec-roi-dashboard.json || fail "exec-roi-dashboard.json missing"

jq -e '.uid == "claude-code-exec-roi"' exec-roi-dashboard.json >/dev/null || fail "wrong dashboard uid"
jq -e '.title == "Executive / ROI"' exec-roi-dashboard.json >/dev/null || fail "wrong dashboard title"

for var in user price_input_sonnet45 price_output_sonnet45 price_cacheread_sonnet45 price_cachewrite_sonnet45
do
  jq -e --arg v "$var" '.templating.list[] | select(.name == $v)' exec-roi-dashboard.json >/dev/null \
    || fail "missing template variable: $var"
done

jq -e '.panels[] | select(.title == "Cache $ saved") | .targets[] | select(.expr | contains("/ 1e6"))' exec-roi-dashboard.json >/dev/null \
  || fail "E10 formula missing / 1e6 scaling"

for composite in "Quality-adjusted activity" "Cost of rejected work ($)" "Output per prompt"
do
  jq -e --arg t "$composite" '.panels[] | select(.title == $t) | .transformations | length > 0' exec-roi-dashboard.json >/dev/null \
    || fail "missing transform chain for composite panel: $composite"
done

for panel in \
  "Leverage multiplier (Nx)" \
  "Quality-adjusted activity" \
  "Total cost (daily)" \
  "Cost per active hour" \
  "Cost of rejected work ($)" \
  "Accepted edits over time" \
  "Output per prompt" \
  "Spend by model and query_source" \
  "Cache $ saved" \
  "Active time by type + adoption"
do
  jq -e --arg t "$panel" '.panels[] | select(.title == $t)' exec-roi-dashboard.json >/dev/null \
    || fail "missing panel: $panel"
done

! rg -q 'claude_code_lines_of_code_count_total|claude_code_commit_count_total|claude_code_pull_request_count_total|claude_code_code_edit_tool_decision_count_total' exec-roi-dashboard.json \
  || fail "dashboard references unsupported metrics"

! rg -q '\| json' exec-roi-dashboard.json || fail "dashboard uses forbidden | json parser"

echo "PASS: executive dashboard contract"
