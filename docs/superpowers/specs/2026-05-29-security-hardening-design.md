# Security Hardening — claude-code-otel — Design Spec

Date: 2026-05-29
Status: Approved

## Context

A multi-agent security audit of this local Docker observability stack rated it
**SAFE_WITH_PRECAUTIONS**: the code is not malicious (official upstream images,
no privileged containers, no docker.sock or host mounts), but the default
*configuration* exposes every service to the local network with no
authentication, ships Grafana with `admin/admin`, and binds the Grafana UI to
port 3000 (which the operator reserves for local Node processes). This spec
hardens the configuration before the stack is run locally.

The defense is applied at the **Docker host-port-publish layer** — restricting
every published port to `127.0.0.1` — plus a non-default Grafana admin password
sourced from a gitignored `.env`. The OpenTelemetry collector's *in-container*
listen addresses are deliberately left on `0.0.0.0` (see Decision D1).

## Goals

1. No stack service is reachable from the LAN/WAN — only from the host machine.
2. Grafana does not ship with the documented `admin/admin` default.
3. Grafana's host port moves off 3000 to avoid colliding with local Node dev servers.
4. Documentation and Makefile reflect the new port and the `.env` setup step.
5. The stack remains fully functional (OTLP ingestion + Prometheus scraping intact).

## Non-Goals

- Pinning image digests / replacing `:latest` tags (optional hardening, deferred).
- Adding TLS or real auth to the OTLP receivers (localhost binding is sufficient for local use).
- Changing `make clean` behavior (only a warning comment is added).

## Decisions

### D1 — Network hardening happens at the host-port layer, NOT in collector-config.yaml

The collector's receivers (`4317`/`4318`) and Prometheus exporter (`8889`) MUST
keep listening on `0.0.0.0` *inside the container*:

- The receivers receive traffic forwarded by Docker's proxy from the bridge
  gateway IP; a `127.0.0.1` in-container bind would make them unreachable from
  the published host port.
- `8889` is scraped by Prometheus over the Docker network (`otel-collector:8889`);
  a `127.0.0.1` bind would break scraping.

Exposure is instead restricted by publishing every host port as
`127.0.0.1:PORT:PORT`, so the kernel only accepts connections from the loopback
interface. `collector-config.yaml` is therefore **left unchanged**.

### D2 — Grafana password via env substitution with a placeholder default

`GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-changeme}`. The real value
lives in a gitignored `.env`; a committed `.env.example` documents the variable.
The `:-changeme` fallback guarantees the value is never literally `admin` even if
the operator forgets `.env`.

### D3 — Grafana host port 3000 → 3001

Only the host side of the mapping changes (`"127.0.0.1:3001:3000"`); the
container continues to listen on 3000, so no Grafana internal config changes.

## Changes by File

### `docker-compose.yml`
- Prefix every published port with `127.0.0.1`:
  - `4317`, `4318`, `8889` (otel-collector)
  - `9090` (prometheus)
  - `3100` (loki)
  - Grafana: `"127.0.0.1:3001:3000"`
- `GF_SECURITY_ADMIN_PASSWORD=admin` → `GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-changeme}`

### `docker-compose-lgtm.yml`
- `"127.0.0.1:3001:3000"` (Grafana), `"127.0.0.1:4317:4317"`, `"127.0.0.1:4318:4318"`

### `collector-config.yaml`
- **Unchanged** (per D1).

### `.env.example` (new, committed)
```
GRAFANA_ADMIN_PASSWORD=changeme
```

### `.gitignore`
- No change required: `.env`, `.env.local`, `.env.*.local` already excluded;
  `.env.example` is not matched by those patterns, so it stays committed. Confirm
  at implementation time.

### `Makefile`
- `up` and `status` echo lines: `http://localhost:3000` → `http://localhost:3001`.
- `up` echo: drop the `(admin/admin)` hint; add a note to copy `.env.example` → `.env`.
- `clean`: add a comment warning that `docker system prune -f` is system-wide
  (affects all Docker resources on the host, not just this stack). Behavior unchanged.

### `README.md` and `CLAUDE_OBSERVABILITY.md`
- Replace `localhost:3000` references with `localhost:3001`.
- Add a one-line note: copy `.env.example` to `.env` and set `GRAFANA_ADMIN_PASSWORD`
  before first `make up`.

## Verification

No automated test suite exists; validation is configuration-level.

1. `docker compose config` exits 0 (compose file parses with the env substitution).
2. `docker compose -f docker-compose-lgtm.yml config` exits 0.
3. Grep confirms every `ports:` entry in both compose files is prefixed with `127.0.0.1:`.
4. Grep confirms no `GF_SECURITY_ADMIN_PASSWORD=admin` remains.
5. `.env.example` exists and is NOT gitignored (`git check-ignore .env.example` exits non-zero).
6. Grep confirms no `localhost:3000` remains in `Makefile`, `README.md`, `CLAUDE_OBSERVABILITY.md`.
7. Conceptual: collector-config.yaml still on `0.0.0.0` (unchanged), so OTLP ingestion + Prometheus scraping intact.

## Refinement Status

(pending spec-refine phase)
