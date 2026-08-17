# Knowledge consolidation — 30 open PRs (#47–#110) → one reconciled state

The 30 open `knowledge/*` PRs (created 2026-08-06 → 2026-08-17, all after the
harvest processed-store dedupe fix in #41) each carried flush-time dedup against
the then-open PR set, but every branch also rewrote `log.md` and this report and
several branches amended the same pages, so per-PR merge meant a conflict
cascade at every step. As with the #17–#40 consolidation, this branch carries
the reconciled end-state and the 30 PRs are closed in its favor.

## Method

Branches were merged chronologically (PR order #47 → #110) onto post-#111 main.
Non-bookkeeping conflicts were union-resolved per file: `related:` lists as id
unions, `last_verified` as the max date, index "load when" rows as the newer
routing framing plus the branch's genuinely new trigger clauses, edge-case
tables as row unions with duplicate-substance rows dropped (one row in
worktree-isolated-workers whose budgeting advice restated an already-merged
row). `log.md` was rebuilt by splicing every branch's own entries into date
order (44 entries added); each branch's added wiki pages were verified present
in the final tree (0 missing).

## Existing-layer check

- Flush-time dedup notes were honored as recorded in each PR title (e.g. #74's
  two insights folded into #73/#52's pages arrive via those branches; #86's
  duplicate dropped); no dropped insight was re-imported.
- Where a branch's index row diverged from a later routing revision already on
  main (the 2026-08-12 disjoint-scope revision for spec-document-gates vs
  testing/quality), the merged row keeps the revision's scope and carries only
  the branch's new trigger clauses.
- Post-merge scans: 0 conflict markers, broken-link scan and index-coverage
  lint run on the final tree (see log entry).

## Open-PR check

This consolidation *is* the reconciliation of the open-PR backlog: all 30 open
`knowledge/*` PRs (#47–#110) are merged into this branch and closed in its
favor. No other open knowledge PRs remain; #111 was merged to main first and
this branch is based on it.

## Routing decision

- New categories: `backend/common/ml` (mape-aligned-point-prediction),
  `backend/python/packaging` (data-files-and-install-paths),
  `security/incident-response` (verifying-assumed-security-agents,
  process-identity-by-path-and-hash). All other 53 new pages route into
  existing categories; 51 existing pages received union-merged amendments.
- All new pages are listed in their domain indexes (nearest-index rule);
  INDEX.md domain summaries updated for backend, frontend, security.
