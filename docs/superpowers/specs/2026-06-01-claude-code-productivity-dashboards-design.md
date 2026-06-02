# Claude Code Productivity Dashboards — Design

- **Date:** 2026-06-01
- **Repo:** `ai-ready-future/claude-code-otel` (fork of `ColeMurray/claude-code-otel`)
- **Status:** Draft — design approved, pending pre-flight metric verification + user review
- **Author:** Pilo (with Claude Code)

## 1. Context & motivation

We run Claude Code with OpenTelemetry telemetry shipped to a Prometheus + Grafana + Loki
stack (deployed on `nuc01`, mirrored from this fork). Today there is a single
**Claude Code Observability** dashboard (uid `claude-code-obs`, 30 panels) focused on
*operational* monitoring — API latency, error rates, tool usage, event logs.

We want to add **productivity tracking** with two properties the current setup lacks:

1. **Historical, not spot.** The headline requirement is seeing productivity *evolve over
   time* — by day, week, and month — not a snapshot of "right now." Every productivity
   panel must be a time-series trend, and the backing store must retain months of data.
2. **Persona separation.** A developer and an executive want different things. Forcing both
   onto one board makes it useless to both, so we split into two purpose-built dashboards.

The Anthropic-linked monitoring guide (`anthropics/claude-code-monitoring-guide`) ships a
thin ROI starter (one dashboard, 8 spot-report panels, 200h retention, no recording rules,
no trend panels). We crib its validated cost/token query patterns and collector shape, then
diverge hard on history and persona design.

## 2. Goals / non-goals

**Goals**
- Two new Grafana dashboards: **Developer Productivity** and **Executive / ROI**.
- A **historical foundation**: extend Prometheus retention to ~13 months and add recording
  rules that pre-compute per-user daily productivity rollups for cheap long-range queries.
- Port the one un-committed dashboard improvement (the `Productivity` stat panel) into the
  fork, and make the existing overview row honor the dashboard time-picker.
- An explicit, maintained **panel→persona allocation** ("what goes where").

**Non-goals**
- Homelab-specific concerns (cAdvisor / node-exporter / hardware dashboards, ntfy alerting,
  Tailscale Funnel exposure) — those stay in the `404pilo/home` repo, not this fork.
- Changing how Claude Code emits telemetry (client-side OTEL env config) beyond noting
  enablement gaps surfaced by pre-flight.
- Deep CI/PR-lifecycle joins (Jira/Linear/GitHub merge state) — out of scope for v1.

## 3. The three-dashboard landscape

| Dashboard | Concern | Persona | Default filter | Horizon | Status |
|---|---|---|---|---|---|
| **Claude Code Observability** (`claude-code-obs`) | Operational / ops | Operator | n/a | hours–days | Exists; minor edits only |
| **Developer Productivity** (`claude-code-dev-productivity`) | Craft / workflow | Developer | `$user` self-scoped | hours–weeks | NEW |
| **Executive / ROI** (`claude-code-exec-roi`) | Investment / outcomes | Executive | team / `All` | weeks–months | NEW |

The existing observability dashboard is unchanged except for the already-applied overview-row
fix (§7). The two new dashboards are the substance of this design.

## 4. Personas

**Developer** — "How do I work better with the agent?" Wants granular, actionable, *self-
filtered* signals: quality (acceptance, by language/tool), efficiency (cache, tokens/line),
attribution (which skills/agents/MCP tools cost what), and friction (errors, retries, tool
failures). Operational time horizon (a session to a few weeks).

**Executive** — "Is this investment paying off?" Wants high-level, dollar-denominated,
team-rollup *trends*: leverage multiplier, value delivered, cost per shipped unit, total
spend trajectory, cost of wasted work. Multi-month horizon, low cardinality, no mechanics.

## 5. Shared design principles

- **Trend-first.** Every productivity panel is a `timeseries`. Snapshot `stat`/`gauge`
  panels appear only as companions in a top "at-a-glance" row, never as the main content.
- **One `$user` template variable per dashboard.** `label_values(claude_code_cost_usage_USD_total, user_email)`,
  multi-value, includes `All`. Prometheus panels filter with `{user_email=~"$user"}` (the
  `=~` makes `All`→`.*`). Developer dashboard defaults to a single user; Executive defaults
  to `All`. **`$user` on Loki/Prom×Loki panels is gated by a §12.1c pre-flight [inferred]:** if
  `user_email` arrives as a structured-metadata label on Loki events, every Loki and Prom×Loki
  query appends it to the stream selector as a structured-metadata label filter —
  `{event="tool_decision"} | user_email=~"$user"` (a `| label=~` clause, *not* an in-selector
  matcher, because structured metadata is filtered post-selector) [inferred]. If the pre-flight
  finds `user_email` ABSENT on Loki events, the developer dashboard's `$user` self-scoping is
  **Prometheus-only for v1**: Loki and the Loki half of Prom×Loki panels are **team-wide** and
  explicitly labeled as such in their panel descriptions; the `$user` variable still scopes the
  Prometheus queries on those same dashboards [inferred]. Fallback label if `user_email` is sparse: `user_account_id`, then `user_id`.
  **Operationalization (v1):** Grafana template variables cannot natively "fall back" between
  label keys, so v1 ships **`$user` bound to `user_email` only**, and the
  `user_account_id`/`user_id` fallback is a documented Phase-2 concern rather than an
  in-dashboard mechanism [inferred]. If a deployment finds `user_email` genuinely sparse, the
  fallback is applied by editing the one `$user` variable's `label_values(...)` query and the
  panel filter label in place (a manual per-dashboard switch), not by chained auto-coalescing
  variables [inferred].
