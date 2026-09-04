# Analysis — graphify-explore-role

<!--
Parsed by skills/wiki-plan/scripts/plan-gate.sh (gate-A). Keep section
headers exactly as shown.
-->

## Requirements
Example-Mapping table: one row per rule, with a concrete Given/When/Then
example.
| Rule | Concrete example | Open question |
|------|------------------|---------------|
| R1 `scripts/graph-freshness.sh <root> [--graph <path>]` has a fixed exit contract: 0 fresh, 2 stale, 3 absent, 4 cannot-evaluate (graphify CLI missing, graph.json unreadable, root not a git repo). It never builds or updates a graph. | Given a repo with `graphify-out/graph.json` and no commits after its mtime, When run, Then rc=0 and stdout `fresh`. Given a repo with no `graphify-out/graph.json`, Then rc=3 and stdout `absent`. | |
| R2 Stale = at least one file changed in a commit after graph.json's mtime, counted via `git log --since=@<epoch> --name-only --format=''`; stdout prints `stale <N>` and stderr one hint line naming `graphify update .` (AST-only). | Given graph.json then one later commit touching 2 files, Then rc=2, stdout `stale 2`, stderr contains `graphify update`. | |
| R3 graph.json validity is checked by `jq -e '.nodes'` in the script itself, because `graphify explain/path` return rc 0 on a missing node AND on a JSON decode error (spike S1). | Given `graphify-out/graph.json` containing `{bad`, Then rc=4 and stderr names the file. | |
| R4 orchestrate Preflight runs the freshness check once per run. rc 0 → `explore` resolves to graphify for this run; rc 2 → one chooser (update now / continue without the graph), the update is `graphify update <root>` and only on an explicit yes; rc 3/4 → silent skip, behavior identical to today. | Given rc 2 and the user picks "continue without", Then no `graphify` command runs and Phase 2 uses grep only. | |
| R5 orchestrate Phase 2, when the graph is fresh: for each candidate task, run `graphify explain "<Symbol>" --graph <root>/graphify-out/graph.json \| head -40` on the task's named symbols; the printed connections seed the task's affected files and shared surfaces, recorded as `graphify explain <Symbol> -> <N> connections`. A graph hit is a lead: every affected file still gets a grep/file confirmation before it enters `graph.json`'s `files`. | Given `graphify explain ChatGateway` lists 20 connections in 3 files, Then those 3 files are grep-confirmed and the evidence line reads `graphify explain ChatGateway -> 20 connections; grep -rn ChatGateway src -> 7 hits`. | |
| R6 Brief `<tools_guidance>` explore row carries the concrete command with `--graph <main-root>/graphify-out/graph.json` because worker worktrees carry no `graphify-out` (gitignored, spike S3) and the graph reflects the integration base, not the worker branch. | Given a dispatched brief, Then its Tools section contains `explore: graphify explain "<Symbol>" --graph <main-root>/graphify-out/graph.json` and the sentence that the graph is a lead, not evidence. | |
| R7 wiki-plan A2: an `Affected files` bullet may cite graphify output only in the same bullet as a grep/file-backed `evidence:` token; `plan-gate.sh` and its fixtures are unchanged. | Given a bullet `- src/x.ts — evidence: graphify explain X -> 4 connections; grep -rn X src -> 3 hits`, Then gate-A `affected-files-evidenced` passes with today's parser (it looks for the `evidence:` token). | |
| R8 loop-implement step 1 and step 6: when `explore` resolves to graphify, run `explain`/`path` before opening source files, and the step-6 self-review names every graph-derived assumption; the graphify SKILL.md is never loaded (CLI only); `--budget` only on `query` (spike S4). | Given explore=graphify, Then the task report NOTES line lists `graph-derived: <assumption>` entries or `graph-derived: none`. | |
| R9 `references/tool-profile.md`, `scripts/resolve-tools.sh` (explore `when` text), and `examples/tools.example.json` document `explore: {kind: "cli", ref: "graphify", how: ...}`; with no config, explore still resolves to `default` (tests/resolve-tools.bats:20 unchanged). | Given no config, When `resolve-tools.sh --json`, Then `.explore.kind == "default"`. | |
| R10 New page `wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md` with a row in `wiki/infrastructure/index.md`, passes `node scripts/wiki-structure-checks.js wiki` with findings: 0, and cites the four research sources. | Given the page, When the checker runs, Then stdout ends `findings: 0`. | |
| R11 `tests/graph-freshness.bats` covers fresh, stale, absent, unreadable graph, no-git root, missing CLI, and the boundary "graph newer than HEAD with dirty worktree" (still fresh — uncommitted edits are not counted). | Given the suite, Then ≥7 cases, each with ≥1 assertion, ≥1 error case, ≥1 boundary case. | |
| R12 Zero-config invariant: with graphify absent, no changed SKILL.md text mandates an action, and the full bats suite result is unchanged from baseline. | Given `PATH` without graphify, When the suite runs, Then the same pass/fail set as baseline. | |

