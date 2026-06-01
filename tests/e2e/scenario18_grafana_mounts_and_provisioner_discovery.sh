#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

yq -e '.services.grafana.volumes[] | select(. == "./claude-code-dashboard.json:/var/lib/grafana/dashboards/claude-code-dashboard.json:ro")' docker-compose.yml >/dev/null \
  || fail "missing claude-code-dashboard mount"
yq -e '.services.grafana.volumes[] | select(. == "./dev-productivity-dashboard.json:/var/lib/grafana/dashboards/dev-productivity-dashboard.json:ro")' docker-compose.yml >/dev/null \
  || fail "missing dev-productivity dashboard mount"
yq -e '.services.grafana.volumes[] | select(. == "./exec-roi-dashboard.json:/var/lib/grafana/dashboards/exec-roi-dashboard.json:ro")' docker-compose.yml >/dev/null \
  || fail "missing exec-roi dashboard mount"

yq -e '.providers[] | select(.type == "file") | .options.path == "/var/lib/grafana/dashboards"' grafana-dashboards.yml >/dev/null \
  || fail "Grafana provisioner path must include /var/lib/grafana/dashboards"

echo "PASS: scenario18"

