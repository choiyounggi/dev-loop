# Knowledge consolidation — 15 open PRs (#17–#40) → one reconciled state

The 15 open `knowledge/*` PRs (created 2026-08-04 → 2026-08-05, before the
harvest processed-store dedupe fix in #41) contained 123 file-versions of ~75
unique pages, with the same insight landing at up to 3 different paths across
up to 8 PRs. Per-PR review would re-import those duplicates, so — as with the
#6–#13 consolidation — this branch carries the reconciled end-state and the 15
PRs are closed in its favor.

## Verified best-practice

Every adopted page's sources were carried from its originating PR's flush, where
they were live-verified at flush time; no new URLs were introduced during
consolidation (checked mechanically: every `http(s)` URL in every merged page
appears in a source PR's diff; every added body line in amended pages traces to
a source PR hunk — orphan-line verification). Confidence fields were kept as the
originating flushes set them, except client-side-rate-limiting where the union
of provider-doc citations (Okta, Auth0, GitHub, OpenAI, RFC 6585) supports
`verified` for the load-bearing claims. One subagent's fabricated content (12
files matching neither main nor any PR, with invented source URLs) was detected
by the same verification and replaced with true PR content.

## Existing-layer check

- Merged-main near-dup scan before consolidation: pairwise Jaccard over
  title + "When this applies" across all 141 merged pages → **0 flagged pairs**;
  previously merged content carries no duplication.
- Cross-PR dedup during consolidation: 10 duplicate clusters collapsed to one
  canonical page each (rate limiting 8→1, call-site enumeration 7→folded into
  the canonical merged in #20, stderr/exit-0 diagnostics 4→1, sysroot 2→1,
  env-off-switch 2→1, completion predicates 2→1, robots.txt 2→1,
  harness-mediated results 2→1, leaked artifacts 2→1, orchestration category
  naming unified). Three near-pairs kept distinct after trigger comparison,
  with mutual `related:` links (differential setup vs interpretation; expansion
  semantics vs off-switch design; import-time tactics vs level choice).
- 24 existing pages received union-merged amendments; additions already present
  in main (from #16/#20) were skipped, and all non-canonical `related:` ids
  were remapped to canonical page ids (post-merge broken-link scan: 0).

## Routing decision

- New categories: `infrastructure/agent-orchestration` (5 pages; unified the
  competing `orchestration`/`agent-orchestration` names), `databases/data-survey`
  (1), `qa/deliverables` (1). All other pages route into existing categories.
- Canonical-path decisions: rate limiting → `backend/common/reliability/`
  (sits beside timeouts-and-retries; 6 of 8 variants chose it); stderr
  diagnostics → `platforms/processes/` (concern spans beyond shells); leaked
  artifacts → `testing/data/artifact-leakage-from-a-suite`; call-site
  enumeration → the existing `backend/common/change-impact/` page.
- All 38 new pages listed in their domain indexes (nearest-index rule; backend
  routes via its python sub-index for bytecode-cache-staleness); INDEX.md domain
  summaries updated for infrastructure/qa/databases. Full-wiki lint: frontmatter,
  ids, related-links, index coverage, size, qualifiers, staleness → 0 findings.
