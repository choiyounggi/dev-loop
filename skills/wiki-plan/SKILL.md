---
name: wiki-plan
description: For a CAPABLE model (Claude Sonnet/Opus, GPT-4-class, Codex) — analyze a feature/change request, make every design decision, and decompose it into ordered, self-contained task specs that a SMALL model (Haiku, Qwen-class) can each execute correctly using only the task spec plus mapped wiki pages. Produces plan.md + tasks/NN-<slug>.md.
---

# Plan — decompose work into small-model-executable tasks

> **In the dev-loop plugin.** The wiki is bundled with the plugin, not in the
> user's project. Resolve every `INDEX.md`, `wiki/<...>.md`, `AGENTS.md`, and
> `templates/` path in this skill against **`${CLAUDE_PLUGIN_ROOT}/`** (the
> installed plugin root), NOT the current working directory. Read the wiki from
> there; write plan output (`plans/<feature>/`) into the user's project as
> described in step 5.
>
> **How this plugs into the loop.** `loop-implement` calls this skill as its
> **step 2 (Plan)** — mandatory. For a single loop-implement task, produce the
> wiki-grounded `## Decisions` table and a concrete plan; loop-implement then
> executes it through its own steps 3–7 (Red → Green → run → audit). The
> full task-decomposition + small-model handoff below (`tasks/NN-*.md` +
> `wiki-implement`) is what `orchestrate` uses to split a goal across sessions.
> Either way, **every decision must cite a `wiki/` page or be marked `[no-wiki]`**.

You are the planner. The implementer will be a small model with no memory of this
planning session. Its entire world per task = one task file + the wiki pages that
file names + the artifacts earlier tasks produced. **Every decision you leave
unmade becomes the small model's guess** — and guesses are where errors enter.

## Rule zero

Decisions live in the plan; execution lives in the tasks. If writing a task makes
you type "choose", "decide", "as appropriate", or "either" — stop, make that
decision now, and write the decision into the task.

## Steps

1. **Clarify the goal.** State what is being built, the acceptance criteria, and
   the stack (language, framework, DB). If the requester left a load-bearing choice
   open (stack, auth mechanism, data model), resolve it with them or state your
   chosen default explicitly in `plan.md` — the small model must never pick.

2. **Wiki routing sweep.** Read the wiki's `INDEX.md`, then the `index.md` of every
   domain the work touches. For each design decision in this work, find the page
   that owns it (match "load when" lines). Build the decision→page map, e.g. for a
   login feature:
   - users table shape → `wiki/databases/schema-design/requirements-to-tables.md`, `naming-conventions.md`, `column-data-types.md`
   - PK type → `wiki/databases/schema-design/primary-key-choice.md`
   - re-signup after delete → `soft-delete.md` + `partial-and-expression-indexes.md`
   - auth mechanism choice → `wiki/security/authn/session-vs-token.md`
   - server token handling → `wiki/backend/auth/jwt-server-side.md`
   - client token handling → `wiki/frontend/auth/token-handling-client-side.md`
   Apply those pages' directives NOW to make the decisions; record decision +
   page id in `plan.md`. A decision no wiki page covers → decide from your own
   judgment, mark it `[no-wiki]`, and note it as an ingest candidate.

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
   | D1 | PK type for users | UUIDv7, app-generated | databases-schema-design-primary-key-choice |
   ## Task order
   | Task | Depends on | Parallel-ok |
   ```

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
   ## Verify
   - <command to run and what output means success; or concrete checklist>
   ## Out of scope
   - <the adjacent thing the next task does — so the implementer stops at the boundary>
   ```

6. **Self-check before handing off.** For each task, simulate a Haiku-grade
   implementer: reading ONLY that file + its wiki pages, is there any point where
   it must choose between two designs, invent a name/type/endpoint, or open an
   unnamed file? Each such point is a planning defect — fix the task, don't hope.
   Then check the seams: every Input names a Deliverable of an earlier task,
   verbatim.

## Execution handoff

Tasks are executed one at a time, in order, each by a fresh small-model session
running `skills/wiki-implement/SKILL.md` with the task file path as its assignment.
If an implementer reports BLOCKED, the fix belongs here: repair the task file
(or the plan), then re-dispatch — that a small model got blocked means the plan
was under-specified, not that the model failed.
