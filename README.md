# dev-loop

**English** | [한국어](README.ko.md)

A Claude Code plugin that merges two things into one self-contained tool:

- **[loop-orchestrator]** — a methodology-grounded verification loop (TDD / PDCA /
  Reflexion) for driving one task, or many parallel tasks, to "done".
- **[dev-llm-wiki]** — a case-routed, semantic-layer knowledge base of software
  best-practices and edge cases, plus a planning methodology that grounds every
  design decision in it.

**The one change from upstream loop-orchestrator:** the plan step is no longer an
optional, pluggable role. It is **fixed to the bundled `wiki-plan` methodology** —
every non-trivial task plans by routing each design decision to a page in the
bundled `wiki/` before any code is written. The rest of the loop is unchanged.

On top of that, dev-loop adds a **knowledge-capture loop**: your sessions emit
verified insights, and `knowledge-flush` researches, de-dups, routes, and opens a
reviewed PR that grows the wiki over time.

---

## Install (global)

Installed via the Claude Code plugin marketplace, so the skills and hooks apply
**globally across every project** you work in:

```
/plugin marketplace add choiyounggi/dev-loop
/plugin install dev-loop@dev-loop
```

Nothing is repo-scoped: the wiki-grounded loop, the `★ Insight` capture
instruction, and the harvest hook are active in any repository you open.

---

## The implementation loop

Run it two ways:

- **One task or one feature** → the `loop-implement` skill — the **single
  implementer**. Step 2 runs `wiki-plan` once to produce an ordered task list where
  each task names the exact wiki pages that ground it; the loop then executes those
  tasks **in the plan's order**, and per task runs:
  `0 define done → 1 analyze + load the task's named wiki pages → 3 tests (Red)
  → 4 implement (apply the pages' directives, no improvisation) → 5 run → 6
  self-review → 6.5 independent test-quality audit → 7 judge (report the WIKI
  references applied) → 7b reflect + retry (bounded)`. There is no separate
  executor — the wiki-executor discipline (load only named pages, decisions win,
  BLOCKED-on-gap) is folded into this loop.
- **A whole goal, split across parallel worker sessions** → the `orchestrate`
  skill: intake → decompose (approval gate) → per-wave plan (wiki-plan) →
  implement + review (each session runs `loop-implement`) → integration test →
  pre-merge gate → merge. **Substrate is automatic: if Orca is detected it drives
  spawn *and supervision*; otherwise raw tmux.** On Orca each phase is a tracked
  Task + Dispatch, and the coordinator blocks on pushed `worker_done` /
  `escalation` / `question` mail instead of polling status files on a timer — so
  a worker's blocking question reaches you in seconds. On tmux the original
  status-file poll is unchanged. Either way, worker sessions escalate a
  guardrails `ask` instead of blocking, and a dead worker is detected fast rather
  than stalling the run.

### Step 2 is fixed to `wiki-plan`

`wiki-plan` makes the planner do a **wiki routing sweep**: read `INDEX.md`, then
each touched domain's `index.md`, and for every design decision find the page
that owns it — recording a `decision → wiki page` map. Decisions are written as
concrete values/code (never "as appropriate"), so the implementing pass executes
instead of guessing. A decision no page covers is marked `[no-wiki]` and becomes
an ingest candidate. This is not a configurable role and cannot be turned off.

The wiki lives at the plugin root (`wiki/`, `INDEX.md`, `AGENTS.md`,
`templates/`); the wiki skills resolve their paths against `${CLAUDE_PLUGIN_ROOT}`.

### Configuring your tools (optional)

Like loop-orchestrator, dev-loop runs fully generic with **no** config, but you
can map its **capability roles** to your real tools so the loop uses them:

