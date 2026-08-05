# Task 06: File GitHub issues + final audit report

## Objective
Every `→ issue` finding from tasks 01/02/03/05 exists as a GitHub issue on
choiyounggi/dev-loop titled `wiki-audit: <theme>`, and
`plans/wiki-audit/findings/REPORT.md` summarizes the whole audit: per-axis
verdict, fixes applied on this branch, issues filed (with numbers), and the
overall production-readiness judgment the user asked for.

## Wiki pages (read these first, only these)
- (none — reporting task)

## Inputs
- plans/wiki-audit/findings/structure.md, routing.md, categories.md, pipeline.md
- Decisions that bind you: D4, D8 (one issue per coherent theme; body = finding +
  evidence + proposed fix)

## Steps
1. Group `→ issue` findings into themes; draft each issue body; create via
   `gh issue create --repo choiyounggi/dev-loop --title "wiki-audit: <theme>" --body-file <tmpfile in .claude/tmp>`.
2. Write REPORT.md: axis-by-axis verdict (구조/내용/카테고리/harvest/flush), what
   was fixed (files), what was filed (issue #s), what is genuinely fine as-is.

## Deliverables
- plans/wiki-audit/findings/REPORT.md
- GitHub issues (numbers recorded in REPORT.md)

## Verify
- `gh issue list --repo choiyounggi/dev-loop --search "wiki-audit in:title" --json number,title`
  lists every theme named in REPORT.md.

## Out of scope
- Merging/committing beyond this branch's scope decisions; opening PRs (the user
  reviews the branch).
