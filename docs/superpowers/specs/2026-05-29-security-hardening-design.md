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
the operator forgets `.env`. `changeme` is an acceptable non-`admin` fallback for
local use; the README/CONTRIBUTING notes instruct the operator to replace it. No
runtime warning/health-check is added (documentation-only is the intended
behavior — out of scope to enforce). `[inferred]`

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
- The `lgtm` service currently has no `environment:` block, so its bundled Grafana
  uses the image-default `admin/admin`. Add an `environment:` block with
  `GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-changeme}` so the LGTM path
  is hardened identically to the primary stack (Goal 2 applies to both compose files). `[inferred]`

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

### `README.md`, `CONTRIBUTING.md`
- Replace ALL user-facing Grafana host-port `3000` references with `3001` — this
  includes both `http://localhost:3000` URLs AND the bare `3000` value in the
  README components table (line ~62). `[inferred]`
- Replace `(admin/admin)` credential hints with a note to set `GRAFANA_ADMIN_PASSWORD`
  via `.env` (README line ~95, CONTRIBUTING line ~17).
- `CONTRIBUTING.md` also has a health-check `curl http://localhost:3000/api/health`
  (line ~88) → `3001`.
- Add a one-line note (README setup section): copy `.env.example` to `.env` and set
  `GRAFANA_ADMIN_PASSWORD` before first `make up`.
- `CLAUDE_OBSERVABILITY.md` contains NO `localhost:3000` or credential references
  (verified by grep), so it is **out of scope** — no edits needed. `[inferred]`

## Verification

No automated test suite exists; validation is configuration-level.

1. `docker compose config` exits 0 (compose file parses with the env substitution).
2. `docker compose -f docker-compose-lgtm.yml config` exits 0.
3. Grep confirms every `ports:` entry in both compose files is prefixed with `127.0.0.1:`.
4. Grep confirms no `GF_SECURITY_ADMIN_PASSWORD=admin` remains.
5. `.env.example` exists and is NOT gitignored (`git check-ignore .env.example` exits non-zero).
6. Grep confirms no `localhost:3000` AND no bare Grafana port `3000` remains in
   `Makefile`, `README.md`, `CONTRIBUTING.md` (e.g. `grep -rn '3000' Makefile README.md CONTRIBUTING.md`
   returns only intended/unrelated matches, none Grafana-host-port).
7. Grep confirms no `GF_SECURITY_ADMIN_PASSWORD=admin` and no `admin/admin` credential
   hint remains in `docker-compose.yml`, `README.md`, `CONTRIBUTING.md`.
8. `docker-compose-lgtm.yml` Grafana has a `GF_SECURITY_ADMIN_PASSWORD` env entry.
9. Conceptual: collector-config.yaml still on `0.0.0.0` (unchanged), so OTLP ingestion + Prometheus scraping intact.

## Refinement Status

Round 1 (spec-simulator): 0 critical, 3 important, 1 minor. All findings resolved
inline by spec-fixer — LGTM Grafana password hardening added, `CONTRIBUTING.md`
brought into doc scope (and `CLAUDE_OBSERVABILITY.md` confirmed out of scope), bare
README port-table value and verification grep widened, placeholder-password behavior
clarified.

Refinement: CONVERGED round 1