- **Backed by recording rules.** Long-range panels query pre-aggregated `cc:*:daily` series
  (§8) instead of recomputing `increase()` over multi-month windows live.
- **Counter hygiene.** All `claude_code_*` metrics are cumulative counters; always wrap in
  `increase()`/`rate()`. Confirmed metric names: `claude_code_active_time_seconds_total`,
  `claude_code_cost_usage_USD_total`, `claude_code_token_usage_tokens_total` (single `_total`,
  no doubling), and `claude_code_session_count_total`. **ABSENT — Phase 2 if/when emitted
  [inferred]:** `claude_code_lines_of_code_count_total`, `claude_code_commit_count_total`,
  `claude_code_pull_request_count_total`, and `claude_code_code_edit_tool_decision_count_total`
  are **not emitted by the running client** (verified ❌ ABSENT in §10.1) — do NOT write queries
  against them in v1. They follow the same `_count_total` convention only as a naming note for a
  possible future client; `tool_decision` lives as a Loki event today (§10.3), not a metric.
- **Honest framing.** Volume metrics (LoC) are gameable; each dashboard pairs volume with a
  quality gate and carries a text panel stating these are leverage/activity indicators, not
  performance scores — important before any per-user filtering is read as ranking.

## 6. Panel → persona allocation ("what goes where")

🌟 = under-exploited combination not present on any base dashboard. Source reflects the
**verified** reality (§10): Prom = Prometheus metric, Loki = log event, Prom×Loki =
cross-source.

**Prom×Loki panel mechanism (v1):** every `Prom×Loki` panel uses a Grafana **Mixed
datasource** — one Prometheus query (refId A) and one Loki query (refId B, an `instant`/range
metric query via `count_over_time`/`sum_over_time` so it returns a numeric series) — combined
with panel **transforms** (`Merge` then a `Binary operation`/`Math` add-field, or `Reduce` for
stat panels) [inferred]. Worked example — **D6 "Output tokens per accepted edit"** [inferred]:
- A (Prometheus): `sum(increase(claude_code_token_usage_tokens_total{type="output",user_email=~"$user"}[$__interval]))`
- B (Loki): `sum(count_over_time({event="tool_decision"} | decision="accept" [$__interval]))`
- Transform: `Merge`, then `Add field from calculation → Binary operation` A `/` B, hide A and B.

**Three-query composites — E2/E6 (preferred two-query form) [inferred].** E2 (`output_tokens ×
accept_rate`) and E6 (`cost × reject_rate`) do **not** fit the A÷B template directly, because
`accept_rate`/`reject_rate` are themselves Loki ratios — naively they need three queries (A Prom ×
B Loki-numerator ÷ C Loki-denominator) and chained transforms. **Preferred form:** compute the rate
*inside a single LogQL expression* so the panel collapses back to two queries (one Prom A × one
Loki-ratio B). Worked example — **E6 "Cost of Rejected Work ($)"** [inferred]:
- A (Prometheus): `sum(increase(claude_code_cost_usage_USD_total{user_email=~"$user"}[$__interval]))`
- B (Loki, reject_rate as one expression):
  `sum(count_over_time({event="tool_decision"} | decision="reject" [$__interval])) / sum(count_over_time({event="tool_decision"} [$__interval]))`
- Transform: `Merge`, then `Binary operation` A `*` B, hide A and B.

E2 is identical with A = output-token `increase(...)` and B's numerator `| decision="accept"`. This
single-expression-ratio form is the **preferred** shape for any "Prom × Loki-rate" panel; only fall
back to the three-query chained-transform form (Merge → B÷C → A×result) if a Loki version cannot
evaluate the division inside one query [inferred].

**LogQL structured-metadata filtering (load-bearing) [inferred]:** Claude Code event fields
(`decision`, `attempt`, `success`, `status_code`, …) arrive as Loki **structured metadata**, not
log-line JSON. Per the project's known dashboard gotcha, the `| json` parser **must NOT be used**
on these events — it fails because the fields are not in the log line. The correct form is a
**structured-metadata label matcher** appended to the stream selector, e.g.
`{event="tool_decision"} | decision="accept"` works *if and only if* `decision` is exposed as a
structured-metadata label by the deployed Loki version [inferred]. Every Loki and Prom×Loki query
in this spec (`| decision="accept"` in D4/D6/E2/E6/E7/E8, `| attempt>1` in D11,
`| success="false"` in D12, `| decision="reject"` in D13/E6) depends on this matcher form being
valid [inferred]. **Pre-flight (a §12 verification-plan step):** before building any Loki panel,
run one matcher-form query (e.g. `sum(count_over_time({event="tool_decision"} | decision="accept" [1h]))`)
and confirm it returns a **non-empty** result; do not proceed to author the Loki panels until that
single query is proven against the deployment [inferred].

