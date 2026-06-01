#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

test -f dev-productivity-dashboard.json || fail "dev-productivity-dashboard.json missing"

jq -e '.uid == "claude-code-dev-productivity"' dev-productivity-dashboard.json >/dev/null || fail "wrong dashboard uid"
jq -e '.title == "Developer Productivity"' dev-productivity-dashboard.json >/dev/null || fail "wrong dashboard title"
jq -e '.templating.list[] | select(.name == "user" and .query.query == "label_values(claude_code_cost_usage_USD_total, user_email)")' dev-productivity-dashboard.json >/dev/null \
  || fail "missing or wrong $user variable query"

for panel in \
  "Leverage ratio (continuous)" \
  "Autonomy (%)" \
  "Accepted edits per active hour" \
  "Tool actions per active hour" \
  "Output tokens per active hour" \
  "First-pass acceptance (%)" \
  "Cache hit ratio" \
  "Output tokens per accepted edit" \
  "Sessions started by type" \
  "Retry tax (attempt > 1)" \
  "Tool failure cost proxy" \
  "Interruption index (rejects per active hour)"
do
  jq -e --arg t "$panel" '.panels[] | select(.title == $t)' dev-productivity-dashboard.json >/dev/null \
    || fail "missing panel: $panel"
done

! rg -q 'claude_code_lines_of_code_count_total|claude_code_commit_count_total|claude_code_pull_request_count_total|claude_code_code_edit_tool_decision_count_total' dev-productivity-dashboard.json \
  || fail "dashboard references unsupported metrics"

! rg -q '\| json' dev-productivity-dashboard.json || fail "dashboard uses forbidden | json parser"

rg -q 'decision=\\"accept\\"' dev-productivity-dashboard.json || fail "missing Loki decision accept matcher"
rg -q 'attempt > 1' dev-productivity-dashboard.json || fail "missing retry-tax numeric matcher"
rg -q 'unwrap duration_ms' dev-productivity-dashboard.json || fail "missing unwrap duration_ms query"

echo "PASS: developer dashboard contract"
