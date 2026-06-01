#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

yq -r '.groups[] | select(.name=="productivity_daily") | .rules[].expr' recording-rules.yml \
  | rg -q 'increase\([^)]*\[1d\]\)' \
  || fail "rules must use increase(...[1d])"

rg -q 'sum by \(user_email\)\(increase\(claude_code_active_time_seconds_total\{type="cli"\}\[1d\]\)\)' recording-rules.yml \
  || fail "leverage numerator is incorrect"
rg -q 'sum by \(user_email\)\(increase\(claude_code_active_time_seconds_total\{type="user"\}\[1d\]\)\)' recording-rules.yml \
  || fail "leverage denominator is incorrect"

rg -q 'sum by \(user_email\)\(increase\(claude_code_token_usage_tokens_total\{type="cacheRead"\}\[1d\]\)\)' recording-rules.yml \
  || fail "cache_hit numerator is incorrect"
rg -q 'sum by \(user_email\)\(increase\(claude_code_token_usage_tokens_total\{type=~"input\|cacheRead\|cacheCreation"\}\[1d\]\)\)' recording-rules.yml \
  || fail "cache_hit denominator is incorrect"

rg -q 'sum by \(user_email\)\(increase\(claude_code_cost_usage_USD_total\[1d\]\)\)' recording-rules.yml \
  || fail "cost_per_active_hour numerator is incorrect"
rg -q 'sum by \(user_email\)\(increase\(claude_code_active_time_seconds_total\[1d\]\)\) / 3600' recording-rules.yml \
  || fail "cost_per_active_hour denominator is incorrect"

echo "PASS: scenario05"

