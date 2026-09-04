---
name: wiki-plan
effort: high
argument-hint: "[what to build]"
description: The fixed planning methodology for a capable model. Make every design decision grounded in a bundled wiki page (recording a decision-to-page map), then decompose the work into ordered, self-contained tasks, each naming the exact wiki pages that govern it. Runs as loop-implement step 2.
---

# Plan — decompose work into small-model-executable tasks

> **In the dev-loop plugin.** The wiki is bundled with the plugin, not in the
> user's project. Resolve every `INDEX.md`, `wiki/<...>.md`, `AGENTS.md`, and
> `templates/` path in this skill against **`${CLAUDE_PLUGIN_ROOT}/`** (the
> installed plugin root), NOT the current working directory. Read the wiki from
> there; write plan output (`plans/<feature>/`) into the user's project as
> described in Phase A/B/C below.
>
> **How this plugs into the loop.** `loop-implement` calls this skill as its
> **step 2 (Plan)** — mandatory, and the call site never changes. Internally
> this runs three gated phases — **Phase A (Analyze)** → **gate-A** → **Phase B
> (Design)** → **gate-B** → **Phase C (Decompose)** — that produce, in order,
> `analysis.md`, `design.md` (+ `review-verdict.md`), then the wiki-grounded
> `plan.md` and one `tasks/NN-*.md` per task naming the exact wiki pages it
> needs. **`loop-implement` is the single implementer** — it then executes
> those tasks *in order*, loading each task's named pages and running the
> verification loop (Red → Green → run → audit) per task. (`orchestrate` uses
> the same output to fan tasks across sessions, each session running
> `loop-implement`.) Every decision must cite a `wiki/` page or be marked
> `[no-wiki]`.

You are the planner. The implementer will be a small model with no memory of this
planning session. Its entire world per task = one task file + the wiki pages that
file names + the artifacts earlier tasks produced. **Every decision you leave
unmade becomes the small model's guess** — and guesses are where errors enter.

## Rule zero

Decisions live in the plan; execution lives in the tasks. If writing a task makes
you type "choose", "decide", "as appropriate", or "either" — stop, make that
decision now, and write the decision into the task.

## Lite mode (skip full A/B when it would be theater)

Before Phase A, check whether this task qualifies for lite mode — all three
conditions must hold, and all three are machine-checkable, so this is never a
judgment call:
- expected `## Size verdict` (see Phase C step 5) is `small`
- zero `[no-wiki]` decisions expected
- the feature touches no pinned file, no security-sensitive surface, no
  migration

If any condition fails, run full Phase A → gate-A → Phase B → gate-B → Phase C.
If all three hold: write a single `analysis.md` with A1/A2 abbreviated (the
`## Requirements` table and `## Ground truth` stay — the baseline pin and the
`Affected files`/`Constraints` evidence are never optional), skip A3/A4's full
treatment, and skip the `plan-reviewer` call entirely. Still emit gate-A and
gate-B (`plan-gate.sh emit` + `gate-check.sh --run`, same as full mode below) —
lite mode changes what you write, not whether the gates run. Because
`research-evidenced` and `reviewer-verdict` have nothing to check in lite mode,
publicly abandon them on the ledger instead of leaving them unmet or deleting
them:
```
ABANDON: research-evidenced lite mode (small, no no-wiki, no pins)
ABANDON: reviewer-verdict lite mode (small, no no-wiki, no pins)
```
A quiet skip is never allowed — every abandonment must appear on the ledger and
in the eventual task report's `GATES:` line. (This is the same abandonment
mechanism `templates/gates.md` already uses.)

## Phase A — Analyze (produces `plans/<feature>/analysis.md`)

Copy `${CLAUDE_PLUGIN_ROOT}/templates/analysis.md` to `plans/<feature>/analysis.md`
and fill it in. Its section headers are parsed by `plan-gate.sh` — keep them
exactly as the template has them.

**A1. Requirements + acceptance examples** (Example Mapping: Rule / Concrete
example / Open question). While a question is unresolved, mark it literally
`OPEN: <question>` in the Open question cell — the gate fails while any `OPEN:`
token remains, so leaving a question unresolved is what blocks entry to Phase B
(Definition of Ready), not a missing checkbox.

**A2. Ground truth** — evidence, not claims:
- `Baseline: <test command> -> rc=<n>, HEAD <sha>, git status <clean|dirty>` —
  record one command that can be copy-pasted and re-run as-is; gate-A re-runs
  this exact command.
