# Task 04: wiki-plan A2 paired evidence and loop-implement step 1/6 graph leads
## Objective
`skills/wiki-plan/SKILL.md` A2 states the paired-evidence rule for graph citations; `skills/loop-implement/SKILL.md` step 1 runs explain/path before opening source when `explore` is graphify and step 6 names graph-derived assumptions; both spans are doc-gated in `tests/orchestrate-graph-explore.bats`.
## Wiki pages (read these first, only these)
- wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md — use for: directives 2, 3, 6 (paired evidence, symbol-anchored commands, `graph-derived:` in the report)
- wiki/qa/process/completion-claims.md — use for: the "claim → required evidence → not evidence" framing of the A2 rule
- wiki/infrastructure/agent-orchestration/session-context-token-budget.md — use for: directive 4 (bound tool output) behind `head -40` / `--budget 800`
- wiki/testing/quality/checks-that-cannot-pass.md — use for: negative controls
## Inputs
- tests/orchestrate-graph-explore.bats from task 03 (helpers `normalize_ws`, `section_body`; append to it)
- Decisions that bind you: D5, D6, D8, D9, D11
- Constraint: skills/wiki-plan/scripts/plan-gate.sh and tests/plan-gate.bats are not edited (R7)
## Steps
1. `skills/wiki-plan/SKILL.md`, Phase A, the A2 bullet that reads `` - `### Affected files` — every bullet needs an `evidence:` token backed by a real search (`<path> — evidence: <search command> -> <n> hits`). ``: append to that bullet: `` A code-graph hit (`explore` = graphify) may be cited only in the same bullet as that search, as a lead: `<path> — evidence: graphify explain <Symbol> -> <N> connections; <search command> -> <n> hits` — the graph chooses where to look, the search decides what is true (`wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md`). ``
2. `skills/loop-implement/SKILL.md`, loop step `1. Analyze + load refs`: after `Consult `knowledge`/`tacit`/`explore` if configured;` insert `when `explore` is graphify, run `graphify explain "<Symbol>" --graph <root>/graphify-out/graph.json | head -40` (and `graphify path "<A>" "<B>"` for a suspected edge) BEFORE opening source files — its hits are leads to confirm by search, never evidence;` keeping the code-block column alignment of the neighbouring lines.
3. Same file, step `6. Self-review + refactor`: append to that step's text `; when `explore` is graphify, list every assumption taken from the graph and not confirmed by a search as `graph-derived: <assumption>` (or `graph-derived: none`) on the task report's NOTES line`.
4. Same file, `## Tool profile (pluggable)` paragraph: after `` `explore` (code/symbol search) `` add ` — a fresh graphify graph is the recommended cli; call the binary directly and never load the graphify skill document (1,300+ lines), see `references/tool-profile.md``.
5. Append to `tests/orchestrate-graph-explore.bats` (add `WIKI_PLAN` and `LOOP` paths in `setup()`):
   - `doc-gate: wiki-plan A2 pairs a graph citation with a search in one bullet` — the A2 span (from `**A2. Ground truth**` to `**A3.`) contains `graphify explain <Symbol> -> <N> connections; <search command> -> <n> hits` and `lead`; negative control strips `graphify explain`
   - `doc-gate: loop-implement step 1 runs explain/path before opening source when explore is graphify` — the text between `1. Analyze` and `3. Write tests` contains `graphify explain`, `head -40`, `BEFORE opening source`; negative control
   - `doc-gate: loop-implement step 6 names graph-derived assumptions` — the text between `6. Self-review` and `6.5` contains `graph-derived:`; negative control
   - `doc-gate: loop-implement never loads the graphify skill document` — file contains `never load the graphify skill document` and does not contain `Skill(graphify`
   - `doc-gate: plan-gate.sh is untouched by the A2 wording` — `git -C "$REPO_ROOT" diff --quiet HEAD -- skills/wiki-plan/scripts/plan-gate.sh` exits 0 (skip with `skip` if not a git checkout)
## Deliverables
- skills/wiki-plan/SKILL.md (modified: one A2 bullet)
- skills/loop-implement/SKILL.md (modified: tool-profile paragraph, step 1, step 6)
- tests/orchestrate-graph-explore.bats (modified: cases appended)
## Verify
- `PATH=/opt/homebrew/bin:$PATH bats tests/orchestrate-graph-explore.bats tests/plan-gate.bats` → all `ok`
- covers: R7, R8
## Out of scope
- orchestrate SKILL.md / brief.md (task 03); tool-profile docs (05); plan-gate.sh (never).
