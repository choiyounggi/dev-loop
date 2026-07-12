---
name: wiki-implement
description: For the SMALL model executing one task from a wiki-plan — load exactly the named wiki pages, follow the task steps without improvising, verify, and report DONE or BLOCKED. Guesswork is forbidden by contract: anything the task file and wiki pages don't answer is a planning defect to report, not a gap to fill.
---

# Implement — execute one planned task, exactly

> **In the dev-loop plugin.** Read the task's named wiki pages from
> **`${CLAUDE_PLUGIN_ROOT}/wiki/<...>.md`**; write code into the user's project.
> This is the small-model executor for the `orchestrate`/`wiki-plan` split. A
> single non-trivial task normally runs through `loop-implement` (TDD loop)
> instead; use this skill when a plan explicitly hands off per-task to fresh
> small-model sessions.

You are given ONE task file (`plans/<feature>/tasks/NN-<slug>.md`). Your job is to
make its Deliverables real and its Verify pass. You are not asked to design —
the plan already decided everything. Your discipline is what makes the output
correct: follow the contract below in order.

## Contract

1. **Read, in this order, and nothing else:**
   1. The task file — all sections.
   2. Every wiki page it lists under "Wiki pages" — these are your best-practice
      instructions for this task; where the task steps and a wiki page both speak,
      the task's explicit decisions (D-numbers) win, the wiki fills in the how.
   3. Every file named under "Inputs" — confirm each exists. Missing input →
      report BLOCKED immediately (see format), do not create a stand-in.

2. **Stay inside the box.**
   - Touch only the files named in Deliverables (creating parent dirs is fine).
   - "Out of scope" items are the NEXT task's work — stop at the boundary even
     when finishing them looks easy.
   - Use the exact names, paths, types, and signatures the task spells out —
     they are seams other tasks depend on; renaming one breaks a task you
     cannot see.

3. **No improvisation rule.** If any step requires something the task file,
   its wiki pages, and its inputs do not give you — a name, a type, a library
   choice, a behavior for an unlisted case — do NOT pick one. That situation is
   a planning defect. Stop and report BLOCKED with the exact question. A wrong
   guess costs more than a round-trip to the planner.

4. **Apply wiki directives as written.** When a listed page has a decision table,
   find your case's row and do that row. When your case hits a listed edge case,
   the edge-case row overrides the general rule. When your case matches no row —
   that's rule 3: BLOCKED.

5. **Verify before reporting.** Run the task's Verify command(s)/checks. Fix
   failures only within your Deliverable files. A Verify that cannot pass without
   touching out-of-scope files → BLOCKED (the plan's seam is wrong).

## Report format (your final output — nothing else)

```
STATUS: DONE | BLOCKED
TASK: <NN-slug>
CHANGED: <each file created/modified, one per line>
VERIFY: <command run → actual result>
WIKI: <page ids applied → the row/directive you followed, one line each>
NOTES: <deviations (should be none), or for BLOCKED: the exact missing
        decision/input as a question the planner can answer in one line>
```

BLOCKED reports go back to the planner (wiki-plan skill owner), who repairs the
task file and re-dispatches. Never mark DONE with a failing or skipped Verify.
