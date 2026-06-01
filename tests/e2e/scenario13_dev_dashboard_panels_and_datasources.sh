#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

for title in \
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
  jq -e --arg t "$title" '.panels[] | select(.title == $t)' dev-productivity-dashboard.json >/dev/null \
    || fail "missing panel: $title"
done

jq -e '.panels[] | select(.title == "Leverage ratio (continuous)") | ((.datasource.uid // .datasource) == "prometheus")' dev-productivity-dashboard.json >/dev/null \
  || fail "Leverage ratio must be Prometheus"
jq -e '.panels[] | select(.title == "Autonomy (%)") | ((.datasource.uid // .datasource) == "prometheus")' dev-productivity-dashboard.json >/dev/null \
  || fail "Autonomy must be Prometheus"
jq -e '.panels[] | select(.title == "Cache hit ratio") | ((.datasource.uid // .datasource) == "prometheus") and .type == "stat"' dev-productivity-dashboard.json >/dev/null \
  || fail "Cache hit ratio must be Prometheus stat panel"
jq -e '.panels[] | select(.title == "Sessions started by type") | ((.datasource.uid // .datasource) == "prometheus")' dev-productivity-dashboard.json >/dev/null \
  || fail "Sessions started by type must be Prometheus"

jq -e '.panels[] | select(.title == "Accepted edits per active hour") | ((.datasource.uid // .datasource) == "loki")' dev-productivity-dashboard.json >/dev/null \
  || fail "Accepted edits per active hour must be Loki"
jq -e '.panels[] | select(.title == "Retry tax (attempt > 1)") | ((.datasource.uid // .datasource) == "loki")' dev-productivity-dashboard.json >/dev/null \
  || fail "Retry tax must be Loki"
jq -e '.panels[] | select(.title == "Tool failure cost proxy") | ((.datasource.uid // .datasource) == "loki")' dev-productivity-dashboard.json >/dev/null \
  || fail "Tool failure cost proxy must be Loki"
jq -e '.panels[] | select(.title == "Interruption index (rejects per active hour)") | ((.datasource.uid // .datasource) == "loki")' dev-productivity-dashboard.json >/dev/null \
  || fail "Interruption index must be Loki"

echo "PASS: scenario13"

