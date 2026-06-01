#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

docker compose config >/dev/null || fail "docker compose config did not parse successfully"

echo "PASS: scenario21"

