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
`OPEN:` token remains in this section. Start every Rule cell with its id
(`R1: ...`, `R2: ...`): design.md's Decision rows and Phase C `covers:` lines
cite these ids, and gate-B's requirements-covered fails a row without one.
| Rule | Concrete example | Open question |
|------|------------------|---------------|

## Ground truth
- Baseline: <test command> -> rc=<n>, HEAD <sha>, git status <clean|dirty>
- Lint: <lint or typecheck command> -> rc=<n>

The baseline-tests-ran gate re-runs the exact `<test command>` above; record
one command that can be copy-pasted and re-executed as-is.

Add one `- Lint:` bullet per lint or typecheck command the project runs, with
the rc you got running it now, or a single
`- Lint: none — checked: <command that confirmed it>` bullet. The
lint-surveyed gate fails without one; it checks the format only and never
re-runs the command.

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

### Reference study
Optional — keep only when the feature mirrors a behavior an existing product
(app, site, binary) already has and a fresh-context study agent observed it
through the `inspect` role (you copy its rows; you never call the tool). One
row per observed behavior; the Unknown cell names what the tooling could not
see, or `none`. The row carries the behavior in words; the Evidence cell
carries the tool name and the capture's evidence id or file name (REA
`ev_<sha>`, `search.har`) — the artifact itself lives outside the tracked tree
(`.claude/tmp/reference/<product-slug>/` once `git check-ignore -q .claude/tmp`
exits 0, else the session scratchpad) and only the study agent and the
reviewer open it. Pasting decompiled code, captured payloads, or assets here
is replaced by that reference. gate-A does not read this block; the task
review's fingerprint grep is the check. Each row that shapes the design
becomes an `R<n>` row above, with its oracle (input -> the original's output)
as the Concrete example; the product version and licence outcome go in
`## Constraints`.

| Observed behavior | Evidence (tool -> evidence id or capture name) | Unknown |
|-------------------|------------------------------------------------|---------|

## Research
External best-practice/pitfall search for this feature's domain (`research`
role). One row per query, or the literal line `no useful results — queries:
<queries>` if nothing useful turned up — the research-evidenced gate accepts
either. Prefer wiki pages already covering the decision; research targets
`[no-wiki]` territory and Spikes.
| Query | Source | Applied |
|-------|--------|---------|
