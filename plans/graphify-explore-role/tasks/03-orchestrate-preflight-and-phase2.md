# Task 03: orchestrate Preflight freshness gate, Phase 2 graph leads, brief explore row
## Objective
`skills/orchestrate/SKILL.md` runs `graph-freshness.sh` in Preflight with the consent-gated update chooser, uses `graphify explain`/`path` as leads in Phase 2 with the paired-evidence form, writes the explore row into `<tools_guidance>`; `skills/orchestrate/templates/brief.md` shows that row; `tests/orchestrate-graph-explore.bats` gates every span with a negative control.
## Wiki pages (read these first, only these)
- wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md — use for: directives 1–5 and the worktree edge case; the exact command forms
- wiki/infrastructure/agent-orchestration/autonomous-decision-rulings.md — use for: directive 1(c) — the update writes outside the run's state, so it is the human's choice
- wiki/infrastructure/agent-orchestration/worktree-isolated-workers.md — use for: directive 3 — reading a main-checkout path is allowed; the brief carries one absolute path
- wiki/testing/quality/checks-that-cannot-pass.md — use for: each doc-gate paired with a fixture that strips the span and fails
## Inputs
- scripts/graph-freshness.sh from task 01 (exit contract 0/2/3/4, stdout token)
- Decisions that bind you: D4, D5, D6, D7, D8, D9, D11
- Style reference: tests/orchestrate-token-budget.bats (`normalize_ws`, `section_body` via awk on a `## ` heading, negative-control fixtures in `BATS_TEST_TMPDIR`)
- Constraints: skills/orchestrate/SKILL.md and brief.md must stay Hangul-free (tests/scripts.bats:170,186); brief.md must not gain a bare `.orchestration/` path (tests/session-prompt-paths.bats:136)
## Steps
1. `skills/orchestrate/SKILL.md`, section `## Preflight`: after the paragraph that ends `Never auto-install without consent.` and before `**Coordinator permissions (tmux substrate).**`, insert this paragraph (wrap at ~80 columns like the file):
   ```
   **Code-graph freshness (optional `explore` lead).** Run
   `sh ${CLAUDE_PLUGIN_ROOT}/scripts/graph-freshness.sh <root>` once, bare
   (read its exit code on the next line, never in a pipe). It never runs
   graphify itself. Branch on the code: **0** (`fresh`) — set `explore` to
   graphify for this run and write the row from Phase 3 step 2 into every
   brief; **2** (`stale <N>`) — ask ONE chooser (§ Asking the user):
   "graphify graph is stale (<N> files changed since it was built) — run
   `graphify update <root>` now (AST-only, seconds, no LLM), or continue
   without the graph?" with *update* as the recommended answer; run the
   update only on an explicit yes and re-run the freshness check afterwards;
   **3**/**4** (`absent` / `cannot-evaluate <reason>`) — print one line saying
   the graph is not in use and continue exactly as before. The coordinator
   never runs a full `/graphify` build and never loads the graphify skill
   document: the CLI is the whole interface (`graphify --help`). Basis:
   `wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md`.
   ```
2. Same file, section `## Phase 2 — Decompose`: after the sentence `A markdown table is not machine readable.` and before the ```json block, insert:
   ```
   **Graph leads (only when Preflight set `explore` to graphify).** For each
   candidate task, run `graphify explain "<Symbol>" --graph
   <root>/graphify-out/graph.json | head -40` on the symbols the task names,
   and `graphify path "<A>" "<B>" --graph <root>/graphify-out/graph.json` for
   a suspected edge between two tasks. The printed connections seed the task's
   affected files and its shared surfaces; the disjointness test in the
   conflict matrix runs on the confirmed sets, never on the graph's guesses.
   A graph hit is a lead, not evidence: every file it suggests is confirmed
   by a search before it enters `files`, and the record pairs both in one
   line — `graphify explain <Symbol> -> <N> connections; grep -rn <Symbol>
   src -> <n> hits`. Ask symbol-anchored questions only; a free-text
   `graphify query` is for orientation (`--budget 800`) and never derives a
   file set. Any assumption taken from the graph and not confirmed is
   recorded on the blackboard as `graph-derived: <assumption>`.
   ```
3. Same file, `## Tool profile` section: replace `` `explore` (code search) `` with `` `explore` (code search; a fresh graphify graph when Preflight says so) ``.
4. Same file, Phase 3 step **2** bullet (`- **2** Per task: write `briefs/<task>.md` ...`): append the sentence `When `explore` is graphify, the `<tools_guidance>` row is: `explore: graphify — graphify explain "<Symbol>" --graph <main-root>/graphify-out/graph.json | head -40 (lead, not evidence; the graph reflects the integration base, and a worktree carries no graphify-out)` with `<main-root>` the absolute main-checkout path.`
5. `skills/orchestrate/templates/brief.md` line with `<tools_guidance>{e.g. docs/specs to read, how to explore; ...}</tools_guidance>`: change the placeholder text to `{e.g. docs/specs to read, how to explore; DB read-only if any; resolved roles — knowledge/tacit/explore; when explore=graphify: "explore: graphify — graphify explain \"<Symbol>\" --graph <main-root>/graphify-out/graph.json | head -40 (lead, not evidence; graph reflects the integration base)"}`. Keep the file free of any bare `.orchestration/` path and of Hangul.
6. Create `tests/orchestrate-graph-explore.bats` with `setup()` (REPO_ROOT, SKILL, BRIEF, `SCRIPT="${REPO_ROOT}/scripts/graph-freshness.sh"`), `normalize_ws`, and `section_body <heading>` helpers copied from tests/orchestrate-token-budget.bats, and these cases, each `doc-gate:` paired with a `doc-gate can fail:` fixture that `grep -v`s the asserted phrase:
   - Preflight section body contains `graph-freshness.sh`, `AskUserQuestion` or `§ Asking the user`, `graphify update <root>`, `never runs a full`, `never loads the graphify skill`, and the wiki slug `wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md`
   - Phase 2 section body contains `head -40`, `-> <N> connections;`, `lead, not evidence`, `--budget 800`, `graph-derived:`
   - Phase 2 body does NOT contain `explain` followed by `--budget` on one normalized line (`! grep -qE 'explain[^|]*--budget'`)
   - the whole SKILL.md does NOT contain `Skill(graphify` nor `/graphify query`
   - Phase 3 step 2 text contains `<main-root>/graphify-out/graph.json`
   - brief.md contains `explore: graphify` and `<main-root>/graphify-out/graph.json`; negative control: a fixture without it
   - `scripts/graph-freshness.sh` referenced by Preflight exists and is executable (`[ -x "$SCRIPT" ]`)
## Deliverables
- skills/orchestrate/SKILL.md (modified: Preflight, Tool profile, Phase 2, Phase 3 step 2)
- skills/orchestrate/templates/brief.md (modified: tools_guidance placeholder)
- tests/orchestrate-graph-explore.bats (new)
## Verify
- `PATH=/opt/homebrew/bin:$PATH bats tests/orchestrate-graph-explore.bats tests/scripts.bats tests/session-prompt-paths.bats tests/orchestrate-token-budget.bats tests/orchestrate-ask-gate.bats` → all `ok`
- covers: R4, R5, R6
## Out of scope
- wiki-plan and loop-implement SKILL.md text (task 04); tool-profile docs (05); templates/session-prompt.md (cksum-pinned, untouched).
