# Task 01: Mechanical lint sweep of all wiki pages and indexes

## Objective
A findings file `plans/wiki-audit/findings/structure.md` listing every mechanical
defect across the 154 wiki pages + 10 domain indexes + INDEX.md, each with the
command that found it and the hit count (0-hit sweeps stated explicitly); defects
that the wiki-lint fix protocol allows fixing directly are fixed on this branch.

## Wiki pages (read these first, only these)
- wiki/qa/document-verification/spec-document-gates.md — use for: designing checks
  that assert structure, not keyword presence

## Inputs
- skills/wiki-lint/SKILL.md — the 10-check rubric (checks 1–10, severities, fix protocol)
- AGENTS.md — frontmatter schema, section skeleton, banned qualifiers list
- Decisions that bind you: D1 (rubric + scripts in .claude/tmp/), D4 (fix vs issue split)

## Steps
1. Write `.claude/tmp/lint-sweep.sh` implementing mechanical projections of the
   lint checks: frontmatter fields present (id/domain/category/confidence/sources/
   last_verified/related); id matches `<domain>-<category>-<slug>` and file path;
   `related:` ids resolve to existing page ids; every page listed in its domain
   index and vice versa; body ≤120 lines; banned qualifiers (usually, consider,
   might, generally, as appropriate) in directive sentences; `verified` with empty
   sources; `unverified` age; bare don't/never/avoid outside `Instead of` tables.
2. Run it; record every finding + command + count in findings/structure.md.
3. Apply direct fixes only for lint fix-protocol categories 3/4/6 (links, index
   lines) and qualifier rewrites where the condition is already stated in the page.
4. Anything non-mechanical goes in the findings file marked `→ issue`.

## Deliverables
- .claude/tmp/lint-sweep.sh (throwaway, not committed)
- plans/wiki-audit/findings/structure.md
- Direct fixes to wiki/**.md files where the fix protocol allows (list each in findings)

## Verify
- `sh .claude/tmp/lint-sweep.sh` exits 0 and its final summary matches the counts
  in findings/structure.md; re-run after fixes shows the fixed categories at 0.

## Out of scope
- Semantic routing quality (task 02); category sufficiency (task 03); any edit to
  AGENTS.md/templates/skills (schema layer — owner approval; file as issue).
