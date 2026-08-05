# Task 03: Category taxonomy sufficiency audit (all development perspectives)

## Objective
`plans/wiki-audit/findings/categories.md`: the full category inventory (domain ×
category × page count), each D3 checklist concern matched to where it lives today
or judged "genuine gap" vs "out of charter" with a 1-line rationale, plus overlap/
ambiguity findings between existing categories (two categories a router could
confuse), ready to be filed as issues in task 06.

## Wiki pages (read these first, only these)
- (none — the taxonomy itself is the audit object)

## Inputs
- plans/wiki-audit/findings/routing.md (task 02 — MISS probes are gap evidence)
- All 10 wiki/<domain>/index.md files; INDEX.md
- Decisions that bind you: D3 (fixed reference taxonomy), D4 (enhancements → issues)

## Steps
1. Build the inventory table: `find wiki -mindepth 2 -maxdepth 2 -type d` + page
   counts per category.
2. Walk the D3 checklist concern by concern: requirements/planning, architecture/
   design, API design, concurrency, distributed systems, messaging/queues, caching,
   networking, observability, performance, docs/i18n, data engineering/ML, config
   mgmt/releases, cost, accessibility, compliance/privacy. For each: covered-where
   (exact domain/category), partially-covered (name the missing slice), or gap.
3. Ambiguity pass: list category pairs whose "load when" scopes overlap enough to
   misroute (e.g. testing/quality vs qa/document-verification), citing the
   overlapping line text.
4. For every "genuine gap": propose target domain, category name, and 2–3 seed
   page titles — concrete enough for a future ingest.

## Deliverables
- plans/wiki-audit/findings/categories.md

## Verify
- Every D3 checklist concern appears exactly once in findings/categories.md with a
  verdict; `grep -c '^| ' ` on the concern table ≥ 16 rows.

## Out of scope
- Creating any new category or page (owner-approval scope — issues only, task 06);
  routing-line rewording (task 02's findings).
