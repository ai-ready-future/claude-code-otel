#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

test -f loki-config.yaml || fail "loki-config.yaml missing"

yq -e '.limits_config.retention_period == "400d"' loki-config.yaml >/dev/null \
  || fail "loki retention_period must be 400d"

yq -e '.compactor.retention_enabled == true' loki-config.yaml >/dev/null \
  || fail "loki compactor retention_enabled must be true"

yq -e '.schema_config.configs[0].index.period == "24h"' loki-config.yaml >/dev/null \
  || fail "loki schema index.period must be 24h"

yq -e '.schema_config.configs[0].store == "tsdb" or .schema_config.configs[0].store == "boltdb-shipper"' loki-config.yaml >/dev/null \
  || fail "loki schema store must be tsdb or boltdb-shipper"

yq -e '.services.loki.command == "-config.file=/etc/loki/config.yaml"' docker-compose.yml >/dev/null \
  || fail "docker-compose loki command must point at /etc/loki/config.yaml"

yq -e '.services.loki.volumes[] | select(. == "./loki-config.yaml:/etc/loki/config.yaml:ro")' docker-compose.yml >/dev/null \
  || fail "missing loki config bind mount"

echo "PASS: loki retention wiring"
