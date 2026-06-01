#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

rg -q '^\.PHONY:.*\bpreflight-productivity\b' Makefile \
  || fail "Makefile .PHONY must include preflight-productivity"
rg -q '^preflight-productivity:' Makefile \
  || fail "Makefile preflight-productivity target is missing"
rg -q 'bash scripts/productivity-preflight.sh' Makefile \
  || fail "preflight-productivity must run scripts/productivity-preflight.sh"

echo "PASS: scenario09"

