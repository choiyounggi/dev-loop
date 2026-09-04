# graphify-explore-role
Goal: dev-loop treats a locally built graphify code graph as an optional, freshness-gated `explore` role — a lead-not-evidence orientation layer for orchestrate Phase 2, wiki-plan A2, and loop-implement steps 1/6. Acceptance: `scripts/graph-freshness.sh` has the 0/2/3/4 contract with bats coverage; the three SKILL.md files and the brief template carry the gated, paired-evidence, CLI-only wording under doc-gates with negative controls; tool-profile docs show the graphify config; zero-config behavior is byte-for-byte unchanged when graphify is absent (full suite green, resolve-tools explore default intact); the grounding wiki page passes the structure and prohibition checkers.
Stack: bash 4+ (bats-core, jq, git — CI ubuntu + macos), graphifyy 0.4.23 CLI (optional at runtime, never required by tests), Node for the wiki checkers.
## Decisions
| # | Decision | Choice | Wiki basis |
|---|----------|--------|------------|
| D1 | Freshness signal | graph.json mtime vs `git log --since=@<epoch> --name-only --format=''`; distinct paths > 0 = stale; uncommitted edits not counted | wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md, wiki/infrastructure/agent-orchestration/control-signals-vs-primary-artifacts.md |
| D2 | Exit contract | stdout one token line: `fresh`/0, `stale <N>`/2, `absent`/3, `cannot-evaluate <usage\|no-cli\|bad-graph\|not-git>`/4; hint on stderr only for 2; the script never executes graphify (checks `command -v "${GRAPHIFY_BIN:-graphify}"` only) | wiki/testing/quality/checks-that-cannot-pass.md, wiki/platforms/processes/tool-diagnostics-without-a-failing-exit-code.md |
| D3 | Dialect/portability | `#!/usr/bin/env bash`, `set -euo pipefail`; mtime `date -r "$f" +%s 2>/dev/null \|\| stat -c %Y "$f" 2>/dev/null \|\| stat -f %m "$f"`; validity `jq -e '.nodes \| type == "array"'` | wiki/platforms/shells/portable-shell-scripts.md, wiki/platforms/tools/bsd-vs-gnu-cli.md |
| D4 | Update is a human choice | rc 2 → one AskUserQuestion chooser in Preflight (recommended: run `graphify update <root>`); never a full build; rc 3/4 → one Preflight line, nothing else | wiki/infrastructure/agent-orchestration/autonomous-decision-rulings.md, wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md |
| D5 | Lead, not evidence | graph citation only paired in one bullet: `graphify explain <Symbol> -> <N> connections; <search cmd> -> <n> hits`; plan-gate.sh unchanged | wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md, wiki/qa/process/completion-claims.md |
| D6 | Commands used | `explain "<Symbol>" --graph <path> \| head -40`; `path "<A>" "<B>" --graph <path>`; `query` only with `--budget 800` for orientation | wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md, wiki/infrastructure/agent-orchestration/session-context-token-budget.md |
| D7 | Worker graph path | brief explore row uses `--graph <main-root>/graphify-out/graph.json` (read-only main-checkout consumption; graph = integration base) | wiki/infrastructure/agent-orchestration/worktree-isolated-workers.md, wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md |
| D8 | CLI-only delivery | call `graphify` directly; never load the graphify SKILL.md; no MCP | wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md, wiki/infrastructure/agent-orchestration/session-context-token-budget.md |
| D9 | Activation points | Preflight rc 0 sets explore=graphify for the run; loop-implement step 1 explain/path before source; step 6 adds `graph-derived:` line to NOTES | wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md |
| D10 | Tool-profile docs | `### explore — graphify` subsection in references/tool-profile.md; example config entry; resolve-tools default `when` text mentions it; default kind stays `default` | [no-wiki] |
| D11 | Doc-gate tests | tests/orchestrate-graph-explore.bats, section-scoped, whitespace-normalized, each gate + negative control | wiki/testing/quality/checks-that-cannot-pass.md, wiki/testing/quality/tests-that-cannot-fail.md |
| D12 | Grounding page | wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md ingested in Phase B (page + index row + INDEX.md scope + log.md); a deliverable of this feature, already on disk | wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md |
## Size verdict
size: medium
5 tasks; every task touches ≤3 files and names ≤4 wiki pages; no task breaks a step-4 bound.
## Task order
| Task | Depends on | Parallel-ok |
|------|------------|-------------|
| 01-graph-freshness-script | — | with 02 |
| 02-resolve-tools-explore-text | — | with 01 |
| 03-orchestrate-preflight-and-phase2 | 01 | — |
| 04-wiki-plan-and-loop-implement-text | 01, 03 (appends to the bats file 03 creates) | — |
| 05-tool-profile-docs-and-full-verify | 01, 02, 03, 04 | — |
