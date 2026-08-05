# Findings — Task 03: Category taxonomy sufficiency (all development perspectives)

Inventory: 10 domains, 60 leaf categories, 141 pages (counts per category in the
sweep output; largest: testing/quality 7, databases/schema-design 8; 24
categories hold exactly 1 page — healthy for a case-routed wiki, not a defect).

## D3 checklist walk

| Concern | Verdict | Where it lives today / what's missing |
|---------|---------|----------------------------------------|
| Requirements/planning | partial — acceptable | qa/process/acceptance-criteria + databases/requirements-to-tables; task decomposition is owned by the wiki-plan skill, not the wiki. No action. |
| Architecture/system design | **genuine gap (G1)** | No category owns "where does this logic live / sync call vs queue vs event / module boundaries". backend/common has point-patterns only. An implementation-planning wiki needs this: wiki-plan's design decisions currently go `[no-wiki]` here. |
| API design | partial → **gap slices (G2, G3)** | api-design has error-responses, idempotency, pagination-contract. Missing: **CORS & preflight** (top-frequency LLM implementation stumble) and **API versioning / breaking-change policy for public APIs** (call-site-enumeration covers internal contracts only). |
| Concurrency | covered | backend/common/concurrency + stack pages (kotlin coroutines, GIL, event loop) + databases/transactions + debugging/concurrency. |
| Distributed systems | partial → **gap slice (G10)** | distributed-locks + idempotent-handlers exist. Missing: multi-service write consistency (saga/outbox-beyond-enqueue, delivery-guarantee semantics: at-least-once vs exactly-once claims, event ordering). |
| Messaging/queues | mostly covered | jobs/idempotent-handlers (consumer side incl. DLQ/outbox) + scheduled-job-overlap. Producer-side topology/schema-evolution thin — fold into G10. |
| Caching | covered | caching/invalidation-and-stampede (keys, tenancy, stampede). HTTP/CDN caching partially in frontend/performance — acceptable. |
| Networking | partial → **gap slices (G2, G6)** | security/api-exposure owns edge/proxy. Missing: CORS (G2); **WebSocket/SSE/realtime lifecycle** (reconnect, backpressure, auth on long-lived connections) — graceful-shutdown only brushes it (G6). |
| Observability | covered | infrastructure/observability ×3 + debugging/signals. |
| Performance | partial — acceptable | frontend/performance, debugging/performance, mobile/startup-time, databases/query-optimization. Load/capacity testing absent (G8, low priority). |
| Docs & i18n | **gap (G7, lower priority)** | qa/document-verification is about *gating* docs, not writing them (fine). UI i18n/l10n (string externalization, pluralization, RTL) has no home; platforms/timezone-and-locale covers only OS locale mechanics. |
| Data engineering/ML | partial — acceptable | LLM *consumption* well covered (backend/common/llm ×2). ML training: out of charter (routing probe 15 confirms clean MISS). Missing slice: **data backfill/transform migrations** beyond DDL (G5) — online-schema-changes covers DDL locking, not batched backfill/dual-write verification. |
| Config mgmt/releases | partial → **gap slice (G4)** | infrastructure/config + deploy + mobile/release. **Feature-flag lifecycle** (naming, targeting, cleanup debt, kill-switch vs experiment) is referenced by rollout pages but owned by none. |
| Cost | out of charter | Cloud cost rarely decides code-level implementation cases this wiki routes. Revisit if orchestrate grows infra-provisioning tasks. |
| Accessibility | partial — acceptable | frontend/accessibility/interactive-elements. Forms-labeling/contrast/landmarks would fit as siblings when real cases arrive (ingest-driven growth is the charter). |
| Compliance/privacy | partial — acceptable | security/data/pii-handling (retention, erasure, test data). Audit-trail design (G9, low priority) unowned. |

## Category-pair ambiguity (router confusion risk)

| Pair | Evidence | Severity |
|------|----------|----------|
| testing/quality (doc-gate cluster: spec-artifact-checks, checks-that-cannot-pass, schema-additions-under-a-golden-gate, harness-reverse-controls) vs qa/document-verification (spec-document-gates, editing-a-gated-document) | Routing probe 6: both claim "automated checks that decide whether a spec document meets requirements" | high — 6 pages across 2 domains, one concern |
| testing/flaky vs debugging/concurrency/intermittent-failures | Routing probe 7: both triggers claim "flaky test / fails only in CI / passes on retry" verbatim | medium |
| infrastructure/data/backup-and-restore vs databases/operations | A DB operator looking for backups plausibly opens databases first; no cross-pointer in databases/index.md | low — add one cross-pointer line |
| backend/common/integrations (holds 1 page: externally-owned-defaults) | Category name promises third-party integration patterns broadly; content is one narrow case. Rename risk vs growth headroom | low — leave, revisit at 3+ pages |

## Proposed seeds for genuine gaps (for issues)

- **G1 backend/common/architecture**: `sync-vs-async-integration` (direct call vs
  queue vs event — decision table by consistency/latency/failure-isolation),
  `module-boundaries-and-layering`, `event-driven-adoption-criteria`.
- **G2 backend/common/api-design/cors-and-preflight**: browser-origin API calls
  failing on CORS; wildcard-vs-allowlist; credentials mode; preflight caching.
- **G3 backend/common/api-design/api-versioning-and-breaking-changes**.
- **G4 infrastructure/deploy/feature-flag-lifecycle** (or backend/common).
- **G5 databases/operations/data-backfill-migrations**: batching, dual-write,
  verification queries, resumability.
- **G6 backend/common/realtime/websocket-sse-lifecycle**: auth, reconnect,
  heartbeat, backpressure, shutdown draining.
- **G7 frontend/i18n** (lower), **G8 testing/strategy/load-testing** (lower),
  **G9 security/data/audit-trails** (lower), **G10
  backend/common/distributed/cross-service-writes** (saga/outbox/delivery
  guarantees).

## Verdict (axis 3)

The 60 existing categories are coherent and, with two exceptions (doc-gates
split, flaky-test dual ownership), unambiguous. The taxonomy's real weakness for
a *planning* wiki is the missing architecture/design layer (G1) and a handful of
high-frequency implementation cases (CORS G2, versioning G3, flags G4, realtime
G6, backfill G5). All are additive — no restructuring required.