## Ground truth
- Baseline: PATH=/opt/homebrew/bin:$PATH bats tests/ -> rc=0, HEAD 484dd9d, git status clean

### Affected files
- scripts/graph-freshness.sh (new) — evidence: `ls scripts/graph-freshness.sh` -> 0 hits (does not exist)
- tests/graph-freshness.bats (new) — evidence: `ls tests/graph-freshness.bats` -> 0 hits (does not exist)
- wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md (new) — evidence: `grep -rli "code graph\|knowledge graph\|graphify" wiki/` -> 2 hits, both in databases/ (DB selection pages), none in agent-orchestration
- wiki/infrastructure/index.md — evidence: `grep -c agent-orchestration wiki/infrastructure/index.md` -> 11 hits (the section the new row joins)
- INDEX.md — evidence: `grep -c "multi-agent orchestration" INDEX.md` -> 1 hit (line 17 scope text gains "code-graph orientation")
- skills/orchestrate/SKILL.md — evidence: `grep -c explore skills/orchestrate/SKILL.md` -> 1 hit (line 71, tools_guidance); `grep -n "^## Preflight\|^## Phase 2" ` -> 2 hits (lines 155, 266)
- skills/orchestrate/templates/brief.md — evidence: `grep -c explore skills/orchestrate/templates/brief.md` -> 1 hit (tools_guidance comment)
- skills/wiki-plan/SKILL.md — evidence: `grep -c "evidence:" skills/wiki-plan/SKILL.md` -> 2 hits (A2 affected-files rule)
- skills/loop-implement/SKILL.md — evidence: `grep -c explore skills/loop-implement/SKILL.md` -> 3 hits (tool profile, step 1, sweep)
- references/tool-profile.md — evidence: `grep -c explore references/tool-profile.md` -> 1 hit (roles table row)
- scripts/resolve-tools.sh — evidence: `grep -c explore scripts/resolve-tools.sh` -> 2 hits (comment + default `when`)
- examples/tools.example.json — evidence: `grep -c explore examples/tools.example.json` -> 1 hit

