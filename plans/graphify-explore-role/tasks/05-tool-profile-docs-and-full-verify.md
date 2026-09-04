# Task 05: tool-profile docs for the graphify explore config, then the full-suite and wiki verification
## Objective
`references/tool-profile.md` documents `explore` = graphify with the freshness gate and the paired-evidence rule; `examples/tools.example.json` shows the entry; the full bats suite, the wiki structure checker, and the prohibition checker are green with graphify absent from PATH.
## Wiki pages (read these first, only these)
- wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md — use for: the subsection's wording (directives 1, 2, 5, 7)
- wiki/qa/process/completion-claims.md — use for: the final report claims exactly what the fresh runs show
## Inputs
- Deliverables of tasks 01–04 (script, SKILL texts, bats files) on disk
- Decisions that bind you: D8, D10, D12
- Constraint: examples/tools.example.json currently has an `explore` entry (`rtb-sourcecode`); replace it
## Steps
1. `references/tool-profile.md`: in the `## Roles` table, change the `explore` row's Purpose cell to `locating code, symbols, call sites (read-only); optionally a fresh graphify code graph as a lead` and its Used-by cell to `loop-implement step 1 (Analyze) + step 6; orchestrate Preflight (freshness) + Phase 2 (leads)`.
2. Same file, before `### `research` — external best-practice/pitfall search`, add:
   ```
   ### `explore` — a graphify code graph as the orientation layer (optional)

   With graphify installed (`pipx install graphifyy`) and a graph built once
   (`/graphify <root>` in any assistant, or `graphify update <root>` for the
   AST-only refresh), configure:

   ```json
   {
     "explore": {
       "kind": "cli",
       "ref": "graphify",
       "how": "graphify explain \"<Symbol>\" --graph <root>/graphify-out/graph.json | head -40; graphify path \"<A>\" \"<B>\" --graph <root>/graphify-out/graph.json",
       "when": "step 1 before opening source, and orchestrate Phase 2 — only after scripts/graph-freshness.sh printed fresh"
     }
   }
   ```

   Rules the skills apply (basis:
   `wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md`):
   - **Freshness first.** `sh ${CLAUDE_PLUGIN_ROOT}/scripts/graph-freshness.sh <root>`
     exits 0 `fresh`, 2 `stale <N>`, 3 `absent`, 4 `cannot-evaluate <reason>`;
     the graph is used only on 0. On 2 the human chooses whether to run
     `graphify update <root>`; the plugin never runs a build itself.
   - **Lead, not evidence.** A graph hit enters a plan only paired with a
     search: `graphify explain <Symbol> -> <N> connections; grep -rn <Symbol>
     src -> <n> hits`. Unconfirmed assumptions are reported as `graph-derived:`.
   - **CLI only, bounded output.** `explain`/`path` through `head -40`, `query`
     with `--budget 800`; the graphify skill document is never loaded.
   - **Worktrees.** Workers point `--graph` at the main checkout's
     `graphify-out/graph.json` (gitignored, so no worktree carries it); the
     graph reflects the integration base.
   Unset, `explore` resolves to `default` and nothing above runs.
   ```
3. `examples/tools.example.json`: replace the `explore` object with `{"kind": "cli", "ref": "graphify", "how": "graphify explain \"<Symbol>\" --graph <root>/graphify-out/graph.json | head -40; graphify path \"<A>\" \"<B>\" --graph <root>/graphify-out/graph.json", "when": "step 1 before opening source, and orchestrate Phase 2 leads — only after scripts/graph-freshness.sh printed fresh; a hit is a lead to confirm by search"}` and validate with `jq -e . examples/tools.example.json`.
4. Run the three verifications below with graphify absent: prefix the suite with `GRAPHIFY_BIN=graphify-absent-xyz` (the suite's own tests set their own `GRAPHIFY_BIN`, so this only proves nothing else depends on the CLI) and a `PATH` that excludes `~/.local/bin`.
## Deliverables
- references/tool-profile.md (modified)
- examples/tools.example.json (modified)
## Verify
- `jq -e '.explore.ref == "graphify"' examples/tools.example.json` → `true`
- `PATH=/opt/homebrew/bin:/usr/bin:/bin bats tests/` → rc 0, `not ok` count 0, `ok` count ≥ 1007 + the new cases
- `node scripts/wiki-structure-checks.js wiki` → `findings: 0`; `node scripts/wiki-lint-prohibitions.js wiki` → `violations: 0`
- covers: R9 (docs half), R10, R12
## Out of scope
- Any SKILL.md or script edit — if a verification fails here, the fix belongs to the task that owns that file (01–04), re-run through loop-implement 7b.
