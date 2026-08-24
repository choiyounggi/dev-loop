---
name: loop-implement
effort: high
argument-hint: "[task or feature to build]"
description: The single implementation loop. It plans via wiki-plan (step 2, required) into an ordered, wiki-navigated task list, then executes those tasks in order, each loading only its named wiki pages, writing tests first, getting an independent test-quality audit, and judging against done; on failure it reflects and retries (bounded). Use for a non-trivial task or feature. Skip typos, config values, and simple renames.
---

# loop-implement — the single implementation loop, driven by a wiki-plan

Drive work to "done" through a closed, methodology-grounded loop (sources at the
bottom). **This is dev-loop's one and only implementation skill** — it both plans
(via `wiki-plan`, step 2) and executes, so there is no separate executor. The
plan `wiki-plan` produces is not a loose sketch: it fixes an ordered task list
and, for each task, *navigates to the exact wiki pages that ground it* (the
decision→page map). This loop **consumes that plan directly** — executing the
tasks in the plan's order, loading exactly the wiki pages each task names, and
citing them — so every change traces back to a verified wiki page.

It works the same whether it runs standalone (you produce the plan here in step 2)
or as an orchestrated worker (the orchestrator hands you a task brief *and* the
plan it already produced, and you adopt and implement it here). Either path, one
loop.

## When to use
- Use: logic changes, new features, bug fixes, behavior-changing refactors.
- Skip: typos, config values, simple rename/import cleanup, one-line edits.

## Two entry modes (both run the SAME loop)
- **A plan already exists** (a `plans/<feature>/` from a prior `wiki-plan` run, or
  handed to you by the orchestrator): skip producing one — execute its tasks in
  the `## Task order` sequence, one at a time, each through steps 0 and 3–7 below,
  loading that task's named wiki pages.
- **No plan yet** (a fresh standalone task): step 2 runs `wiki-plan` first to
  produce the ordered, wiki-navigated plan, then you execute it the same way.

## The plan step is fixed (not pluggable)
Step 2 (Plan) is **hardwired to the bundled `wiki-plan` skill** and is
**mandatory** for every non-trivial task — it is not a pluggable role and cannot
resolve to inline planning. `wiki-plan` grounds each design decision in the
bundled `wiki/` semantic layers before any code is written, so the implementing
pass executes decisions instead of guessing them. See step 2 below.

## Tool profile (pluggable)
The *other* steps can use environment-specific tools through named **capability
roles**: `knowledge` (domain facts / policy / code values), `tacit` (past
incidents, edge cases, danger zones), `verify` (the project's test / build / QA
command), `explore` (code/symbol search), and `design` (visual/UI spec for a UI
task, e.g. a Figma link). (`plan` is intentionally absent — see above.) Resolve
them once at the start:

```
sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --summary
```

For each role: if a tool is configured, use it where the loop references that role
below; if it resolves to `default`, use the generic built-in behavior (your own
analysis). Configuration is optional and layered (per-user then per-repo) — with
nothing set, those steps run fully generic. The plan step is unaffected by this
config; it always runs `wiki-plan`. Schema, precedence, and examples:
`references/tool-profile.md`.

A role is a tool injected into one step — never a loop. Do NOT map a role (esp.
`verify`) to a tool that runs its own implement/verify/retry loop or another
orchestrator; that nests loops and muddies the retry/DoD/auditor ownership. There
is no `implement` role — step 4 below is the single owner of the implement cycle.

## The loop

Step 2 produces the plan once (or you were handed one). Steps 0 and 3–7 then run
**per task, in the plan's `## Task order`** — finish and judge one task before
starting the next, so a downstream task always builds on a verified upstream one.