- `### Affected files` — every bullet needs an `evidence:` token backed by a
  real search (`<path> — evidence: <search command> -> <n> hits`). A
  code-graph hit (`explore` = graphify) may be cited only in the same bullet
  as that search, as a lead: `<path> — evidence: graphify explain <Symbol> ->
  <N> connections; <search command> -> <n> hits` — the graph chooses where to
  look, the search decides what is true
  (`wiki/infrastructure/agent-orchestration/code-graph-as-orientation-layer.md`).
- `Constraints` — every pinned file, protected span, and CI requirement this
  feature touches, each with the command used to check it; if none apply, say
  so explicitly (an empty section fails the gate).

**A3. Spikes** — timebox investigation of any load-bearing unknown (XP spike).
Record what was discovered in `## Spikes`. A remaining unknown that blocks
Phase B is escalated to the requester now — never carried forward as a
placeholder.

**A4. Research** (`research` role — resolution order and fallback owned by
`loop-implement`'s Tool profile section, not repeated here) — confirm this
feature's domain has no known best-practice/pitfall you're missing: at least
one search, logged in `## Research` as `Query | Source | Applied`, or the
literal no-useful-results line the template shows. Wiki pages take priority
over research — research targets `[no-wiki]` territory and Spikes. If no
search tool is reachable at all, `ABANDON` the `research-evidenced` gate in the
open (never a silent skip).

**gate-A** — once `analysis.md` is complete:
```
sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh emit A plans/<feature> .dev-loop/gates/plan-A-<feature>.md
sh ${CLAUDE_PLUGIN_ROOT}/skills/loop-implement/scripts/gate-check.sh --run .dev-loop/gates/plan-A-<feature>.md
```
Gate ids: `baseline-tests-ran`, `affected-files-evidenced`,
`open-questions-resolved`, `constraints-surveyed`, `research-evidenced`. Exit 0
(every gate MET or explicitly ABANDONed) before entering Phase B; a failing
gate means fixing `analysis.md`, not editing the gate.

## Phase B — Design (produces `plans/<feature>/design.md`)

Copy `${CLAUDE_PLUGIN_ROOT}/templates/design-doc.md` to `plans/<feature>/design.md`
(note the filename changes from `design-doc.md` to `design.md`). Its `## Decisions`
table now has six columns:

```markdown
| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |
```

**Wiki routing sweep** — read the wiki's `INDEX.md`, then the `index.md` of
every domain the work touches. For each design decision, find the page that
owns it (match "load when" lines), apply its directives now, and record the
decision + page. `Wiki basis` is a repo-relative path,
`wiki/<domain>/<category>/<page>.md`, to a page that actually exists — not a
page id — or the literal `[no-wiki]` (with the decision noted as an ingest
candidate); gate-B greps every non-`[no-wiki]` path under the wiki root and
fails on any miss. Example, for a login feature:

| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |
|---|----------|--------|------------|----------------------|-------------|
| D1 | PK type for users | UUIDv7, app-generated | `wiki/databases/schema-design/primary-key-choice.md` | Auto-increment int — leaks row count, harder to shard | any insert path missing an explicit id |
| D2 | Auth mechanism | Session cookie, not token | `wiki/security/authn/session-vs-token.md` | JWT — needless revocation complexity for this scale | session-fixation / logout test |
| D3 | Re-signup after delete | Soft-delete + partial unique index | `wiki/databases/schema-design/soft-delete.md`, `wiki/databases/schema-design/partial-and-expression-indexes.md` | Hard delete — loses audit trail | re-signup integration test |

`Testability` names the test/gate that would catch this decision being wrong —
never leave it blank; a row missing any of the six cells fails
`decision-rows-complete`.

**Independent review** — call the `plan-reviewer` subagent (Agent tool) with:
the `analysis.md` path (including its `## Research` section), the `design.md`
path, the requester's original goal text, and the wiki root
(`${CLAUDE_PLUGIN_ROOT}`). It is read-only, fresh-context, and returns
`VERDICT: PASS | FAIL` + `FINDINGS:` + `SUMMARY:`. Record its full output under
`design.md`'s `## Review`; if `VERDICT: PASS`, copy just the `VERDICT: PASS`
line into `plans/<feature>/review-verdict.md` (gate-B reads that file, not the
`## Review` section). If `VERDICT: FAIL`, resolve every `blocking` finding and
re-call — bounded at 3 total calls; a 3rd `FAIL` is STOP + escalate to the
requester, not a forced PASS.

**gate-B**:
```
sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh emit B plans/<feature> .dev-loop/gates/plan-B-<feature>.md
sh ${CLAUDE_PLUGIN_ROOT}/skills/loop-implement/scripts/gate-check.sh --run .dev-loop/gates/plan-B-<feature>.md
```
Gate ids: `groundings-exist`, `decision-rows-complete`, `reviewer-verdict`.
Exit 0 before entering Phase C.

## Phase C — Decompose (produces `plans/<feature>/plan.md` + `tasks/NN-*.md`)

3. **Order by dependency, not by layer preference.** Data before code that uses
   it, contracts before consumers, server before client integration:
   schema/migrations → server core (domain logic) → server API surface → client →
   integration/e2e verification. Two tasks with no dependency edge may note
   `parallel-ok`.

4. **Cut tasks to small-model size.** Every task must satisfy ALL of:
   | Criterion | Bound |
   |-----------|-------|
   | One concern | A reader can title it without "and" |
   | Files touched | ≤ 3 created/modified |
   | Wiki context | ≤ 4 pages needed |
   | Verifiable | Has a command or concrete check that proves it done |
   | Self-contained | Doable from the task file + named wiki pages + named prior artifacts — no reading of other task files |
   A task that fails a bound gets split; a task too trivial to verify gets merged
   into its neighbor.

5. **Write the files** (into the target project, `plans/<feature>/`):

   `plans/<feature>/plan.md`:
   ```markdown
   # <feature>
   Goal: <1-3 lines + acceptance criteria>
   Stack: <language/framework/DB — exact versions where they matter>
   ## Decisions
   | # | Decision | Choice | Wiki basis |
   |---|----------|--------|------------|
   | D1 | PK type for users | UUIDv7, app-generated | wiki/databases/schema-design/primary-key-choice.md |
   ## Size verdict
   size: small | medium | large
   ## Task order
   | Task | Depends on | Parallel-ok |
   ```

   **`## Size verdict` is REQUIRED, not optional.** Judge it against the step-4
   bounds table, aggregated over the whole plan: `small` = ≤3 tasks, `medium` =
   ≤8 tasks, `large` = >8 tasks OR any single task still breaking a step-4 bound
   after you've tried to split it. When the verdict is `large`, the section MUST
   also carry a recommended pre-dispatch split: per piece, its `files` and
   `outputs` — the exact fields `graph-add.sh` validates, so the split can be
   applied as independent graph nodes without another round-trip through you.

   `plans/<feature>/tasks/NN-<slug>.md` — one per task:
   ```markdown
   # Task NN: <one-concern title>
   ## Objective
   <what exists when this is done — observable, 1-3 lines>
   ## Wiki pages (read these first, only these)
   - wiki/<path>.md — use for: <which part of this task it governs>
   ## Inputs
   - <artifact from task NN-1: exact file path / interface name>
   - Decisions that bind you: D1 (UUIDv7), D3 (...)
   ## Steps
   1. <concrete step — names, paths, signatures spelled out>
   ## Deliverables
   - <exact file paths created/modified>
   - if this task touches a pinned file named in analysis.md's `Constraints`,
     name the pin update here explicitly (e.g. "bump the cksum pin in
     tests/session-prompt-rework.bats") — a task that touches a pin without
     declaring its update is a plan defect, not a surprise for the implementer.
   ## Verify
   - <command to run and what output means success; or concrete checklist>
   - covers: R<n> — the `## Requirements` row (from analysis.md's A1) this
     task's verification proves; a task covering no Rule is a scope-creep
     signal, and a Rule covered by no task is a coverage gap.
   ## Out of scope
   - <the adjacent thing the next task does — so the implementer stops at the boundary>
   ```

6. **Self-check before handing off.** For each task, simulate a Haiku-grade
   implementer: reading ONLY that file + its wiki pages, is there any point where
   it must choose between two designs, invent a name/type/endpoint, or open an
   unnamed file? Each such point is a planning defect — fix the task, don't hope.
   Then check the seams: every Input names a Deliverable of an earlier task,
   verbatim. Then check the verdict: is the `## Size verdict` present, and is
   it consistent with the task table — does its `small`/`medium`/`large` call
   actually match the task count and the step-4 bounds you just checked? Then
   check coverage both directions: every Rule in analysis.md's `## Requirements`
   is named by at least one task's `covers:` line, and every task's `covers:`
   line names a Rule that actually exists — an orphan on either side goes back
   to Phase A/C for repair before dispatch.

## Execution handoff

Tasks are executed one at a time, in `## Task order`, by **`loop-implement`** —
the single implementation loop. It loads each task's named wiki pages, applies
their directives (task D-number decisions win), and runs the verification loop
(tests → audit → judge) before moving to the next task. (In `orchestrate`, each
task is dispatched to its own session, which runs `loop-implement`.)

If execution reports BLOCKED, the fix belongs here: the task was under-specified.
Repair the task file (or a decision in `plan.md`), then re-dispatch — a BLOCKED
report means the plan left a decision to the implementer, not that execution
failed.
