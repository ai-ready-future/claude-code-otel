#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

yq -e '.exporters.prometheus.metric_expiration == "24h"' collector-config.yaml >/dev/null \
  || fail "metric_expiration must be 24h"

yq -e '.service.pipelines.metrics.receivers[0] == "otlp"' collector-config.yaml >/dev/null \
  || fail "metrics pipeline receivers must remain [otlp]"
yq -e '.service.pipelines.metrics.receivers[1] == null' collector-config.yaml >/dev/null \
  || fail "metrics pipeline receivers must contain only otlp"

yq -e '.service.pipelines.metrics.processors[0] == "resource"' collector-config.yaml >/dev/null \
  || fail "metrics pipeline processors must remain [resource]"
yq -e '.service.pipelines.metrics.processors[1] == null' collector-config.yaml >/dev/null \
  || fail "metrics pipeline processors must contain only resource"

yq -e '.service.pipelines.metrics.exporters[0] == "prometheus"' collector-config.yaml >/dev/null \
  || fail "metrics pipeline exporters must include prometheus first"
yq -e '.service.pipelines.metrics.exporters[1] == "debug"' collector-config.yaml >/dev/null \
  || fail "metrics pipeline exporters must include debug second"
yq -e '.service.pipelines.metrics.exporters[2] == null' collector-config.yaml >/dev/null \
  || fail "metrics pipeline exporters must remain [prometheus, debug]"

echo "PASS: scenario06"
