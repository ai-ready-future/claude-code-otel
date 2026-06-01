#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

yq -e '.limits_config.retention_period == "400d"' loki-config.yaml >/dev/null \
  || fail "limits_config.retention_period must be 400d"

yq -e '.compactor.retention_enabled == true' loki-config.yaml >/dev/null \
  || fail "compactor.retention_enabled must be true"
yq -e '.compactor.working_directory == "/loki/compactor"' loki-config.yaml >/dev/null \
  || fail "compactor.working_directory missing"
yq -e '.compactor.retention_delete_delay == "2h"' loki-config.yaml >/dev/null \
  || fail "compactor.retention_delete_delay missing"
yq -e '.compactor.retention_delete_worker_count == 150' loki-config.yaml >/dev/null \
  || fail "compactor.retention_delete_worker_count missing"
yq -e '.compactor.delete_request_store == "filesystem"' loki-config.yaml >/dev/null \
  || fail "compactor.delete_request_store must be filesystem"

yq -e '.schema_config.configs[0].store == "tsdb"' loki-config.yaml >/dev/null \
  || fail "schema_config store must be tsdb"
yq -e '.schema_config.configs[0].index.period == "24h"' loki-config.yaml >/dev/null \
  || fail "schema index period must be 24h"

yq -e '.services.loki.volumes[] | select(. == "./loki-config.yaml:/etc/loki/config.yaml:ro")' docker-compose.yml >/dev/null \
  || fail "docker-compose loki service must mount loki-config.yaml"

echo "PASS: scenario07"

