# Productivity Dashboards Deploy Runbook (nuc01)

1. From the fork root, sync changed files:

```bash
rsync -av --relative \
  claude-code-dashboard.json dev-productivity-dashboard.json exec-roi-dashboard.json \
  docker-compose.yml prometheus.yml recording-rules.yml \
  collector-config.yaml loki-config.yaml \
  nuc01:/home/jazz/claude-code-otel/
```

2. Bump each changed dashboard JSON `version` by `+1` before restart.

3. Restart Prometheus for retention/compose/rule-file changes:

```bash
docker compose up -d --force-recreate prometheus
```

4. If only `recording-rules.yml` changed, hot-reload instead:

```bash
curl -X POST http://localhost:9090/-/reload
```

5. Restart Grafana to force dashboard re-provision:

```bash
docker compose restart grafana
```

6. Restart collector only when `collector-config.yaml` changed:

```bash
docker compose up -d --force-recreate otel-collector
```

7. Run pre-flight + smoke checks:

```bash
make preflight-productivity
curl -fsS http://localhost:9090/api/v1/status/runtimeinfo | jq -r '.data.storageRetention'
```