```
2. Plan (wiki-plan)  — REQUIRED, once. If no plan exists, invoke `wiki-plan` to
                        make every design decision (each grounded in a `wiki/`
                        page — the decision->page map) and emit the ordered task
                        list, each task naming the exact wiki pages it needs. If a
                        plan exists, adopt it. Never defer a decision to execution. [PDCA Plan / wiki-plan]

   ── for each task, in Task order: ──
0. Define done       — from the task's Objective + Verify + the plan's Deliverables:
                        write this task's pass/fail checklist FIRST, as a gates
                        ledger file `.dev-loop/gates/<task-id>.md` (copy
                        `templates/gates.md`): each machine-checkable criterion
                        gets CHECK:/EXPECT:, manual ones EVIDENCE only.
                        (See "Gates ledger" below.)                             [DoD/XP]
1. Analyze + load refs— read THIS task's "Wiki pages (read these first, only
                        these)" — the pages `wiki-plan` navigated to — and load
                        exactly those from `${CLAUDE_PLUGIN_ROOT}/wiki/`, plus the
                        task's Inputs (confirm each exists; a missing Input is a
                        plan defect -> 7b, not a stand-in). List the test
                        scenarios. Consult `knowledge`/`tacit`/`explore` if
                        configured; for a UI task read the `<design_spec>`/`design`. [TDD step 1 / PDCA Plan]
3. Write tests (Red) — failing test(s) BEFORE code, from the task's Verify/Objective.
                        If test-first is impractical (exploratory UI), fix the
                        acceptance criteria / verify command first.             [TDD test-first]
4. Implement (Green) — minimal code to pass, executing the task under the
                        Execution contract below: apply the named pages' directive
                        rows as written, task D-number decisions win, stay inside
                        Deliverables, and do NOT improvise — a gap is a plan defect. [TDD Green / PDCA Do]
5. Run tests (Check) — run new + existing tests + the task's Verify command;
                        preserve failure output. Use the `verify` role if set.    [PDCA Check / self-testing code]
6. Self-review + refactor — bugs, edge cases, resource leaks, input validation,
                        unused code; re-check against the named pages' edge-case
                        rows and the `tacit` danger zones if configured.          [TDD Refactor / self-review]
6.5 Floor + independent audit — REQUIRED: run the test-floor.sh mechanical
                        pre-gate first; exit 3 is an immediate VERDICT: FAIL
                        (loop to step 3) without spending the auditor call.
                        Otherwise call the test-quality-auditor subagent with
                        the task brief, the diff, the test paths, and the
                        floor result. (self-grading guard)
7. Judge against done — PASS only if gate-check --run exits 0 on this task's
                        ledger (every gate MET with recorded evidence, or
                        visibly ABANDONED) AND the auditor returns VERDICT:
                        PASS. Emit the task report (format below, with the
                        WIKI: references you applied).                          [DoD / evaluator]
   - PASS  -> next task in Task order (back to step 0), until all tasks done.
   - FAIL  -> 7b.
7b. Reflect + retry  — say why it failed. If it is a PLAN defect (a decision/name/
                        input the task+pages+inputs never gave), repair the plan/
                        task via step 2, don't guess; else retry from step 3.
                        Bounded: ≤3 attempts per task; 3rd failure STOPs + escalates. [Reflexion / bounded retry]
```

## Execution contract (step 4 — absorbed from the wiki executor)

The plan already decided the design; your discipline is what makes the output
correct. While implementing a task:

1. **Read exactly what the task names, nothing else.** The task file (all
   sections), then every page under its "Wiki pages" — those are your
   best-practice instructions for this task — then every "Inputs" file. Where a
   task step and a wiki page both speak, the task's explicit **D-number decisions
   win**; the wiki fills in the *how*.
2. **Stay inside the box.** Touch only files named in Deliverables (creating
   parent dirs is fine). "Out of scope" is the next task's work — stop at the
   boundary even when finishing it looks easy. Use the exact names/paths/types/
   signatures the task spells out; they are seams other tasks depend on.
3. **No improvisation.** If a step needs something the task, its wiki pages, and
   its inputs do not give — a name, a type, a library choice, a behavior for an
   unlisted case — do NOT pick one. That is a planning defect: go to 7b and repair
   the plan/task via `wiki-plan`. A wrong guess costs more than a re-plan.
4. **Apply wiki directives as written.** A listed page's decision table → do your
   case's row. A listed edge case → the edge-case row overrides the general rule.
   No matching row → that's rule 3 (plan defect), not a guess.
5. **Cite what you applied.** The task report's `WIKI:` line names each page id
   and the row/directive you followed — this is the explicit reference back to the
   plan's decision→page map, so every change is traceable.

## Task report (step 7 output, per task)

```
STATUS: PASS | BLOCKED
TASK:   <NN-slug>
CHANGED: <each file created/modified, one per line>
TESTS:  <n cases; the Red->Green transition; auditor VERDICT>
VERIFY: <the task's Verify command → actual result>
GATES:  <met=N unmet=N abandoned=N from gate-check; EVERY abandonment listed
         as "id — reason" — a silently dropped gate is never allowed>
WIKI:   <page id applied → the row/directive followed, one line each>
NOTES:  <deviations (should be none); for BLOCKED: the exact missing decision/
         input, as a one-line question wiki-plan can answer>
```

A BLOCKED task is a plan defect: repair the task file / decisions via `wiki-plan`
(step 2) and re-run it. Never mark PASS with a failing or skipped Verify.

## Depth that keeps the loop to one pass

Most retry rounds are not bad luck — they are defects a deeper first pass would
have caught. These five practices sharpen steps 0–2 and 6 so problems surface
*now* instead of in a later retry (or in review). They need no external
tooling — just plain search and discipline — so they hold even when every
capability role resolves to `default`. (Trivial tasks skip this, per *Scale to
size* below.)

- **Pin the baseline (steps 0–1).** Fix the starting point: a clean
  `git status` and a noted HEAD. Anchor every "change here" reference by
  symbol/structure — "the `addChip()` body, before the push" — not by line
  number. A one-commit drift silently invalidates every line anchor.
- **Check spec conformance (step 1).** Before writing code, confirm the change
  *intent* matches its spec — the types it touches, the existing tests, and the
  stated requirement (use the `knowledge` role here if configured). Spec-vs-
  implementation mismatch is the single most common reason the judge fails;
  surface and resolve it before coding, not after.
