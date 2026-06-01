#!/usr/bin/env bash
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

test -x scripts/productivity-preflight.sh || fail "scripts/productivity-preflight.sh missing or not executable"

for needle in \
  'store: tsdb' \
  'store: boltdb-shipper' \
  'decision="accept"' \
  'attempt > 1' \
  'unwrap duration_ms' \
  'user_email!=""'

do
  rg -q "$needle" scripts/productivity-preflight.sh || fail "missing pre-flight check: $needle"
done

rg -q '^preflight-productivity:' Makefile || fail "Makefile target preflight-productivity missing"
rg -q 'scripts/productivity-preflight.sh' Makefile || fail "Makefile does not execute preflight script"

echo "PASS: preflight scaffolding"
