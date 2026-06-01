#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

test -f recording-rules.yml || fail "recording-rules.yml missing"

yq -e '.global.evaluation_interval == "1m"' prometheus.yml >/dev/null \
  || fail "prometheus global evaluation_interval must be 1m"

yq -e '.rule_files[] | select(. == "/etc/prometheus/recording-rules.yml")' prometheus.yml >/dev/null \
  || fail "prometheus.yml missing /etc/prometheus/recording-rules.yml"

yq -e '.groups[] | select(.name == "productivity_daily" and .interval == "5m")' recording-rules.yml >/dev/null \
  || fail "productivity_daily group missing or wrong interval"

for rec in \
  "cc:cost_usd:daily" \
  "cc:active_seconds:daily" \
  "cc:leverage:daily" \
  "cc:tokens:daily" \
  "cc:cache_hit:daily" \
  "cc:cost_per_active_hour:daily" \
  "cc:sessions:daily"
do
  yq -e ".groups[] | select(.name == \"productivity_daily\") | .rules[] | select(.record == \"$rec\")" recording-rules.yml >/dev/null \
    || fail "missing rule: $rec"
done

! rg -q 'claude_code_lines_of_code_count_total|claude_code_commit_count_total|claude_code_pull_request_count_total|claude_code_code_edit_tool_decision_count_total' recording-rules.yml \
  || fail "recording rules include unsupported metrics"

echo "PASS: recording rules"