Not touched, on purpose: `templates/brief.md` at the repo root (legacy copy; `grep -rn "templates/brief.md"` outside plans/docs -> only skills/orchestrate/SKILL.md, which resolves to the skill's own templates dir), `templates/session-prompt.md` (cksum-pinned), `skills/wiki-plan/scripts/plan-gate.sh` (R7 keeps the parser).

## Constraints
- tests/resolve-tools.bats:20 pins `.explore.kind == "default"` with no config — checked: `grep -n explore tests/resolve-tools.bats` -> 1 hit; the default stays `default`, only its `when` text changes.
- tests/send-prompt.bats:739 cksum-pins `templates/session-prompt.md` from `## Subagent usage protocol` on — checked: `grep -n cksum tests/send-prompt.bats` -> 3 hits; this feature does not edit session-prompt.md.
- tests/scripts.bats:163-170 pins brief.md literals `split proposal`, `files it would touch`, `split_of`, and zero Hangul bytes; tests/scripts.bats:186 pins zero Hangul bytes in skills/orchestrate/SKILL.md — checked: `grep -n hangul_bytes tests/scripts.bats` -> 4 hits; all new text is English.
- tests/session-prompt-paths.bats:136 forbids any bare `.orchestration/` path in brief.md other than `.orchestration/status` — checked: `sed -n 130,139p tests/session-prompt-paths.bats`; the new explore row uses `<main-root>/graphify-out/graph.json`, never `.orchestration/`.
- scripts/wiki-structure-checks.js (run by tests/wiki-structure-checks.bats:19 on the live wiki) requires frontmatter keys id/domain/category/applies_to/confidence/sources/last_verified/related, id == `infrastructure-agent-orchestration-code-graph-as-orientation-layer`, an index row, and `related` ids that exist — checked: `sed -n 17,45p scripts/wiki-structure-checks.js`.
- CI runs on ubuntu and macos (.github/workflows/test.yml) — checked: `grep -n "brew install\|apt-get" .github/workflows/test.yml` -> 2 hits; the script uses `date -r <file> +%s` (works on both, spike S2) and no `stat -f`/`stat -c`.
- User hook `exit-code-masking-guard` blocks piping a decision-carrying script — checked: memory note; bats cases use `run sh "$SCRIPT"` and read `$status`, never a pipe.

## Spikes
- S1 graphify exit codes (graphifyy 0.4.23): `graphify explain "NoSuchNodeXYZ" --graph g.json` -> rc 0; `graphify path A NoSuch` -> rc 0 with "No node matching"; `graphify explain X --graph bad.json` -> Python JSONDecodeError traceback, rc 0. Consequence: the freshness script must validate graph.json with jq itself and must not rely on graphify's rc for anything (R3).
- S2 mtime portability: `date -r graph.json +%s` -> 1788137456 on macOS 25.1; GNU coreutils `date -r FILE` is the same flag. `git log --since=@1788137456 --name-only --format='' | sort -u | wc -l` -> 97 on linkly-calendar (stale). graph.json's top-level `graph` dict is empty and GRAPH_REPORT.md carries only a date, so mtime is the only freshness signal available.
- S3 graphify-out is gitignored in linkly-calendar (`git check-ignore -q graphify-out` -> ignored), so a git worktree never carries it; workers must point `--graph` at the main checkout (R6).
- S4 `graphify explain X --budget 100` printed the full 20-connection list — `--budget` is a `query` option only; explain/path output is bounded with `| head -N` instead (R5/R8).
- S5 Query quality on linkly-calendar (1306 nodes): a free-text `graphify query "<planning sentence>" --budget 600` returned noise (Error, String, .encode()); `explain ChatGateway` returned 20 precise connections; `path ChatGateway processFanoutMessage` returned a 3-hop path; `graphify benchmark` -> 11.4x average token reduction (6.3x–22.2x). Consequence: skills prescribe symbol-anchored explain/path, never free-text query, for planning.

## Research
`research` role resolved to default; answered by `mcp__brave-search__brave_web_search` (2 of 6 queries rate-limited, retried) plus WebFetch on three articles.
| Query | Source | Applied |
|-------|--------|---------|
| local code graph coding agent context layer orientation impact analysis when to use vs grep | https://www.developersdigest.tech/blog/codegraph-local-indexes-ai-coding-agents — "Use the graph to choose where to look. Use the file, test, and runtime to decide what is true"; measure tool calls/file reads before first edit, wrong-file edits, staleness incidents; "If those improve, keep the graph. If they do not, remove it." | R5/R7 lead-not-evidence rule; wiki page "Do this" + measurement rows |
| keeping code knowledge graph fresh incremental update git hook stale graph detection coding agent | https://aq-score.com/blog/codegraph-local-code-knowledge-graph-agent-ops-guide-2026 — "If the graph is stale, incomplete, or conflicts with the files, stop using it and investigate from the files"; rebuild from the active checkout | R1/R2/R4 freshness gate before any use; never auto-build |
| AI coding agent orchestrator use dependency graph to split work into parallel tasks avoid file conflicts | https://getautonoma.com/blog/parallel-ai-agent-prs — "Use a dependency graph to map each task to the files it will likely touch before assigning tasks to agents. Only run tasks in parallel if their expected file sets are disjoint" | R5 Phase 2 explain-derived affected files feed the existing conflict matrix |
| graphify knowledge graph codebase Claude Code skill agent workflow best practices | https://www.tiarebalbi.com/en/blog/code-graphs-coding-agents-delivery-shape — a remote/local MCP exposing ten graph tools "lands tens of thousands of tokens in context whether you query it or not"; https://github.com/Graphify-Labs/graphify — `query`/`path`/`explain`, `graphify update` AST-only, `hook install` post-commit/post-checkout | R8 CLI-only, never load the 1319-line graphify SKILL.md; wiki page "Instead of" row |
| GraphRAG codebase agent code graph multi-agent task decomposition impact analysis blast radius | https://eliteai.tools/agent-skills/code-graph — PLAN → LOCATE → UNDERSTAND → BLAST → TRACE → CHANGE → VERIFY; graph refreshed by watcher + session-start + post-commit hook | R8 explain/path before reading source; wiki page edge case on refresh layers |
