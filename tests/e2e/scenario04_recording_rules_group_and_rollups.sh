#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

yq -e '.groups | length == 1' recording-rules.yml >/dev/null \
  || fail "recording-rules.yml must define exactly one group"

yq -e '.groups[] | select(.name == "productivity_daily" and .interval == "5m")' recording-rules.yml >/dev/null \
  || fail "missing productivity_daily group with 5m interval"

yq -e '.groups[] | select(.name == "productivity_daily") | .rules | length == 7' recording-rules.yml >/dev/null \
  || fail "productivity_daily must contain exactly seven rules"

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
    || fail "missing recording rule: $rec"
done

rg -q 'sum by \(user_email, start_type\).*claude_code_session_count_total' recording-rules.yml \
  || fail "cc:sessions:daily must aggregate by start_type"

! rg -q 'claude_code_lines_of_code_count_total|claude_code_commit_count_total|claude_code_pull_request_count_total|claude_code_code_edit_tool_decision_count_total' recording-rules.yml \
  || fail "recording rules reference unsupported metrics"

echo "PASS: scenario04"