**D0 / E0 are NOT single Mixed panels [inferred].** The at-a-glance "stat row" is **4 separate
single-datasource stat panels grouped in a Grafana row** — each sub-stat has its own *single*
datasource, not Mixed (e.g. D0: leverage = Prom, acceptance % = Loki, cache % = Prom,
cost/active-hr = Prom). The `Prom×Loki` tag on the D0/E0 table rows means "the row mixes Prom and
Loki *panels*," read it as "Prom + Loki stats" — the Mixed-datasource A÷B/A×B template does **not**
apply to D0/E0, and each sub-stat is added by editing its own panel JSON (four panels, not one)
[inferred]. The Mixed/transform A÷B template applies only to the genuine **single-panel
cross-source** cases: **D2, D6, D13, E8** (D10 was reframed to pure Prom via `cc:sessions:daily`;
E2/E6 are three-query composites — see the worked examples below) [inferred].

The remaining genuine single-panel cross-source `Prom×Loki` panels (D2, D13, E8)
follow this same A÷B / A×B template, swapping queries [inferred]. (A Loki recording-rule path that would let
these be single-datasource is deferred to §13.) [inferred] Per the Option-A decision, panels that depended on `commit`/`pull_request`/
`lines_of_code` (which your telemetry does not emit) are **dropped or reframed to real
proxies** (accepted edits, tool actions, output tokens) — labeled as activity proxies, not
"lines/commits shipped."

### 6.1 Developer Productivity dashboard

| # | Panel | Composite / formula sketch | Type | Source |
|---|---|---|---|---|
| D0 | At-a-glance stats | leverage Nx · acceptance % · cache % · cost/active-hr | stat row (4 panels) | Prom + Loki stats |
| D1 | Leverage ratio (continuous) + autonomy % | `cli/user` active; `cli/(cli+user)` | timeseries | Prom |
| D2 | Activity per active hour *(reframed)* | 3 small timeseries in a sub-row: accepted-edits/hr · tool-actions/hr · output-tokens/hr (see note) | timeseries (×3) | Prom×Loki |
| D4 | First-pass acceptance — trend + by tool | `tool_decision{decision="accept"}/all`, `by(tool_name)` | timeseries + bar | Loki |
| D5 | Cache hit ratio | `cacheRead/(input+cacheRead+cacheCreation)` | timeseries | Prom |
| D6 | Output tokens per accepted edit *(reframed)* | `output_tokens ÷ accepted_decisions` | timeseries | Prom×Loki |
| D7 | Output density / thinking-to-doing | `output/cost by(model)`; `output/input` | timeseries | Prom |
| D8 | Spend & tokens by model / query_source / agent *(reframed)* | `sum by(model\|query_source\|agent_name)(increase(cost[range]))` | bar/table | Prom |
| D10 | 🌟 Sessions started by type — over time *(reframed)* | `cc:sessions:daily` by `start_type` (fresh vs resume) | bar/timeseries | Prom (rules) |
| D11 | Friction — retry tax | `api_error` events `\| attempt>1` by `status_code` (numeric form gated by §12.1b) | timeseries | Loki |
| D12 | Friction — tool-failure cost | `tool_result{success="false"}` count × `duration_ms` (`unwrap` gated by §12.1b); top `error_type` | timeseries + table | Loki |
| D13 | Interruption index *(reframed)* | `tool_decision{decision="reject"}` per active hour | timeseries | Prom×Loki |

**D2 definitions [inferred].** "tool-actions" is defined concretely as the **`tool_result` event
count across all `success` values** (`sum(count_over_time({event="tool_result"} [..]))`) — actions
attempted. "accepted-edits" is `tool_decision | decision="accept"`. Rather than stack three
Mixed-datasource transform pipelines in one panel, D2 is **split into three small timeseries grouped
in a Grafana sub-row**, each its own Prom×Loki A÷B panel (numerator Loki/Prom count, denominator
Prom active-hours `increase(active_time)/3600`) [inferred]. This keeps each panel on the worked A÷B
template and avoids the unsupported triple-pipeline-in-one-panel shape.

*Dropped (no data source):* net-LoC/churn, tokens-per-line, effort-efficiency (`effort` is
single-valued `high`), and skill/plugin/MCP attribution (labels privacy-bucketed to
`third-party`/`custom`, §10.2).

### 6.2 Executive / ROI dashboard

| # | Panel | Composite / formula sketch | Type | Source |
|---|---|---|---|---|
| E0 | At-a-glance stats | leverage Nx · cost (period) · acceptance % · cost/active-hr | stat row (4 panels) | Prom + Loki stats |
| E1 | Leverage multiplier (Nx) — trend | `floor(cli/user)` clamped ≥1, over time | timeseries | Prom |
| E2 | 🌟 Quality-Adjusted Activity — trend *(reframed)* | `output_tokens × accept_rate` (value-weighted work) | timeseries | Prom×Loki |
| E3 | Total cost — daily/weekly/monthly | via `cc:cost_usd:daily` | timeseries | Prom (rules) |
| E5 | Cost per active hour — trend | via `cc:cost_per_active_hour:daily` | timeseries | Prom (rules) |
| E6 | 🌟 Cost of Rejected Work ($) | `cost × reject_rate` | timeseries | Prom×Loki |
| E7 | Accepted edits over time *(reframed)* | `tool_decision{decision="accept"}` rate | timeseries/bar | Loki |
| E8 | 🌟 Output per prompt *(reframed)* | `output_tokens ÷ user_prompt count` | timeseries | Prom×Loki |
| E9 | Spend by model + main/subagent | `cost by(model)`, `by(query_source)` | piechart/timeseries | Prom |
| E10 | Cache $ saved | `(cacheRead_tokens / 1e6) × ($price_input_sonnet45 − $price_cacheread_sonnet45)` | stat + timeseries | Prom |
| E11 | Active time user-vs-cli + adoption | `active_time by(type)`; sessions started per day by `start_type` via `cc:sessions:daily` | timeseries | Prom |

