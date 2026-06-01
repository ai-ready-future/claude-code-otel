#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

yq -e '.exporters.prometheus.metric_expiration == "24h"' collector-config.yaml >/dev/null \
  || fail "collector metric_expiration must be 24h"

! rg -q 'metric_expiration:\s*2h' collector-config.yaml \
  || fail "collector still sets metric_expiration: 2h"

echo "PASS: collector metric_expiration"
