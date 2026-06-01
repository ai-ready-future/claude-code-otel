#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

yq -e '.rule_files[] | select(. == "/etc/prometheus/recording-rules.yml")' prometheus.yml >/dev/null \
  || fail "prometheus.yml must load /etc/prometheus/recording-rules.yml"

yq -e '.global.evaluation_interval == "1m"' prometheus.yml >/dev/null \
  || fail "global.evaluation_interval must remain 1m"

echo "PASS: scenario03"

