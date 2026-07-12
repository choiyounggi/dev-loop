# dev-loop

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

- **One task** → the `loop-implement` skill. Its loop:
  `0 define done → 1 analyze → 2 PLAN (wiki-plan, required) → 3 write tests (Red)
  → 4 implement (Green) → 5 run → 6 self-review → 6.5 independent test-quality
  audit → 7 judge → 7b reflect + retry (bounded)`.
- **A whole goal, split across parallel tmux sessions** → the `orchestrate`
  skill: intake → decompose (approval gate) → per-wave plan (wiki-plan) →
  implement + review → integration test → pre-merge gate → merge.

### Step 2 is fixed to `wiki-plan`

`wiki-plan` makes the planner do a **wiki routing sweep**: read `INDEX.md`, then
each touched domain's `index.md`, and for every design decision find the page
that owns it — recording a `decision → wiki page` map. Decisions are written as
concrete values/code (never "as appropriate"), so the implementing pass executes
instead of guessing. A decision no page covers is marked `[no-wiki]` and becomes
an ingest candidate. This is not a configurable role and cannot be turned off.

The wiki lives at the plugin root (`wiki/`, `INDEX.md`, `AGENTS.md`,
`templates/`); the wiki skills resolve their paths against `${CLAUDE_PLUGIN_ROOT}`.

---

## The knowledge-capture loop

The wiki is meant to grow from what you actually learn. Three moving parts:

1. **Capture (global, automatic).** A SessionStart hook injects a standing
   instruction: whenever, in any repo, you discover a verified best-practice or a
   real edge case worth persisting, emit a compact `★ Insight` block (trigger /
   directive / why / evidence / domain / tags).

2. **Harvest (automatic, offline).** A Stop hook scrapes those blocks from the
   session transcript into a local queue (`~/.dev-loop/queue/`). It never edits
   the wiki and never opens a PR — harvesting is cheap and non-blocking.

3. **Flush (on-demand, you trigger it).** `/dev-loop:knowledge-flush` drains the
   queue. For **each** candidate it must, before any PR:
   - **research & verify** the best-practice against real sources (official docs,
     primary references) and assign a confidence (verified / field-tested /
     unverified — never a fabricated citation),
   - **check existing layers** for duplicates to merge into and pages to link,
   - **decide the target layer/category** (or justify a new category),
   - then run `wiki-ingest` and write an `INGEST_REPORT.md`.

   It opens **one PR per flush** and **never auto-merges**. You review the open
   `dev-loop:knowledge` PRs and merge or reject each one.

### This ordering is enforced by a hook

`hooks/pre-flush-pr-gate.sh` (PreToolUse) **blocks** `gh pr create` on a
knowledge branch unless the `INGEST_REPORT.md` exists and has all three sections
(`## Verified best-practice`, `## Existing-layer check`, `## Routing decision`)
filled with real content. The gate is narrowly scoped to knowledge-flush PRs, so
it never interferes with ordinary `gh pr create` in any repo.

---

## Skills

| Skill | Role |
|-------|------|
| `loop-implement` | Drive one task to done through the verification loop (plan step = wiki-plan). |
| `orchestrate` | Split one goal into parallel sessions, each running loop-implement. |
| `wiki-plan` | **The fixed plan methodology** — route each decision to a wiki page, decompose. |
| `wiki-implement` | Small-model per-task executor for the orchestrate/wiki-plan split. |
| `wiki-ingest` | Add verified knowledge to the right semantic layer (used by knowledge-flush). |
| `wiki-query` | Answer a question from the wiki with citations. |
| `wiki-lint` | Health-check the wiki. |
| `knowledge-flush` | Research + verify + route queued insights → one reviewed wiki PR. |

## Structure

```
dev-loop/
├── .claude-plugin/{plugin,marketplace}.json
├── AGENTS.md INDEX.md templates/     # wiki schema + routing entry + page template
├── wiki/                             # 10-domain semantic-layer knowledge base
├── skills/                           # the 8 skills above
├── agents/test-quality-auditor.md    # bundled independent test auditor (loop step 6.5)
├── hooks/
│   ├── hooks.json
│   ├── preflight.sh                  # SessionStart: git/tmux/jq advisory
│   ├── insight-instruction.sh        # SessionStart: inject ★ Insight capture instruction (global)
│   ├── loop-gate.sh                  # Stop: verification-loop integrity gate
│   ├── harvest-insights.sh + harvest.js  # Stop: harvest insights → queue
│   └── pre-flush-pr-gate.sh          # PreToolUse: enforce the flush pre-PR pipeline
├── scripts/resolve-tools.sh          # capability-role profile resolver (no `plan` role)
├── references/tool-profile.md
└── docs/                             # inherited design notes (loop-orchestrator lineage)
```

---

## Attribution

Contributions (including auto-opened knowledge PRs) are committed as the repo
owner (`choiyounggi`), not as an assistant, and carry no `Co-Authored-By` trailer.

## Lineage & license

Forked from **loop-orchestrator** and **dev-llm-wiki** (both by choiyounggi).
See `docs/` for the inherited loop design (note: those docs predate the
fixed-plan-step change described above). MIT — see `LICENSE`.

[loop-orchestrator]: https://github.com/choiyounggi/loop-orchestrator
[dev-llm-wiki]: https://github.com/choiyounggi/dev-llm-wiki
