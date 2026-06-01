#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

yq -e '.services.prometheus.volumes[] | select(. == "./recording-rules.yml:/etc/prometheus/recording-rules.yml:ro")' docker-compose.yml >/dev/null \
  || fail "missing recording rules bind mount in prometheus service"

echo "PASS: scenario02"