**E11 "adoption" definition [inferred].** The adoption series is **sessions *started* per day, by
`start_type`** (`cc:sessions:daily`) — an adoption-rate proxy, consistent with §8.2. True
*concurrent-active-session* count is **not derivable** from `claude_code_session_count_total` (a
cumulative counter of session *starts*) and would need additional client telemetry; it is Phase-2
(§13) [inferred].

*Dropped (no data source):* cost-per-commit/PR, deliverables-shipped (commits+PRs). These
return in Phase 2 if the git/GitHub exporter (§13) is built.

### 6.3 Shared, reframed

Three measures appear on both, treated differently: **Leverage multiplier**,
**Quality-Adjusted Activity**, **Cost per active hour**. Executive gets the smooth long-range
*trend* (monthly rollup, team-wide); Developer gets the actionable *current value + breakdown*
(self-scoped, with per-tool splits).

## 7. Porting the existing dashboard improvement (already applied)

The fork's `claude-code-dashboard.json` (uid `claude-code-obs`) was reconciled with the live
nuc01 copy. The only delta was the **`Productivity` stat panel** plus the overview-row
behavior:

- Added the `Productivity` stat panel (id 24): `clamp_min(floor(sum(increase(cli_active[$__range])) / sum(increase(user_active[$__range]))), 1)`, unit `suffix:x`, in the Overview row.
- The 4 existing overview stat panels (Active Sessions, Cost, Token Usage, Lines of Code) were
  switched from hardcoded `[1h]` windows to `[$__range]` so they follow the dashboard
  time-picker, and their "(1h)"/"(Last Hour)" title suffixes were dropped.
- Overview row reflowed to 5 panels across 24 cols (widths 5/5/5/4/5), top-level `version`
  bumped. The deliberately hourly-bucketed timeseries panels (ids 5, 12, 19, 20, 21 — the
  "...Hourly" panels) were left untouched; their `[1h]` is a per-bucket window, not a filter.

This is committed to the fork. (Deploy to nuc01 is a separate step — §9.)

## 8. Historical foundation

Default Prometheus retention is 15d. To support multi-month trends we make three changes,
all in the fork's base config (upstream-clean — no homelab specifics):

### 8.1 Retention (`docker-compose.yml`, prometheus service `command:`)
```
--storage.tsdb.retention.time=400d
--storage.tsdb.retention.size=20GB
--storage.tsdb.path=/prometheus
--config.file=/etc/prometheus/prometheus.yml
--web.enable-lifecycle
```
`--web.enable-lifecycle` opens the `POST /-/reload` endpoint so the §9.1 step-3 reload-only
fallback (hot-loading a changed `recording-rules.yml` without recreating the container) actually
works — without it that call returns 405/403 [inferred]. Security note: this leaves an
unauthenticated config-reload endpoint open on the prometheus port; acceptable here because the
NUC stack is Tailscale-only / not internet-exposed, but it must not be enabled on a publicly
reachable prometheus without auth in front of it [inferred]. `retention.size` is a safety cap
against unbounded disk on the NUC; whichever limit hits
first wins. Also mount the new rules file into the prometheus container: add a bind-mount
stanza `./recording-rules.yml:/etc/prometheus/recording-rules.yml:ro` to the prometheus
service `volumes:` in `docker-compose.yml`, so the host file `./recording-rules.yml` (repo
root, alongside `prometheus.yml`) appears at `/etc/prometheus/recording-rules.yml` inside the
container [inferred].

