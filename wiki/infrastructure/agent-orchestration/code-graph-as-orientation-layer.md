---
id: infrastructure-agent-orchestration-code-graph-as-orientation-layer
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: field-tested
sources:
  - https://www.developersdigest.tech/blog/codegraph-local-indexes-ai-coding-agents
  - https://aq-score.com/blog/codegraph-local-code-knowledge-graph-agent-ops-guide-2026
  - https://getautonoma.com/blog/parallel-ai-agent-prs
  - https://www.tiarebalbi.com/en/blog/code-graphs-coding-agents-delivery-shape
  - https://github.com/Graphify-Labs/graphify
last_verified: 2026-09-04
related: [infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-session-context-token-budget, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, qa-process-completion-claims]
---

# A Pre-Built Code Knowledge Graph as the Orientation Layer for Planning Agents

## When this applies

A repository carries a locally built code knowledge graph (graphify's
`graphify-out/graph.json`, a CodeGraph index, or similar) and an agent is about
to plan, decompose, or estimate the blast radius of a change; an orchestrator is
splitting one goal into parallel tasks and needs each task's file set before
dispatch; deciding whether a graph result can stand as evidence in a plan.

## Do this

1. **Gate every use on freshness first, from the primary artifact.** A graph is
   the repository at one point in time; graphify's `graph.json` stores no commit
   sha or build timestamp, so compare the graph file's mtime against
   `git log --since=@<mtime-epoch> --name-only` — the git log is the primary
   artifact of "what changed". Treat a graph older than the newest code commit as
   stale, and treat an unreadable graph, a missing CLI, or a non-git root as
   "cannot evaluate": in all of those cases plan from the files, exactly as if no
   graph existed.

2. **Use the graph to choose where to look; use files, tests, and runtime to
   decide what is true.** A graph hit is a lead, never evidence. Every affected
   file a graph suggests is confirmed by a search or a read of that file before it
   enters a plan, a task's file set, or a conflict matrix, and the evidence line
   records both: `graphify explain <Symbol> -> <N> connections; grep -rn <Symbol>
   src -> <n> hits`.

3. **Ask symbol-anchored questions, never free-text ones, when planning.**

| Question | Command | Read the output as |
|----------|---------|--------------------|
| What touches this type / class / function? | `graphify explain "<Symbol>" --graph <path> \| head -40` | The candidate affected files and the shared surfaces between tasks |
| Does A reach B, and through what? | `graphify path "<A>" "<B>" --graph <path>` | A dependency edge to record between the tasks that own A and B |
| Orientation in an unfamiliar area | `graphify query "<question>" --budget 800 --graph <path>` | Community names to open next; measured on a 1,306-node graph a planning-sentence query returned unrelated nodes (`Error`, `String`) while `explain` on a named class returned 20 precise connections |

4. **Map each candidate task to its files through the graph before assigning
   parallel work**, then run tasks in parallel only when their confirmed file sets
   are disjoint. The graph makes a change's blast radius visible before dispatch;
   the disjointness test still runs on the confirmed sets, not the graph's guesses.

5. **Deliver the graph to the agent as a CLI, with bounded output.** A graph
   exposed as a ten-tool MCP server lands tens of thousands of tokens of tool
   definitions in context whether or not it is queried; a CLI costs only the lines
   it prints. Pipe `explain`/`path` through `head`, cap `query` with `--budget`,
   and call the binary directly rather than loading the vendor's skill document
   (graphify's is 1,300+ lines) into a coordinator session.

6. **Name graph-derived assumptions in the completion report.** Any file set,
   edge, or "nothing else calls this" claim that came from the graph and was not
   independently confirmed is listed as `graph-derived: <assumption>` so the
   reviewer can challenge it with a direct search.

7. **Measure before keeping it.** Track file reads and tool calls before the
   first edit, wrong-file edits, review comments about missed impact, and
   staleness incidents across runs with and without the graph. Keep the graph
   only when those improve; graphify's own benchmark reported an 11.4x average
   per-query token reduction on a 65k-word corpus, which is the upper bound, not
   the planning-time gain.

## Edge cases

| Case | Then |
|------|------|
| The graph is stale and rebuilding is cheap (graphify `update <root>` is AST-only, no LLM) | Offer the rebuild as an explicit choice to the human; it writes into the user's checkout outside the run's own state, so it is never run on the orchestrator's own initiative |
| Workers run in git worktrees | The graph output directory is usually gitignored, so no worktree carries it; pass `--graph <main-checkout>/graphify-out/graph.json` — a read of a main-checkout path is the sanctioned way to consume shared read-only input — and remember the graph reflects the integration base, not the worker's branch |
| The CLI exits 0 on a missing node, a missing graph file, or a JSON decode error | Validate the graph file yourself (`jq -e '.nodes'`) and detect "no node matching" from stdout; the exit code carries no signal |
| Routes, handlers, or imports are generated by framework convention, decorators, or dynamic imports | The graph under-reports edges there; widen the search with grep on the convention (route table, decorator name) before trusting a "no callers" result |
| The graph and a file disagree | The file wins; record the disagreement as a staleness incident and drop the graph for the rest of the task |
| Uncommitted edits exist in the checkout | The mtime-vs-log check does not count them; a graph is "fresh" relative to commits only — re-run the check after the edits land if the plan depends on them |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Cite `graphify explain X -> 12 connections` as the sole evidence for an affected file | Pair it with the grep or read that confirmed the file | The graph is a lead; a stale or convention-blind edge would enter the plan as fact |
| Run the graph tool's full build inside an orchestration run | Report `stale` and let the human choose the AST-only update | A full build may call an LLM on docs, spends the user's budget, and writes outside the run's state |
| Load the vendor's skill document to learn the CLI | Call `graphify --help` (40 lines) and the three commands above | The skill document is 1,300+ lines of pipeline instructions the coordinator never executes |

## Sources

- https://www.developersdigest.tech/blog/codegraph-local-indexes-ai-coding-agents — "Use the graph to choose where to look. Use the file, test, and runtime to decide what is true"; the measurement list in directive 7 and the decorator/convention limit
- https://aq-score.com/blog/codegraph-local-code-knowledge-graph-agent-ops-guide-2026 — "If the graph is stale, incomplete, or conflicts with the files, stop using it and investigate from the files"; rebuild from the active checkout; results are leads, not evidence
- https://getautonoma.com/blog/parallel-ai-agent-prs — map each task to the files it will touch via the dependency graph before assigning; parallelize only disjoint file sets
- https://www.tiarebalbi.com/en/blog/code-graphs-coding-agents-delivery-shape — a graph MCP exposing ten tools costs tens of thousands of context tokens whether queried or not
- https://github.com/Graphify-Labs/graphify — `explain`/`path`/`query --budget`, `update` (AST-only, no LLM), `hook install` post-commit/post-checkout; exit-0-on-error, empty `graph` metadata, and the query-vs-explain quality gap measured on graphifyy 0.4.23 with a 1,306-node graph, 2026-09-04
