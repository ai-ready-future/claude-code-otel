#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

compose="docker-compose.yml"

for flag in \
  "--storage.tsdb.retention.time=400d" \
  "--storage.tsdb.retention.size=20GB" \
  "--storage.tsdb.path=/prometheus" \
  "--config.file=/etc/prometheus/prometheus.yml" \
  "--web.enable-lifecycle"
do
  yq -e ".services.prometheus.command[] | select(. == \"$flag\")" "$compose" >/dev/null \
    || fail "missing Prometheus flag: $flag"
done

yq -e '.services.prometheus.volumes[] | select(. == "./recording-rules.yml:/etc/prometheus/recording-rules.yml:ro")' "$compose" >/dev/null \
  || fail "missing recording-rules bind mount"

yq -e '.services.grafana.volumes[] | select(. == "./dev-productivity-dashboard.json:/var/lib/grafana/dashboards/dev-productivity-dashboard.json:ro")' "$compose" >/dev/null \
  || fail "missing dev dashboard bind mount"

yq -e '.services.grafana.volumes[] | select(. == "./exec-roi-dashboard.json:/var/lib/grafana/dashboards/exec-roi-dashboard.json:ro")' "$compose" >/dev/null \
  || fail "missing exec dashboard bind mount"

echo "PASS: compose wiring"
