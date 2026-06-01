#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

for flag in \
  "--storage.tsdb.retention.time=400d" \
  "--storage.tsdb.retention.size=20GB" \
  "--storage.tsdb.path=/prometheus" \
  "--config.file=/etc/prometheus/prometheus.yml" \
  "--web.enable-lifecycle"
do
  yq -e ".services.prometheus.command[] | select(. == \"$flag\")" docker-compose.yml >/dev/null \
    || fail "missing Prometheus command flag: $flag"
done

echo "PASS: scenario01"
