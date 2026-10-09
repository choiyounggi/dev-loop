---
id: platforms-toolchains-agent-files-written-by-next-dev
domain: platforms
category: toolchains
applies_to: [nextjs]
confidence: verified
sources:
  - https://nextjs.org/docs/app/api-reference/config/next-config-js/agentRules
  - https://nextjs.org/docs/app/guides/ai-agents
  - https://github.com/vercel/next.js/pull/92910
  - https://github.com/vercel/next.js/pull/99043
  - https://unpkg.com/next@16.4.0/dist/server/lib/generate-agent-files.js
  - https://unpkg.com/next@16.4.0/dist/server/lib/app-info-log.js
  - "Docs bundled with next 16.3.8: node_modules/next/dist/docs/01-app/02-guides/ai-agents.md"
  - "Installed source, next 16.3.8: dist/server/lib/start-server.js, app-info-log.js, generate-agent-files.js, dist/compiled/@vercel/detect-agent/index.js"
  - "Field case 2026-10-07 (agent-driven next dev in a dev-loop task worktree): both files created, untracked, not in .gitignore"
last_verified: 2026-10-08
related: [qa-process-scope-purity-checks]
---

# AGENTS.md and CLAUDE.md Written by `next dev`

## When this applies

`next dev` runs on Next.js 16.3 or later in a tree whose changes are then
harvested (`git add -A`, a scope-purity gate, a copy of untracked files into a
clean checkout), and either an AI coding agent runs it (Next detects env vars such
as `CLAUDECODE`, `CURSOR_TRACE_ID`, `GEMINI_CLI`, `CODEX_SANDBOX`) or
`agentRules: false` is set. Also when `AGENTS.md` or `CLAUDE.md` appear, change or
disappear after a dev-server run or a Next.js upgrade nobody asked to edit them.

## Do this

1. **Decide once per project whether the managed block is wanted, before
   agents run `next dev`.** The block points agents at the docs bundled in
   `node_modules/next/dist/docs/`.

