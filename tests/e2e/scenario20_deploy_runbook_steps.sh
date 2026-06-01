#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

for needle in \
  'rsync -av --relative' \
  'Bump each changed dashboard JSON `version` by `+1`' \
  'docker compose up -d --force-recreate prometheus' \
  'curl -X POST http://localhost:9090/-/reload' \
  'docker compose restart grafana' \
  'docker compose up -d --force-recreate otel-collector'
do
  rg -Fq "$needle" docs/productivity-dashboards-deploy.md \
    || fail "deploy runbook missing: $needle"
done

echo "PASS: scenario20"
