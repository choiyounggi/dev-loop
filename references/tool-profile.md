# Tool profile — pluggable capability roles

loop-orchestrator is environment-neutral by default: it depends on no specific
MCP server, skill, or agent (only the bundled `test-quality-auditor`). The **tool
profile** lets each installation plug its own tools into a few named *capability
roles*. If you configure a role, the skills use your tool; if you don't, they use
the generic built-in behavior. Nothing breaks when nothing is configured.

## Roles

| Role        | Purpose                                          | Used by (step)                          |
| ----------- | ------------------------------------------------ | --------------------------------------- |
| `intake`    | work-list source — an issue tracker the parent/child issues come from | orchestrate Phase 0 (Intake) |
| `knowledge` | domain facts, business policy, code/status values | loop-implement step 1 (Analyze); orchestrate Phase 0/2 |
| `tacit`     | past incidents, edge cases, coupling/danger zones | loop-implement step 1 (Analyze) + step 6 (Self-review) |
| `verify`    | running the project's tests / build / QA checks   | loop-implement step 5 (Run); orchestrate Phase 5 (integration) |
| `explore`   | locating code, symbols, call sites (read-only); optionally a fresh graphify code graph as a lead | loop-implement step 1 (Analyze) + step 6; orchestrate Preflight (freshness) + Phase 2 (leads) |
| `design`    | visual/UI spec for FE/UI tasks (e.g. a Figma link in the issue) | orchestrate Phase 0/2 + brief; loop-implement step 1 (Analyze) |
| `research`  | external best-practice/pitfall search for a feature's domain, and evidence for `[no-wiki]` decisions | wiki-plan Phase A4 (external research), Phase A3 (spike research), Phase B (`[no-wiki]` grounding) |

Roles are optional and extensible — you may add custom keys; the resolver passes
them through, and a skill uses a role only if it knows that role by name.

### `design` — the visual-spec source (optional)

When `design` is configured and a task is UI-facing — the issue references a
design (e.g. a Figma link) and the change touches the UI — orchestrate pulls the
referenced spec while building the task brief and writes it into the brief's
`<design_spec>` tag, so the worker session implements against the real visual
contract instead of guessing. `loop-implement` consults the same role in step 1
(Analyze / spec-conformance) when run standalone. With `design` unset, neither
skill looks for a visual spec — the original behavior. Backend-only or non-UI
tasks skip it even when configured. Example mapping to a Figma MCP:

```json
{ "design": { "kind": "mcp", "ref": "rtb-figma",
              "how": "get_spec_links -> inspect_node / get_dev_ready / get_design_tokens",
              "when": "issue has a Figma link AND the change touches UI; skip for backend-only tasks" } }
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
- **Lead, not evidence.** A graph hit enters a plan only paired with a search:
  `graphify explain <Symbol> -> <N> connections; grep -rn <Symbol> src -> <n>
  hits`. Unconfirmed assumptions are reported as `graph-derived:`.
- **CLI only, bounded output.** `explain`/`path` through `head -40`, `query`
  with `--budget 800`; the graphify skill document is never loaded.
- **Worktrees.** Workers point `--graph` at the main checkout's
  `graphify-out/graph.json` (gitignored, so no worktree carries it); the graph
  reflects the integration base.

Unset, `explore` resolves to `default` and nothing above runs.

### `research` — external best-practice/pitfall search (optional, fixed interpretation order)

`research` backs `wiki-plan`'s Phase A4 (external research: best practices and
known pitfalls for the feature's domain, at least one search recorded in
`## Research`), Phase A3 spike research, and grounding a Phase B `[no-wiki]`
decision. Unlike the other roles, its **interpretation order is fixed** — a
shell script cannot detect whether an MCP tool exists in the calling
environment, so `resolve-tools.sh` only tells you "configured" vs "default";
the fallback chain when it resolves to `default` is owned by the
`loop-implement` SKILL text, in this order:

1. The tool configured for `research` in the tool profile, if any.
2. `mcp__brave-search__brave_web_search`, if it exists in the environment.
3. The built-in WebSearch.
4. If none of the above are available: ABANDON the `research-evidenced` gate
   (open abandonment, not a silent skip).

Whichever tool actually answered the query is recorded in `## Research`
alongside the query and source. Example mapping (explicit override — with
`research` unset it still resolves to `default` and step 2–3 of the chain
above apply):

```json
{ "research": { "kind": "mcp", "ref": "brave-search",
                "how": "brave_web_search(query, count, freshness)",
                "when": "Phase A4 best-practice/pitfall search; Phase B [no-wiki] grounding" } }
```

