---
name: configure
description: Set up dev-loop's capability-role tool profile — map `knowledge` (your domain wiki / MCP), `verify` (your project's test/build/QA command), `explore` (code search), `tacit` (past incidents), and `design` (Figma/visual spec) to the actual tools this environment has, then write ~/.claude/dev-loop/tools.json (global) or <repo>/.dev-loop/tools.json (per-repo). Use when asked to "configure dev-loop", "set up tools", "map my wiki/test command", or "/dev-loop:configure".
---

# configure — set up the dev-loop tool profile

dev-loop runs fully generic with **no** config (every role falls back to the
model's own behavior). Configuring the roles makes the loop use *your* real tools:
your domain wiki for facts, your actual test command for verification, etc. The
bundled best-practice `wiki/` (used by `wiki-plan`) needs no config — the
`knowledge` role is for a separate *external/domain* wiki.

> Note: the plan step is fixed to `wiki-plan` and is NOT configurable. There is no
> `plan` role.

## Steps

1. **Show the current profile.** Run and report what is already set vs. default:
   ```sh
   sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --summary
   ```

2. **Decide scope.**
   - **Global** (all your projects): `~/.claude/dev-loop/tools.json`
   - **Per-repo** (committed, team-shared; overrides global per role/field):
     `<repo>/.dev-loop/tools.json`
   Ask the user which, if unclear. (Legacy `~/.claude/loop-orchestrator/tools.json`
   and `<repo>/.loop-orchestrator/tools.json` are still read as a fallback.)

3. **Map each role to a real tool.** Read `${CLAUDE_PLUGIN_ROOT}/examples/tools.example.json`
   as the shape and `references/tool-profile.md` for the schema. For THIS
   environment, detect and propose concrete mappings, then confirm with the user:

   | Role | Map to | How to find it |
   |------|--------|----------------|
   | `knowledge` | your domain/policy **wiki** or knowledge MCP | check available MCP servers (e.g. a `wiki_search`/`search_wiki` tool) |
   | `verify` | your project's **test / build / QA** command | read `package.json` scripts / Makefile / `pom.xml` / CI config for the real command |
   | `explore` | code/symbol search (LSP, `rtb-sourcecode`, ripgrep) | what this repo/language supports |
   | `tacit` | past incidents / danger-zone lore (MCP) | check for a lore/incidents MCP |
   | `design` | Figma / visual-spec MCP | only if UI work; check for a Figma MCP |
   | `intake` | issue tracker (orchestrate work-list) | Jira/GitHub issues MCP, if used |

   Leave any role the user has no tool for as `default` (omit it).
   `kind` is one of `mcp | skill | agent | cli | default`; add `ref`, and
   optionally `how` (invocation hint) and `when` (a one-line trigger).

4. **Write the file** for the chosen scope, e.g. global:
   ```jsonc
   // ~/.claude/dev-loop/tools.json
   {
     "knowledge": { "kind": "mcp", "ref": "<your-wiki-mcp>", "how": "search -> read", "when": "domain facts, policy, code values" },
     "verify":    { "kind": "cli", "ref": "<your test/build command>", "how": "run only; report failures verbatim", "when": "step 5 — running tests" }
   }
   ```
   Include only the roles being set; unset roles inherit `default`. For `verify`,
   map the **exact** command (e.g. `pnpm -w test`, `./gradlew test`) — verified by
   reading the project's build config, not guessed.

5. **Validate.** Re-run `resolve-tools.sh --summary` and confirm each role now
   resolves as intended (not `default` where you set it). Report the final profile.

## Guardrails
- Never map `verify` (or any role) to a tool that runs its own implement/fix/retry
  loop — a role is injected into ONE loop step, never a nested loop (see
  `references/tool-profile.md`). `verify` must run tests and report only.
- Do not invent MCP/tool names — only map tools you confirmed exist in this
  environment. If unsure, leave the role `default` and say so.
- Never write secrets/tokens into tools.json; reference tools by name only.
