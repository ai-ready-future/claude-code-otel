#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

test -f docs/productivity-dashboards-deploy.md || fail "deploy runbook missing"

for needle in \
  'rsync -av --relative' \
  'docker compose up -d --force-recreate prometheus' \
  'curl -X POST http://localhost:9090/-/reload' \
  'docker compose restart grafana' \
  'docker compose up -d --force-recreate otel-collector'
do
  rg -q "$needle" docs/productivity-dashboards-deploy.md || fail "runbook missing command: $needle"
done

jq -e '.panels[] | select(.id == 24 and .title == "Productivity")' claude-code-dashboard.json >/dev/null \
  || fail "existing productivity stat panel regression"

jq -e '.panels[] | select(.title == "Cost") | .targets[] | select(.expr | contains("$__range"))' claude-code-dashboard.json >/dev/null \
  || fail "overview Cost panel no longer follows $__range"

jq -e '.panels[] | select(.title == "Token Usage") | .targets[] | select(.expr | contains("$__range"))' claude-code-dashboard.json >/dev/null \
  || fail "overview Token Usage panel no longer follows $__range"

echo "PASS: deploy runbook + baseline regression"