- **Sweep adjacent defects (step 1, re-checked in step 6).** When you find the
  change site, treat it as the *first instance of a category*, not a lone fix.
  Deliberately search the same file, sibling files in the same module, and the
  consumers for the same pattern (defect clustering); the `explore` role helps
  if configured. Fold the in-scope hits into this task; list the rest
  explicitly as out-of-scope or follow-up. Skipping this is what makes a later
  round surface "the one you missed."
- **Attach evidence, not claims.** For each sweep, record the actual result —
  the search you ran, the hit count, and the locations (state 0 hits
  explicitly) — never just "checked." "Confirmed, 0 hits" and "didn't look"
  must be distinguishable.
- **Plan without judgment calls (step 2).** This is exactly what `wiki-plan`
  enforces: write decisions as concrete values or code, not vague directives.
  Replace "follow the existing pattern" / "handle appropriately" / "etc." with
  the actual pattern quoted and the actual branch written as if/else, each with
  its `wiki/` page as basis. The implementing pass should execute, not re-decide.

## Floor pre-gate + calling the auditor (step 6.5)

Before calling the auditor, run the mechanical floor pre-gate — it judges only
the countable half of test quality (tests exist, case counts, assertion
presence), never the semantic half:

```
sh ${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/test-floor.sh <cwd> <same diff range step 6's self-review used>
```

- exit 3 (stdout `fail`) -> treat as `VERDICT: FAIL` immediately: strengthen
  the tests (never weaken them), increment the attempt count, and loop back
  to step 3 — without spending the auditor subagent call.
- exit 0 (stdout `pass`) or exit 2 (stdout `unknown`) -> proceed to the auditor.

Use the Agent tool to run the `test-quality-auditor` subagent. Pass it: the task
brief, the change diff (`git diff`), the test file path(s), and the floor result
(`floor=pass` or `floor=unknown`). It returns:

```
VERDICT: PASS | FAIL
REASONS: ...
```

- `VERDICT: PASS` -> proceed to step 7.
- `VERDICT: FAIL` -> address REASONS by strengthening the tests/code (never by
  weakening tests), increment the attempt count, and loop back to step 3.

Floor passed != quality passed — the auditor still rules on semantic quality
even when the floor came back clean.

This subagent is bundled with the plugin, so it is always available. Do NOT call
other agents by name (e.g. a code-reviewer) — they may not exist in the user's
environment. For optional exploration you may delegate to the core Agent tool
generically, without depending on a specific agent name.

## Gates ledger (steps 0 and 7)

The done-checklist is not prose in context — it is a file the machine can
judge, so "done" survives long sessions and is never a self-report. At step 0
write `.dev-loop/gates/<task-id>.md` from `templates/gates.md`; at step 7 run:

```
sh ${CLAUDE_PLUGIN_ROOT}/skills/loop-implement/scripts/gate-check.sh --run .dev-loop/gates/<task-id>.md
```

- The checker executes each runnable gate's `CHECK:` itself; a gate is MET
  only on exit 0 AND the `EXPECT:` token in the output. It flips the box and
  records the evidence — never tick a runnable gate by hand.
- A checked box whose `EVIDENCE:` still reads `pending` is CLAIMED — a
  done-claim without proof, treated as worse than unchecked.
- An impossible gate is abandoned in the open (`ABANDON: <id> <reason>`),
  never deleted; every abandonment appears on the report's `GATES:` line.
- The plugin's Stop hook (loop-gate) parses these ledgers — without executing
  commands — and blocks the session from ending while gates are UNMET or
  CLAIMED (bounded: it releases after 6 stops with no ledger progress). So a
  session cannot quietly end on an unproven "done".
- Keep `.dev-loop/` out of version control (it is workspace state, like
  `.orchestration/`); add it to the project's `.gitignore` once.

## Guardrails (do not violate)
- Never weaken, delete, or skip tests to make them pass. Green must be honest.
- Never tick a runnable gate by hand or hand-write its EVIDENCE — only
  gate-check.sh --run records proof. Ledger green must be honest too.
- Bounded retry: at most 3 attempts; then stop and escalate the real failure.
- "I don't know" / "unverified" never counts as pass — stop and report.
- Scale to size: trivial tasks (typos, config values, simple renames) are out of
  scope for this skill entirely — see "When to use". Every task that *does* run
  the loop runs step 2 (wiki-plan); the plan step is never skipped.

## Sources
TDD Red-Green-Refactor / test-first (Kent Beck, *Canon TDD* / *TDD by Example*;
Fowler, Self-Testing Code); PDCA/PDSA (Shewhart/Deming); self-review and "improve
the codebase" review bar (Google eng-practices); Definition of Done (Scrum Guide)
+ acceptance criteria (XP); self-verification loops (Self-Refine, Reflexion;
Anthropic, *Building Effective Agents* evaluator-optimizer); bounded retry
(resilience patterns — bounded, with escalation); defect clustering / "the
adjacent defect" (Beizer, *Software Testing Techniques*) — defects group, so a
found one warrants sweeping its neighbors.