### `intake` — the issue-tracker entry (optional)

When `intake` is configured and the user names a parent issue (key or URL),
orchestrate Phase 0 reads that issue and its children: the parent supplies the
overall goal/architecture, each child becomes a candidate task. With `intake` unset
(or for a free-text goal), orchestrate decomposes the natural-language goal itself —
the original behavior. So a Jira/GitHub/Linear shop plugs its tracker here; everyone
else just states a goal. Example mapping to the Atlassian MCP:

```json
{ "intake": { "kind": "mcp", "ref": "atlassian",
              "how": "getJiraIssue(parent) + searchJiraIssuesUsingJql('parent=<KEY>')",
              "when": "user gives a parent issue key/URL; children become tasks" } }
```

**Partial resume (one child already done).** A child counts as *completed* if the
user names it, or — when intake exposes status — its tracker status is Done.
orchestrate (Phase 0) drops completed children from the task set (no session), but
seeds the dependency graph with their **base outputs**, so any task that depends on
one still gets its exact signature injected (Phase 3 step 0). Never drop a completed
child silently — a dependent would lose its premise and re-create it. `setup-
worktrees.sh` is idempotent, so a branch/worktree the user already made is detected
and kept. To declare a completed child, give its **key + the exact signature it
exposed + where it's merged** (or let orchestrate read the signature from the
integration branch); see the README "이슈트래커 진입" section for a copy-paste prompt.

## A role is a tool, not a loop (the nesting guard)

A role plugs a **tool or information source into one step** of the verification
loop — it never replaces the loop. Do **not** map a role to a tool that runs its
own implement / verify / retry loop, or to another orchestrator (e.g. an
"implement-loop" skill). loop-implement already *is* the implementation loop;
nesting a second loop inside it makes the retry count, the Definition-of-Done
judgment, and the test-quality auditor gate ambiguous about which loop owns them,
and tends to drag in an environment-specific tool's own assumptions.

- There is intentionally **no `plan` role**. In dev-loop the plan step (step 2)
  is **fixed to the bundled `wiki-plan` skill** — planning is grounded in the
  `wiki/` semantic layers and is not user-configurable. (This is the one
  difference from upstream loop-orchestrator, where `plan` was a pluggable role
  defaulting to inline planning.)
- `verify` must **run tests and report** — not run a test-*and-fix* loop. A QA
  tool that auto-fixes belongs outside, not as a role.
- There is intentionally **no `implement` role**. Implementation is the loop's
  own step 4; that is the single owner of the implement/retry cycle.

## Config files & precedence

Layered like `git config`, lowest to highest:

```
built-in defaults  <  ~/.claude/dev-loop/tools.json  <  <repo>/.dev-loop/tools.json
```

Run **`/dev-loop:configure`** to set these up interactively (it maps your wiki,
test command, etc. and writes the file). The legacy `loop-orchestrator` paths
(`~/.claude/loop-orchestrator/tools.json`, `<repo>/.loop-orchestrator/tools.json`)
are still read as a fallback.

- **per-user** (`~/.claude/dev-loop/tools.json`) — your machine's tools,
  applied across every project.
- **per-repo** (`<repo>/.dev-loop/tools.json`) — commit it to share a
  team-standard mapping; overrides your per-user file.
- Merge is **per role and per field**: a per-repo file can override one role — or
  one field of a role — and inherit the rest. To drop an inherited value, set that
  field to `null`.

## Schema

```jsonc
{
  "<role>": {
    "kind": "mcp" | "skill" | "agent" | "cli" | "default",
    "ref":  "<server / skill / agent name or command>",   // omit when kind=default
    "how":  "<short invocation hint, e.g. tool call sequence>",  // optional
    "when": "<one line: when this role should be consulted>"     // optional
  }
}
```

- `kind: "default"` (or an omitted role) → use loop-implement's own generic
  behavior for that role (no external dependency).
- Unknown/invalid config file → ignored with a warning (fail-open to defaults).

See `examples/tools.example.json` for an RTB-flavored profile
(wiki-rag / rtb-lore). Note: `plan` is not configurable here — step 2 always
runs the bundled `wiki-plan` skill.

## Resolving (for skills/scripts)

```sh
sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh            # resolved JSON
sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --summary  # one line per role
sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --role verify
```

`orchestrate` resolves the profile once and writes each role's guidance into the
per-task `<tools_guidance>` brief, so spawned worker sessions get it even if they
can't re-read the config. `loop-implement` resolves it directly when run standalone.
