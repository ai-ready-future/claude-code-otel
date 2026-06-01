#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1"; exit 1; }

test -f scripts/productivity-preflight.sh || fail "preflight script missing"

for needle in \
  'store: tsdb' \
  'store: boltdb-shipper' \
  'period:\s*24h' \
  'decision="accept"' \
  'attempt > 1' \
  'unwrap duration_ms' \
  'user_email!=""'
do
  rg -Fq "$needle" scripts/productivity-preflight.sh || fail "preflight check missing: $needle"
done

! rg -q '\| json' scripts/productivity-preflight.sh || fail "preflight script must not use | json"

echo "PASS: scenario08"
