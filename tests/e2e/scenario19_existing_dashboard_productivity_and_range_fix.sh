#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

jq -e '.uid == "claude-code-obs"' claude-code-dashboard.json >/dev/null \
  || fail "unexpected base dashboard uid"

jq -e '.panels[] | select(.id == 24 and .title == "Productivity") | .targets[] | select(.expr | contains("clamp_min(floor") and contains("type=\"cli\"") and contains("type=\"user\"") and contains("[$__range]"))' claude-code-dashboard.json >/dev/null \
  || fail "Productivity stat panel formula missing expected $__range clamp_min(floor(cli/user),1)"

for title in "Active Sessions" "Cost" "Token Usage" "Lines of Code"
do
  jq -e --arg t "$title" '.panels[] | select(.title == $t) | .targets[] | select(.expr | contains("[$__range]"))' claude-code-dashboard.json >/dev/null \
    || fail "overview stat panel must use [$__range]: $title"
done

echo "PASS: scenario19"

