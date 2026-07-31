#!/usr/bin/env bash
# Consolidated configuration validation for the observability stack.
#
# These are REAL validators (parse / lint / well-formedness), not literal-value
# snapshots — they catch syntax errors, malformed JSON, and broken recording
# rules that would only otherwise surface at deploy time. This is the suite the
# CI gate (.github/workflows/ci.yml) runs on every PR to main.
#
# Locally, checks whose tooling is absent are SKIPPED (not failed); in CI the
# workflow installs the tooling so every check actually runs.
set -uo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fails=0
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; fails=$((fails + 1)); }
skip() { printf '  \033[33m–\033[0m %s (skipped: %s)\n' "$1" "$2"; }

# 1. docker compose config parses, resolves bind-mounts, and is internally consistent
echo "▸ docker compose"
if command -v docker >/dev/null 2>&1; then
  if err=$(docker compose config -q 2>&1); then pass "docker compose config valid"
  else fail "docker compose config invalid: $err"; fi
else skip "docker compose config" "docker not installed"; fi

# 2. Prometheus recording rules lint (promtool — local binary or via prom image)
echo "▸ prometheus rules"
promtool=""
if command -v promtool >/dev/null 2>&1; then
  promtool=(promtool)
elif command -v docker >/dev/null 2>&1; then
  promtool=(docker run --rm --entrypoint promtool -v "$repo_root:/w" -w /w prom/prometheus:latest)
fi
if [ -n "${promtool:-}" ]; then
  if out=$("${promtool[@]}" check rules recording-rules.yml 2>&1); then pass "promtool check rules recording-rules.yml"
  else fail "recording rules invalid:"$'\n'"$out"; fi
else skip "promtool check rules" "promtool/docker unavailable"; fi

# 3. Dashboards are well-formed JSON
echo "▸ dashboards json"
for f in *.json; do
  [ -e "$f" ] || continue
  if err=$(jq empty "$f" 2>&1); then pass "$f well-formed"
  else fail "$f invalid JSON: $err"; fi
done

# 4. YAML configs parse
echo "▸ yaml configs"
for f in collector-config.yaml loki-config.yaml prometheus.yml recording-rules.yml; do
  [ -e "$f" ] || continue
  if err=$(yq -e '.' "$f" 2>&1 >/dev/null); then pass "$f parses"
  else fail "$f invalid YAML: $err"; fi
done

# 5. Regression guard: Loki panels must not use `| json`. Claude Code log fields
#    arrive as structured metadata, so the json parser yields empty results and
#    silently breaks every panel. (Learned-the-hard-way gotcha — keep this gate.)
echo "▸ loki query guard"
for f in *.json; do
  [ -e "$f" ] || continue
  if grep -q '| json' "$f"; then fail "$f uses '| json' — Loki fields are structured metadata; queries return empty"
  else pass "$f free of '| json'"; fi
done

# 6. Regression guard: every dashboard must be mounted into Grafana. A dashboard
#    added to the repo but not to the compose file is invisible at runtime, and
#    nothing else reports it.
echo "▸ dashboard provisioning"
for f in *.json; do
  [ -e "$f" ] || continue
  if grep -q "\./$f:/var/lib/grafana/dashboards/" docker-compose.yml; then pass "$f mounted into grafana"
  else fail "$f is not mounted in docker-compose.yml — Grafana never loads it"; fi
done

# 7. Regression guard: every datasource uid a dashboard refers to must exist in
#    grafana-datasources.yml. Grafana makes a random uid for a datasource that
#    declares none, so a dashboard reference then resolves to nothing and every
#    panel shows "Datasource not found". (Learned-the-hard-way gotcha.)
echo "▸ datasource uid references"
if command -v jq >/dev/null 2>&1 && command -v yq >/dev/null 2>&1; then
  defined=$(yq -r '.datasources[].uid' grafana-datasources.yml | grep -v '^null$' | sort -u)
  for f in *.json; do
    [ -e "$f" ] || continue
    missing=""
    for uid in $(jq -r '[.. | objects | select(has("uid") and has("type"))
                         | select(.type | IN("prometheus","loki","alertmanager"))
                         | .uid] | unique | .[]' "$f"); do
      case "$uid" in \$*) continue ;; esac   # dashboard variable, resolved at view time
      grep -qxF "$uid" <<<"$defined" || missing="$missing $uid"
    done
    if [ -z "$missing" ]; then pass "$f datasource uids all defined"
    else fail "$f refers to undefined datasource uid(s):$missing"; fi
  done
else skip "datasource uid references" "jq/yq unavailable"; fi

# 8. Shell scripts are syntactically valid
echo "▸ shell syntax"
for f in scripts/*.sh; do
  [ -e "$f" ] || continue
  if err=$(bash -n "$f" 2>&1); then pass "$f parses"
  else fail "$f syntax error: $err"; fi
done

echo
if [ "$fails" -eq 0 ]; then echo "✅ all validations passed"; exit 0
else echo "❌ $fails validation(s) failed"; exit 1; fi