| Project decision | Do |
|------------------|----|
| Keep the block (Next's default) | Commit it as its own change. Runs on the same Next version find a current block and write nothing. After each Next.js upgrade, run one agent-driven `next dev` and commit the rewritten block as its own change: the block text changes between releases (16.3.8 heads it `# This is NOT the Next.js you know`, 16.4.0 `## This is NOT …`) and only an exact match counts as current |
| No framework-written agent files | Set `agentRules: false` in `next.config`. On 16.3.x this stops new writes and leaves an existing block. From 16.4.0 every `next dev`, agent or not, removes the block from `AGENTS.md` and deletes the file when the block was its only content; commit that removal as its own change |

2. **Snapshot `git status --porcelain` before the run, then read what it wrote.**
   The write depends on the version and on which files existed
   (`writeAgentFiles` in `dist/server/lib/generate-agent-files.js`):

| Version | Before the run | After the run | What changed |
|---------|----------------|---------------|--------------|
| 16.3.x | Neither file | `?? AGENTS.md`, `?? CLAUDE.md` | Both created: `AGENTS.md` holds only the block, `CLAUDE.md` holds `@AGENTS.md` |
| 16.3.x | `AGENTS.md` exists, and it holds the block or `CLAUDE.md` does not | ` M AGENTS.md` | Block appended, or replaced between `<!-- BEGIN:nextjs-agent-rules -->` and `<!-- END:nextjs-agent-rules -->`; the rest is kept |
| 16.3.x | Only `CLAUDE.md` exists, or only `CLAUDE.md` holds the block | ` M CLAUDE.md` | Block upserted into `CLAUDE.md`; the rest is kept |
| 16.4.0+ | No `AGENTS.md` | `?? AGENTS.md` | Created with only the block; `CLAUDE.md` is never created or edited |
| 16.4.0+ | `AGENTS.md` exists | ` M AGENTS.md` | Block upserted; an older `<!-- NEXT-AGENTS-MD-START -->` block is stripped |
| 16.4.0+, `agentRules: false` | `AGENTS.md` holds the block | ` M AGENTS.md`, or the file is gone when it held only the block | Block removed |

3. **Keep the write out of an unrelated change set.** Stage your own paths
   explicitly (`git add <paths>`). Delete a file only when the pre-run snapshot
   did not list it and its content is exactly what Next writes (`AGENTS.md`: the
   block plus a newline; `CLAUDE.md`: `@AGENTS.md`). For any other file, remove
   only the block, the marker lines included, or leave the file unstaged. A removal
   returns on the next agent-driven `next dev`, so settle step 1.

## Edge cases

| Case | Then |
|------|------|
| `next build` or `next start` | Neither writes nor removes: the call sits inside `if (isDev)` in `start-server.js` (16.3.8 and 16.4.0) |
| `next dev` from a human terminal (no agent env var) | Nothing is written. With `agentRules: false` on 16.4.0+, the removal in step 1 still runs |
| A 16.3 project kept the block in `CLAUDE.md`, then upgrades to 16.4 | 16.4 checks only `AGENTS.md`: an agent run creates `AGENTS.md` with the new block and leaves the old copy in `CLAUDE.md`; delete that copy by hand |
| An untracked hand-written `AGENTS.md` or `CLAUDE.md` existed before the run | `??` looks the same as a created file; the pre-run snapshot and the content check in step 3 tell them apart |
| Which release stopped writing `CLAUDE.md` | PR #99043; the released 16.4.0 already carries it (its `generate-agent-files.js` never names `CLAUDE.md`) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `git checkout -- AGENTS.md CLAUDE.md` or `rm` them to clean the tree after a dev-server run | Compare with the pre-run snapshot and the generated content (step 3): delete only a file the run created, remove only the block (markers included) from any other | Next keeps a hand-written file's content outside the markers; reverting or deleting the whole file discards uncommitted edits to it |
| Harvest with `git add -A` after `next dev` ran | Stage explicit paths, or commit the block once per Next version (step 1) | The write, or the 16.4.0+ removal, lands in whatever the harvest picks up |

## Sources

- https://nextjs.org/docs/app/api-reference/config/next-config-js/agentRules — "The `agentRules` option controls whether `next dev` creates and updates version-matched documentation instructions for detected AI coding agents. It is enabled by default."; "The next `next dev` run removes the existing agent rules block and preserves all other content, even when no agent is detected."; version history: `v16.3.0` option added, `v16.4.0` "Setting `agentRules` to `false` removes an existing managed block on `next dev`"
- https://nextjs.org/docs/app/guides/ai-agents — "When `next dev` detects a coding agent, it creates or updates the managed instructions for existing projects."; "Next.js updates only the content between the agent rules markers and preserves the rest of `AGENTS.md`."; "Managed documentation instructions are enabled by default in Next.js 16.3 and later."
- https://github.com/vercel/next.js/pull/92910 — "Auto-generate AGENTS.md / CLAUDE.md in next dev", merged 2026-04-21
- https://github.com/vercel/next.js/pull/99043 — "`next dev`, `create-next-app`, upgrades … no longer create, discover, or update `CLAUDE.md`"
- https://unpkg.com/next@16.4.0/dist/server/lib/generate-agent-files.js and https://unpkg.com/next@16.4.0/dist/server/lib/app-info-log.js (16.4.0 is npm `latest` on 2026-10-08) — `syncAgentRulesForDev` returns `removeAgentRulesFiles(dir)` when disabled, before `getAgentName()`; `writeAgentFiles` creates or upserts only `AGENTS.md`; `removeManagedBlockFromFile` unlinks a file left empty; `hasCurrentAgentRules` reads only `AGENTS.md` and compares the block exactly; the block heading is `## This is NOT the Next.js you know`; `start-server.js` calls the sync inside `if (isDev)`
- Docs bundled with next 16.3.8 (`node_modules/next/dist/docs/01-app/02-guides/ai-agents.md`) — "When an AI coding agent is detected in the environment and no managed block is present, Next.js auto-generates `AGENTS.md` and `CLAUDE.md` at the project root. Existing `AGENTS.md` or `CLAUDE.md` files are upserted, so content outside the managed block is preserved"
- Installed source, next 16.3.8: `start-server.js` runs `ensureAgentRulesForDev(dir)` inside `if (isDev)` when `agentRules !== false`; `app-info-log.js` `ensureAgentRulesForDev` returns when `getAgentName()` is null or `hasCurrentAgentRules(dir)`; `generate-agent-files.js` `writeAgentFiles` writes `AGENTS.md` when it exists and holds the block or `CLAUDE.md` does not, else `CLAUDE.md` when it exists, else creates both; `CLAUDE_MD_CONTENT = '@AGENTS.md\n'`; the block heading is `# This is NOT the Next.js you know`; `compiled/@vercel/detect-agent/index.js` reads `CLAUDECODE`, `CLAUDE_CODE`, `CURSOR_TRACE_ID`, `GEMINI_CLI`, `CODEX_SANDBOX`, `CODEX_THREAD_ID`, `AI_AGENT`
- Field case 2026-10-07 (an agent-driven `next dev` in a dev-loop task worktree, Next.js 16.3.x): the dev log printed "✓ Generated AGENTS.md and CLAUDE.md for AI agents. Set `agentRules: false` in next.config to disable."; both files were untracked, absent from `.gitignore`, with mtimes equal to the dev-server start, and absent after a production build
