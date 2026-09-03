# Root Index — Domain Map

Route by matching a "route here when" line, then open that domain's `index.md`.
Load nothing else at this level. What you match is your current **task** when
planning, and the **diff in front of you** when reviewing — one table, two inputs
(routing protocol step 7, `AGENTS.md`).

`scaffold` domains have **no pages yet** — do not route into them expecting answers;
follow the cross-pointers in their index or take the next matching seeded domain
(routing protocol step 1, `AGENTS.md`).

| Domain | Status | Route here when |
|--------|--------|-----------------|
| [databases](wiki/databases/index.md) | **seeded** | Choosing a datastore/database type for a workload (relational vs document vs vector vs graph), designing schemas/tables/keys, choosing or evaluating indexes, writing or optimizing queries, choosing transaction/isolation behavior, surveying live data to derive a rule, verifying additive migrations |
| [backend](wiki/backend/index.md) | **seeded** | Server-side application code — language-agnostic (`common/`: API contracts, call-site enumeration before a contract change, idempotency, JWT, timeouts/retries, caching, jobs, transactions in app code, shared state/pools, errors, consuming LLM APIs (completion validation, context budgeting), authoring agent-facing artifacts (binding instruction text, agent tool-surface granularity/parity), MAPE-aligned point-prediction calibration, consuming external-API responses, externally-owned defaults, object-storage references, sync-vs-async integration choice, WebSocket/SSE connection lifecycle) plus stack subtrees: `java/` (JPA, Spring proxies, JVM threads/memory), `node/` (event loop, promises, runtime validation, shutdown), `python/` (GIL/asyncio, pydantic, WSGI/ASGI workers, language traps, packaging data files with `importlib.resources`) |
| [frontend](wiki/frontend/index.md) | **seeded** | Web UI code: state placement, rendering performance, in-UI data fetching (races, infinite scroll), auth token handling, forms, XSS-safe output, accessibility, agent-facing tool surfaces (WebMCP) |
| [infrastructure](wiki/infrastructure/index.md) | **seeded** | CI/CD pipelines, secrets in build/deploy, container image builds, rollout/rollback strategy, observability (logs/metrics/alerting), per-environment/path-valued config, multi-agent orchestration (worker liveness signals, shared run state, tmux pane delivery, completion gates, worktree-isolated workers, autonomous ask-vs-rule decisions, session context/token budgeting) |
| [testing](wiki/testing/index.md) | **seeded** | Writing or structuring automated tests: level choice, test-before-code ordering, cases/assertions, cross-layer effect scoping, test data, mock decisions, flaky tests (release-process quality → qa) |
| [qa](wiki/qa/index.md) | **seeded** | Release-quality process: release gates, regression scoping, bug reports, severity/priority triage, evidence for completion claims, acting on code-review feedback, adversarial review of high-risk diffs, exploratory testing (guarded-path coverage, override matrices), scope-purity gates, sourcing deliverable documents from generated artifacts, verifying the quantitative claims in a document before publishing it, automated verification of document deliverables (spec/RFC gates) (writing automated test code → testing) |
| [debugging](wiki/debugging/index.md) | **seeded** | Diagnosing a failure — finding what is wrong and why: reproducing, bisection, hypothesis testing, traces/logs, intermittent failures (fixing the diagnosed fault → its owning domain) |
| [security](wiki/security/index.md) | **seeded** | Trust-boundary decisions: input validation, session-vs-token auth choice, per-resource authorization (IDOR), secrets hygiene, dependency trust, PII handling, in-session agent tool exposure (prompt-injection blast radius), the author identity a commit publishes to a public repository, host-compromise triage / incident response (verifying assumed security agents, identifying masquerading processes) (XSS rendering → frontend; CI secrets → infrastructure; JWT implementation → backend/frontend auth) |
| [platforms](wiki/platforms/index.md) | **seeded** | OS-level differences breaking code across macOS/Linux/Windows: shell portability, BSD-vs-GNU CLI, filesystem case/line endings, Unicode normalization in text/file-name matching, commands inspected before execution, background services/cron, invoking prompt-capable CLIs non-interactively, toolchain version pinning |
| [mobile](wiki/mobile/index.md) | **seeded** | App-side iOS/Android/cross-platform: process death/state survival, offline-first sync, mobile-network calls, store rollout/hotfix strategy, startup time |

All ten domains are seeded. New categories grow via `skills/wiki-ingest/SKILL.md`.