### 8.2 Recording rules (`recording-rules.yml`, new)
A `productivity` group with `interval: 5m` (bounds stored resolution and compute cost). Rules
pre-compute per-user daily rollups so a multi-month dashboard query is cheap. **Trimmed to
metric-backed measures only** — the dropped LoC/commit/decision rules referenced metrics this
client does not emit (§10). Acceptance/decision rate is Loki-only and cannot be a Prometheus
recording rule (see §8.4). Sketch:
```yaml
groups:
  - name: productivity_daily
    interval: 5m
    rules:
      - record: cc:cost_usd:daily
        expr: sum by (user_email) (increase(claude_code_cost_usage_USD_total[1d]))
      - record: cc:active_seconds:daily
        expr: sum by (user_email, type) (increase(claude_code_active_time_seconds_total[1d]))
      - record: cc:leverage:daily
        expr: |
          sum by (user_email)(increase(claude_code_active_time_seconds_total{type="cli"}[1d]))
          / sum by (user_email)(increase(claude_code_active_time_seconds_total{type="user"}[1d]))
      - record: cc:tokens:daily
        expr: sum by (user_email, type) (increase(claude_code_token_usage_tokens_total[1d]))
      - record: cc:cache_hit:daily
        expr: |
          sum by (user_email)(increase(claude_code_token_usage_tokens_total{type="cacheRead"}[1d]))
          / sum by (user_email)(increase(claude_code_token_usage_tokens_total{type=~"input|cacheRead|cacheCreation"}[1d]))
      - record: cc:cost_per_active_hour:daily
        expr: |
          sum by (user_email)(increase(claude_code_cost_usage_USD_total[1d]))
          / (sum by (user_email)(increase(claude_code_active_time_seconds_total[1d])) / 3600)
      - record: cc:sessions:daily
        expr: sum by (user_email, start_type) (increase(claude_code_session_count_total[1d]))
```
**`start_type` is single-metric-only [inferred].** The `start_type` (fresh/resume) label exists
*only* on `claude_code_session_count_total` — not on `active_time`/`cost`/`token_usage`, and there
is no `session_id` join key on any metric. So D10 can only roll up **session starts by type over
time** (`cc:sessions:daily` by `start_type`), which it does. Attributing active_time / cost / tokens
to fresh-vs-resume sessions is **Phase-2 (§13)** — it requires a `session_id` label this client does
not emit [inferred].
`prometheus.yml` adds `rule_files: [/etc/prometheus/recording-rules.yml]` (absolute container
path matching the §8.1 bind-mount) and a global `evaluation_interval: 1m` [inferred]. The
default `1m` is kept (rather than matching the group's `interval: 5m`) so the rules re-evaluate
promptly relative to the scrape interval; the `5m` group `interval` already bounds how often
this specific group runs, so the global knob stays at the conventional default [inferred].

**Zero-handling for ratio rules:** the three ratio rules (`cc:leverage:daily`,
`cc:cache_hit:daily`, `cc:cost_per_active_hour:daily`) divide by a denominator that is zero on
days with no `user_active` time / no token activity / no active time, yielding no-data gaps that
propagate to trend panels. v1 policy: **leave the denominators unguarded and accept the gaps** —
a day with zero denominator genuinely has no meaningful ratio, so the resulting `cc:*:daily` gap
is correct, and panels render it as "no data" rather than a misleading `0` [inferred]. Panels
backed by these rules therefore must not interpolate across gaps (connect-null-values OFF)
[inferred].

### 8.3 Collector retention (`collector-config.yaml`)
Raise the Prometheus exporter `metric_expiration` from the current `2h` to `24h`. This is
**mandatory, not optional** (§10.4): at 2h the exporter drops any metric series unseen for two
hours, so cross-session gaps appear as counter resets and lifetime/cumulative panels
undercount. 24h comfortably spans normal between-session gaps.

### 8.4 Loki retention + Loki-based history (`loki` config)
About half the panels (acceptance, friction, per-prompt) query **Loki events**, so Loki must
also retain months of data. Default Loki retention is short; extend it via the compactor /
`limits_config.retention_period` (proposed: `400d`, matching Prometheus) with retention
deletion enabled. Edit the deployed Loki config file `loki-config.yaml` (host path
`./loki-config.yaml`, repo root; bind-mounted into the loki container) to add the compactor and
retention settings, and confirm `schema_config` uses a retention-capable store [inferred]:
```yaml
limits_config:
  retention_period: 400d
compactor:
  working_directory: /loki/compactor
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  delete_request_store: filesystem
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb            # or boltdb-shipper — must be a shipper store for retention to apply
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
```
**Schema migration is OUT-OF-SCOPE for v1 [inferred].** v1 scopes the Loki change to the
**additive `limits_config.retention_period` + `compactor` blocks only**, applied on top of an
*already-shipper-backed* deployment. This is gated by a **pre-flight check (a §12
verification-plan step):** before any of this work starts, confirm the deployed
`loki-config.yaml`'s `schema_config` already uses a shipper store (`boltdb-shipper` or `tsdb`)
with a 24h index period [inferred]. If — and only if — that pre-flight passes, the additive
blocks above are sufficient and the `schema_config` shown is descriptive (it documents the
expected existing shape, not a change to apply) [inferred]. If the pre-flight finds a non-shipper
store (e.g. the legacy `boltdb` index), retention extension **defers to Phase 2 (§13)**: a Loki
`schema_config` migration is non-trivial (it requires a new dated `schema_config` entry with a
future `from:` date, dual-store reads across the cutover, and risks orphaning existing index
data) and v1 does not specify that migration procedure [inferred]. For v1, Loki-based panels
use **live LogQL over the selected range** — the
event volumes are modest (a few thousand per 15d) so long-range queries are acceptable. A
future optimization is the Loki **ruler** writing recorded series (e.g. daily accept-rate)
back to Prometheus via `remote_write`, mirroring §8.2 for Loki — deferred (§13).

## 9. Repo & deploy strategy

Two source-of-truth repos, kept distinct:
- **`ai-ready-future/claude-code-otel` (this fork)** — generic Claude Code observability:
  the three dashboards, collector config, prometheus + recording rules, base compose. This is
  where all work in this spec is committed. The two new dashboard files live at the repo root
  alongside the existing `claude-code-dashboard.json`, named `dev-productivity-dashboard.json`
  (uid `claude-code-dev-productivity`) and `exec-roi-dashboard.json`
  (uid `claude-code-exec-roi`) [inferred]. They are picked up by the **same Grafana file-
  provisioning provider** that already loads the existing dashboard — i.e. the provider's
  folder/path glob in the provisioning config (`grafana/provisioning/dashboards/*.yaml`) must
  point at the directory containing all three JSON files, so no new provider entry is needed if
  the existing provider already globs the directory; if it references the single file by name,
  add the two new filenames (or switch it to a directory glob) [inferred].
- **`404pilo/home` (`infra/nuc01/`)** — the actually-deployed homelab variant (override
  compose with hardware scrapes, ntfy alerting, Funnel exposure). Homelab-specific deltas
  (e.g. the retention flag must also land in the deployed `docker-compose.override.yml`
  mirror) are applied here.

**Deploy path (out of band of the fork commit):** nuc01's `/home/jazz/claude-code-otel/` is
NOT a git checkout — it is a flat deployed copy. After committing to the fork, deployment
copies the changed dashboards/config to nuc01, bumps each dashboard's `version`, and runs
`docker compose restart grafana` (dashboard reload requires it — provisioner does not
hot-reload) and a prometheus restart (for the retention flag + rules). Recording rules can be
hot-loaded with a prometheus config reload. See memory note `grafana-provisioned-dashboard-reload`.

### 9.1 Concrete deploy steps [inferred]

The deploy is a manual `rsync` from the local fork checkout to the flat copy on nuc01, followed by two scoped restarts, in this order [inferred]:

1. **Copy changed files.** From the local fork root, push the in-scope dashboards and config to the deployed copy [inferred]:
   ```
   rsync -av --relative \
     claude-code-dashboard.json dev-productivity-dashboard.json exec-roi-dashboard.json \
     docker-compose.yml prometheus.yml recording-rules.yml \
     collector-config.yaml loki-config.yaml \
     nuc01:/home/jazz/claude-code-otel/
   ```
   (Only the files actually changed in a given deploy need be listed; the homelab override files in `404pilo/home` are deployed separately, not by this rsync.) [inferred]
2. **Version bump rule.** Each dashboard's top-level `version` field is bumped **manually** (increment by 1) as part of the same commit that changes the dashboard JSON — Grafana's provisioner only reloads a dashboard whose `version` is higher than the one already in its database [inferred].
3. **Restart prometheus** (picks up the retention-flag change in `docker-compose.yml` and the new `rule_files` mount) [inferred]:
   ```
   docker compose up -d --force-recreate prometheus
   ```
   If only `recording-rules.yml` changed (no compose/flag change), a config reload is sufficient instead: `curl -X POST http://localhost:9090/-/reload` [inferred].
4. **Restart grafana** to force a dashboard re-provision (the provisioner does not hot-reload) [inferred]:
   ```
   docker compose restart grafana
   ```
5. **Restart the collector** only if `collector-config.yaml` changed (e.g. the `metric_expiration` bump): `docker compose up -d --force-recreate otelcol` [inferred].

`docker compose` commands run from `/home/jazz/claude-code-otel/` on nuc01 [inferred].

> Open decision (deferred, non-blocking): whether to make nuc01 a real git checkout of the
> fork to eliminate the manual copy step. Out of scope for v1.

## 10. Metric emission status (pre-flight — VERIFIED 2026-06-01)

Live check against nuc01 Prometheus + Loki. The reality differs materially from the
documented catalog and reshapes the data-source strategy: **most productivity signal lives in
Loki events, not Prometheus metrics, in the running client versions (2.1.143–2.1.159).**

### 10.1 Prometheus metrics — only 4 families exist
| Metric | Status | Notes |
|---|---|---|
| `claude_code_token_usage_tokens_total` | ✅ PRESENT | `type`(input/output/cacheRead/cacheCreation), `model`, `query_source`(main/subagent/auxiliary) all populate |
| `claude_code_cost_usage_USD_total` | ✅ PRESENT | `model`, `query_source` populate |
| `claude_code_active_time_seconds_total` | ✅ PRESENT | `type` cli/user |
| `claude_code_session_count_total` | ✅ PRESENT | `start_type` fresh/resume |
| `claude_code_lines_of_code_count_total` | ❌ ABSENT | client does not emit as a metric |
| `claude_code_commit_count_total` | ❌ ABSENT | client does not emit as a metric |
| `claude_code_pull_request_count_total` | ❌ ABSENT | client does not emit as a metric |
| `claude_code_*decision*` | ❌ ABSENT (as metric) | exists as Loki `tool_decision` event instead |

### 10.2 Attribution labels are privacy-bucketed in metrics
On `token_usage`/`cost_usage`: `skill_name`/`plugin_name` collapse to the literal
`third-party`; `mcp_server_name`/`mcp_tool_name` collapse to `custom`. Only `agent_name`
(`general-purpose`, `workflow-subagent`) carries real values. `speed` is never set; `effort`
is only ever `high`. **⇒ 🌟 skill/plugin/MCP attribution is dead in metrics.** The Loki
`api_request` event, however, carries the *full* attribution (real `query_source` strings like
`agent:builtin:general-purpose`, `speed`, `effort`) — so attribution must be built from Loki.

### 10.3 Loki events — all present, rich, 15d+ of data
| Event | 15d count | Useful fields |
|---|---|---|
| `tool_decision` | 4143 | `decision`(accept/reject), `source`, `tool_name` ← **acceptance rate lives here** |
| `tool_result` | 4109 | `success`, `duration_ms`, `tool_name`, `tool_input_size_bytes`, `tool_result_size_bytes` |
| `api_request` | 4080 | tokens, `cost_usd`, `duration_ms`, `model`, `effort`, `speed`, `agent_name`, full `query_source` |
| `user_prompt` | 409 | prompt metadata |
| `api_error` | 6 | `error`, `attempt`, `status_code`, `model`, `duration_ms` |

### 10.4 Two config truths
- **`metric_expiration: 2h`** (collector prometheus exporter) silently drops any metric series
  unseen for 2h. Historical TSDB samples already scraped are retained, but cross-session gaps
  appear as counter resets and any "lifetime cumulative" panel undercounts. **Bump to 24h**
  (§8.3) — now strongly justified, not optional.
- Collector metrics pipeline is a clean passthrough (`otlp → resource → [prometheus, debug]`),
  no filtering. So the metric absences are **client-side** (not emitted as metrics by this
  version), not a collector config gap.

### 10.5 Consequence for the allocation
- **Build on Prometheus:** leverage, autonomy, cost trend, cost/active-hour, cache ratio &
  cache $ saved, output density, active-time, session-type rollups.
- **Build on Loki (not Prometheus):** acceptance/decision rate (+ by tool), all friction
  panels (retry tax, tool-failure cost, interruption index), real attribution
  (by `agent_name` / `query_source` / `model` / `effort` / `speed`), per-prompt measures.
- **No data source anywhere (v1):** commit count, PR count, true lines-of-code. These require
  a separate git/GitHub exporter (see §13 future work) — they are NOT in Claude Code telemetry.

See §6 for the per-panel revised status flags.

## 11. Risks & mitigations

- **Empty panels mislead** ("is it broken or just no data?"). Mitigation: per-panel "no data"
  text + the pre-flight annotations; group not-yet-flowing panels so their emptiness is
  expected.
- **Disk growth** from 400d retention. Mitigation: `retention.size=20GB` cap; recording rules
  keep query cost flat regardless of raw cardinality; revisit if the NUC disk tightens.
- **Cardinality** from per-user × per-model/query_source/agent attribution. Mitigation:
  attribution panels aggregate `by(label)` at query time; recording rules stay keyed on
  `user_email` (plus `type`/`start_type`) only.
- **Pricing constants** for "Cache $ saved" / "Cost of rejected work" must be maintained as
  the model price list changes. Mitigation: keep prices as **Grafana constant-type template
  variables** (not text panels — text panels can't be referenced in queries), one per
  (model, token-type) pair, so panels like E10 can multiply against them [inferred]. **Unit
  convention (load-bearing) [inferred]:** all `$price_*` variables are **USD per 1,000,000 tokens**.
  Since `claude_code_token_usage_tokens_total` counts *raw* tokens, any panel that multiplies a token
  count by a price variable **must divide the token count by `1e6` first** — stated once here and
  applied in E10's formula. Omitting the `/ 1e6` overstates dollars by 1,000,000×. v1
  ships per-million-token USD constants for the in-use Sonnet 4.5 model, with initial values
  from the current Anthropic price list (verify at deploy time) [inferred]:
  `$price_input_sonnet45 = 3.00`, `$price_output_sonnet45 = 15.00`,
  `$price_cacheread_sonnet45 = 0.30`, `$price_cachewrite_sonnet45 = 3.75` [inferred].
  E10 ("Cache $ saved") references `$price_input_sonnet45` and `$price_cacheread_sonnet45`,
  scaling the cacheRead token count by `/ 1e6` per the unit convention above —
  `(sum(increase(claude_code_token_usage_tokens_total{type="cacheRead"}[$__range])) / 1e6) × ($price_input_sonnet45 − $price_cacheread_sonnet45)` [inferred];
  E6 ("Cost of rejected work") uses the already-emitted `claude_code_cost_usage_USD_total`
  (no price variable needed) [inferred]. Add a per-model variable set if/when multiple models
  appear in `query_source`/`model` labels; treat all as estimates, labeled as such [inferred].
- **`user_email` sparsity** (only on OAuth auth) breaks the `$user` filter. Mitigation: the
  documented fallback chain `user_email → user_account_id → user_id`.

## 12. Verification plan

1. Pre-flight emission check (live Prometheus/Loki) — DONE; results in §10.
1a. **Pre-flight: Loki schema store (gates §8.4).** Confirm the deployed `loki-config.yaml`'s
   `schema_config` already uses a shipper store (`boltdb-shipper`/`tsdb`) with a 24h index period.
   Read what the **running** Loki process actually loaded (not the on-disk file, which may not yet be
   reloaded) — run on nuc01 [inferred]:
   ```
   docker exec loki cat /etc/loki/config.yaml | grep -A3 schema_config
   ```
   **Pass** = output contains `store: tsdb` *or* `store: boltdb-shipper` **and** `period: 24h`.
   If pass, apply the additive `limits_config`/`compactor` blocks; if a non-shipper store (e.g.
   `boltdb`) or non-24h period, retention extension defers to Phase 2 (§13) — schema migration is
   out of v1 scope [inferred].
1b. **Pre-flight: LogQL structured-metadata matcher (gates all Loki panels).** Run one matcher-form
   query (e.g. `sum(count_over_time({event="tool_decision"} | decision="accept" [1h]))`) and confirm
   it returns a **non-empty** result before authoring any Loki/Prom×Loki panel. Do NOT use `| json`
   on these events (fields are structured metadata) [inferred]. **Also validate the two
   higher-order LogQL forms D11/D12 depend on** (the string-equality matcher above does *not* prove
   either) [inferred]:
   - **Numeric comparator (gates D11 `| attempt>1`):**
     `sum(count_over_time({event="api_error"} | attempt > 1 [1h]))` must return non-empty.
   - **Unwrap on metadata (gates D12 `duration_ms` sum):**
     `sum(sum_over_time({event="tool_result"} | success="false" | unwrap duration_ms [1h]))` must return non-empty.
   If the numeric form fails, defer D11's numeric filtering to Phase-2 (log-line JSON extraction); if
   the unwrap form fails, defer D12's `duration_ms` sum to Phase-2 (§13) and ship D12 as a plain
   failure *count* only [inferred].
1c. **Pre-flight: Loki `user_email` scoping (gates `$user` on all Loki/Prom×Loki panels).** Run
   `{event="tool_decision"} | user_email!=""` against the deployed Loki and confirm a **non-empty**
   result [inferred]. If non-empty, every Loki and Prom×Loki query appends the structured-metadata
   label filter `| user_email=~"$user"` to its stream selector (post-selector label filter, *not* an
   in-`{}` matcher). If ABSENT, the developer dashboard's `$user` self-scoping is **Prometheus-only
   for v1**; Loki panels are **team-wide** and labeled as such in their panel descriptions (§5)
   [inferred].
2. After implementation: load each dashboard in Grafana, confirm every panel either renders
   data or is an expected-empty (annotated) panel; confirm `$user` switches scope correctly.
3. Confirm retention took effect: `GET /api/v1/status/runtimeinfo` shows `storageRetention`
   ~400d; confirm `cc:*:daily` recording-rule series exist via `count by (__name__)({__name__=~"cc:.*"})`.
4. Confirm a multi-month time-range renders the trend panels quickly (recording rules path).
5. Smoke-test the deploy reload procedure (version bump + grafana restart) on nuc01.

## 13. Future work (Phase 2, out of v1 scope)

- **Git/GitHub deliverables exporter.** A small exporter that scrapes real commits, merged
  PRs, and merged lines-of-code per author/repo into Prometheus — independent of Claude Code
  telemetry. Restores the dropped Executive panels (cost-per-commit/PR, deliverables shipped,
  Quality-Adjusted *Output* using true net-LoC). Pursued only if executives want true delivery
  metrics; v1 ships the honest activity-proxy versions instead.
- **Loki ruler recording rules.** Pre-aggregate Loki-derived daily measures (accept rate,
  tool-failure rate) and `remote_write` them to Prometheus as `cc:*:daily` series, so the
  Loki-based panels get the same cheap long-range path as the metric-based ones (§8.4).
- **Fresh-vs-resume cost/token attribution.** Attributing active_time / cost / tokens to session
  `start_type` (the original D10 ambition) requires a `session_id` label common to
  `session_count_total` and the cost/token/active_time metrics — not emitted by this client.
  Revisit if a future client version adds a `session_id` (or `start_type`) label to those metrics.
- **Re-evaluate on client upgrade.** If a future Claude Code version emits `lines_of_code` /
  `commit` / `code_edit_tool.decision` as metrics (or stops privacy-bucketing skill/plugin/MCP
  names), revisit §6 to move those panels back onto Prometheus and re-enable real attribution.

## Refinement Status

Refinement: CONVERGED round 4

Adversarial spec-simulator ↔ spec-fixer loop (relay:refining-specs). Convergence = no
critical/important findings remained.

| Round | Findings (crit/imp/min) | Fixer result |
|---|---|---|
| 1 | 1 / 8 / 6 | addressed 9, skipped 6 minor |
| 2 | 1 / 4 / 2 | addressed 5, skipped 2 minor |
| 3 | 3 / 5 / 0 | addressed 8 |
| 4 | 0 / 0 / 2 | CONVERGED (2 minor accepted) |

Notable gaps closed across the loop: §9.1 concrete deploy steps (rsync + ordered restarts);
Loki retention scoped to additive blocks with a shipper-store pre-flight (§12.1a); LogQL
structured-metadata matcher/numeric/unwrap pre-flights (§12.1b) and `user_email` `$user`-scoping
pre-flight (§12.1c); §5↔§10.1 metric-name reconciliation; D0/E0 stat-rows clarified as 4
single-source panels; the Prom×Loki Mixed-datasource A÷B/A×B worked examples (D6, E6); the E10
pricing **per-1M-token / `1e6` scaling** fix (was a latent 1,000,000× error); and reframes of the
unimplementable-as-written D2, D10, E2, E11 panels to metric-backed proxies with Phase-2 deferrals.

Accepted minor (round 4, non-blocking — derivable by the plan author): new dashboards reuse
`claude-code-dashboard.json`'s datasource-UID lookup (`grafana/provisioning/datasources/`), `tags`
convention, and 24-col row + `gridPos` layout conventions with sequential per-dashboard panel ids. [inferred]