| Role | Map to |
|------|--------|
| `verify` | your project's **test / build / QA** command (the loop's run step) |
| `knowledge` | your domain/team **wiki** or knowledge MCP (external facts) |
| `explore` | code/symbol search (LSP, ripgrep, a source-search CLI) |
| `tacit` | past incidents / danger-zone lore |
| `design` | Figma / visual-spec MCP (UI work) |
| `intake` | issue tracker (orchestrate's work-list) |

(`plan` is **not** a role — the plan step is fixed to `wiki-plan`. And the bundled
best-practice `wiki/` needs no config; `knowledge` is a *separate* external wiki.)

Set it up with **`/dev-loop:configure`**, which writes `~/.claude/dev-loop/tools.json`
(global) or `<repo>/.dev-loop/tools.json` (per-repo, team-shared). Precedence is
git-config style: `defaults < ~/.claude/dev-loop/tools.json < <repo>/.dev-loop/tools.json`.
A SessionStart hook nudges you (at most weekly, then never) if you haven't
configured anything — silence it with `DEV_LOOP_CONFIG_NUDGE=0`. Legacy
`loop-orchestrator` config paths are still read as a fallback. See
`references/tool-profile.md` and `examples/tools.example.json`.

---

## The knowledge-capture loop

The wiki is meant to grow from what you actually learn. Three moving parts:

1. **Capture (global, automatic).** A SessionStart hook injects a standing
   instruction: whenever, in any repo, you discover a verified best-practice or a
   real edge case worth persisting, emit a compact `★ Insight` block (trigger /
   directive / why / evidence / domain / tags).

2. **Harvest (automatic, offline).** A Stop hook scrapes those blocks from the
   session transcript into a local queue (`~/.dev-loop/queue/`). It dedupes
   against both the session's queue file and the already-flushed store
   (`.processed.jsonl`), caps a session at 10 rows as a runaway backstop, and
   cleans up emptied queue files. It never edits the wiki and never opens a
   PR — harvesting is cheap and non-blocking.

3. **Flush → verified PR (automatic, or on-demand).** The queue is drained by the
   `knowledge-flush` pipeline. For **each** candidate it must, before any PR:
   - **research & verify** the best-practice against real sources (official docs,
     primary references) and assign a confidence (verified / field-tested /
     unverified — never a fabricated citation),
   - **check existing layers** for duplicates to merge into and pages to link
     (naming the page ids it actually read),
   - **check open `knowledge/*` PRs** so sibling flushes don't pile up duplicate
     PRs — each candidate is folded into an in-flight PR, dropped as a pending
     duplicate, or ingested as new,
   - **decide the target layer/category** (or justify a new category),
   - then run `wiki-ingest` and write an `INGEST_REPORT.md`.

   It opens **one PR per flush** and **never auto-merges**. Each contributor's PR
   is committed and opened under **their own git/gh identity** (never a hardcoded
   account, never an assistant); the repo owner reviews the open
   `dev-loop:knowledge` PRs and merges or rejects each one.

   Two ways it runs:
   - **Automatic** — the `hooks/auto-flush.sh` Stop hook fires the pipeline in a
     detached, headless `claude` run when the queue crosses a threshold and the
     rate-limit window has elapsed, so PRs appear without you doing anything.
     Guarded: kill switch `DEV_LOOP_AUTOFLUSH=0`, once per
     `DEV_LOOP_AUTOFLUSH_INTERVAL` (default 3600s), only at
     `DEV_LOOP_AUTOFLUSH_MIN` (default 3) pending items, single-flight lock, and
     recursion-safe. Needs `claude` + `gh` on PATH and gh authenticated; if either
     is missing it silently no-ops and you fall back to manual.
   - **Manual** — invoke `/dev-loop:knowledge-flush` any time to drain the queue now.

### This ordering is enforced by a hook

`hooks/pre-flush-pr-gate.sh` (PreToolUse) **blocks** `gh pr create` on a
knowledge branch unless the `INGEST_REPORT.md` exists and has all four sections
(`## Verified best-practice`, `## Existing-layer check`, `## Open-PR check`,
`## Routing decision`) filled with real content. The Existing-layer check must
carry a `Pages read: <id>, …` line, and each id is resolved against the
checkout's `wiki/` — a report citing pages that don't exist fails closed. The
gate is narrowly scoped to knowledge-flush PRs, so it never interferes with
ordinary `gh pr create` in any repo.

---

## Skills

| Skill | Role |
|-------|------|
| `loop-implement` | **The single implementer** — consumes the wiki-plan and executes its tasks in order (loading each task's named wiki pages) through the verification loop. Plan step = wiki-plan. |
| `orchestrate` | Split one goal into parallel worker sessions, each running loop-implement — over **Orca when detected** (Task/Dispatch tracking, event-driven `worker_done`/`ask`/`escalation` waits, native liveness), else tmux status-file polling. Workers escalate guardrails `ask`s instead of blocking; dead workers are detected. |
| `wiki-plan` | **The fixed plan methodology** — route each decision to a wiki page, decompose into ordered, page-navigated tasks. |
| `wiki-ingest` | Add verified knowledge to the right semantic layer (used by knowledge-flush). |
| `wiki-query` | Answer a question from the wiki with citations. |
| `wiki-lint` | Health-check the wiki. |
| `knowledge-flush` | Research + verify + route queued insights → one reviewed wiki PR. |
| `configure` | Set up the capability-role tool profile (map your wiki, test command, etc.). |

## Structure

```
dev-loop/
├── .claude-plugin/{plugin,marketplace}.json
├── AGENTS.md INDEX.md templates/     # wiki schema + routing entry + page/brief/session-prompt templates
├── wiki/                             # 10-domain semantic-layer knowledge base
├── skills/                           # the 8 skills above (user-invocable; appear in the / menu by skill name)
├── agents/test-quality-auditor.md    # bundled independent test auditor (loop step 6.5)
├── hooks/
│   ├── hooks.json
│   ├── preflight.sh                  # SessionStart: git/tmux/jq advisory
│   ├── insight-instruction.sh        # SessionStart: inject ★ Insight capture instruction (global)
│   ├── config-nudge.sh               # SessionStart: nudge to /dev-loop:configure if unconfigured (weekly)
│   ├── loop-gate.sh                  # Stop: verification-loop integrity gate
│   ├── harvest-insights.sh + harvest.js  # Stop: harvest insights → queue
│   ├── auto-flush.sh                 # Stop: auto-run knowledge-flush (guarded) → PR
│   └── pre-flush-pr-gate.sh          # PreToolUse: enforce the flush pre-PR pipeline
├── scripts/resolve-tools.sh          # capability-role profile resolver (no `plan` role)
├── tests/                            # bats suites — hooks (harvest, flush gate, loop gate) + orchestration scripts; CI runs them on ubuntu + macos
├── references/tool-profile.md
└── docs/                             # inherited design notes (loop-orchestrator lineage)
```

---

## Attribution

Knowledge PRs (manual or auto-opened) are committed under **each contributor's own
git/gh identity** — never a hardcoded account and never an assistant, with no
`Co-Authored-By` trailer. Every contributor opens a PR from their own account; the
repo owner reviews and merges/rejects.

## Lineage & license

Forked from **loop-orchestrator** and **dev-llm-wiki** (both by choiyounggi).
See `docs/` for the inherited loop design (note: those docs predate the
fixed-plan-step change described above). MIT — see `LICENSE`.

[loop-orchestrator]: https://github.com/choiyounggi/loop-orchestrator
[dev-llm-wiki]: https://github.com/choiyounggi/dev-llm-wiki
