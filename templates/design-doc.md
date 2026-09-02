<!-- contract: t1-plan-gate owns the implementation -->
# Design — <feature>

<!--
Parsed by skills/wiki-plan/scripts/plan-gate.sh (gate-B). Keep section
headers exactly as shown. A heading entirely absent is "target missing"
(exit 4); a heading present but not satisfying its rule below is a content
defect (exit 3).
-->

## Decisions
One data row per decision. All six cells must be non-empty — the
decision-rows-complete gate fails a row with any blank cell. `Wiki basis` is
either a repo-relative path `wiki/<domain>/<category>/<page>.md` to a page
that actually exists, or the literal `[no-wiki]`; the groundings-exist gate
greps the wiki root for every non-`[no-wiki]` path and fails on any miss.
`Testability` names the test/gate that would catch this decision being wrong.
| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |
|---|----------|--------|------------|----------------------|-------------|

## Review
Record the plan-reviewer subagent's fixed-format verdict here, and also copy
the `VERDICT: PASS` line alone into `<plan-dir>/review-verdict.md` — the
reviewer-verdict gate reads that file, not this section.
