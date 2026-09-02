<!-- contract: t1-plan-gate owns the implementation -->
# Analysis — <feature>

<!--
Parsed by skills/wiki-plan/scripts/plan-gate.sh (gate-A). Keep section
headers exactly as shown — the parser locates each section by its heading
text, not by position. A heading that is entirely absent is treated as
"target missing" (exit 4); a heading present but not satisfying its rule
below is a content defect (exit 3).
-->

## Requirements
Example-Mapping table: one row per rule, with a concrete Given/When/Then
example. Leave "Open question" blank once resolved; while unresolved, mark
it `OPEN: <question>` — the open-questions-resolved gate fails while any
`OPEN:` token remains in this section.
| Rule | Concrete example | Open question |
|------|------------------|---------------|

## Ground truth
- Baseline: <test command> -> rc=<n>, HEAD <sha>, git status <clean|dirty>

The baseline-tests-ran gate re-runs the exact `<test command>` above; record
one command that can be copy-pasted and re-executed as-is.

### Affected files
Every bullet MUST include an `evidence:` token backed by a real search — the
affected-files-evidenced gate fails a bullet with none.
- <path> — evidence: <search command> -> <n> hits

## Constraints
List every pinned file, protected span, and CI requirement this feature
touches, each with the command used to check it. If none apply, say so
explicitly — an empty section fails the constraints-surveyed gate.
- <pinned file / protected span / CI requirement> — checked: <command>
<!-- or, if nothing applies: - none — checked: <command that confirmed it> -->

## Spikes
Timeboxed investigation of load-bearing unknowns (XP spike). Record what was
discovered; a remaining unknown that blocks Phase B must be escalated to the
requester, not left as a placeholder.

## Research
External best-practice/pitfall search for this feature's domain (`research`
role). One row per query, or the literal line `no useful results — queries:
<queries>` if nothing useful turned up — the research-evidenced gate accepts
either. Prefer wiki pages already covering the decision; research targets
`[no-wiki]` territory and Spikes.
| Query | Source | Applied |
|-------|--------|---------|
