---
name: loop-implement
description: Close a single implementation task with a methodology-grounded verification loop — define done, analyze, plan, write tests first (Red), implement (Green), run, self-review, get an independent test-quality audit, then judge against done; on failure reflect and retry (bounded). Use for one non-trivial task (feature, fix, behavior-changing refactor). Skip for typos, config values, simple renames.
---

# loop-implement — verification loop for a single task

Take one task and drive it to "done" through a closed loop whose steps are
grounded in established methodology (sources at the bottom). This is the worker
half of loop-orchestrator: an orchestrator session hands you one task; you
complete it here. It also works standalone for a single task.

## When to use
- Use: logic changes, new features, bug fixes, behavior-changing refactors.
- Skip: typos, config values, simple rename/import cleanup, one-line edits.

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

```
0. Define done       — write the acceptance criteria + done checklist FIRST,
                        so the loop has an explicit pass/fail target.        [DoD/XP]
1. Analyze           — understand the change; list the test scenarios it needs.
                        Consult `knowledge` + `tacit` if configured; use `explore`
                        to locate code/symbols. For a UI-facing task, read the
                        visual spec — the brief's `<design_spec>` if present, else
                        consult `design` (e.g. a Figma link) — and implement to it. [TDD step 1 / PDCA Plan]
2. Plan (wiki-plan)  — REQUIRED. Invoke the bundled `wiki-plan` skill to make
                        every design decision, each grounded in a `wiki/` page
                        (record the decision->page map), and to write the plan
                        as concrete values/code — never "as appropriate". This
                        step is not skippable for a non-trivial task and never
                        defers a decision to the implementing pass.              [PDCA Plan / wiki-plan]
3. Write tests (Red) — write the failing test(s) BEFORE the code. The test is
                        the spec and the verification oracle. If test-first is
                        impractical (e.g. exploratory UI), fix the acceptance
                        criteria / verification command before implementing.    [TDD test-first]
4. Implement (Green) — minimal code to make the tests pass.                     [TDD Green / PDCA Do]
5. Run tests (Check) — run new + existing tests; preserve failure output. Use the
                        `verify` role's command if configured (run only).        [PDCA Check / self-testing code]
6. Self-review + refactor — clean up; check bugs, edge cases, resource leaks,
                        input validation, unused code. Re-check against the
                        `tacit` role's danger zones if configured.               [TDD Refactor / self-review / Self-Refine]
6.5 Independent audit — REQUIRED: call the test-quality-auditor subagent with the
                        task brief, the diff, and the test paths. Do NOT grade
                        your own tests. (self-grading guard)
7. Judge against done — pass only if the done checklist is met AND the auditor
                        returns VERDICT: PASS.                                  [DoD / evaluator]
   - PASS  -> done.
   - FAIL  -> 7b.
7b. Reflect + retry  — state in words why it failed (what the auditor/tests
                        showed), then retry from step 3 with that reflection.
                        Bounded: at most 3 attempts. On the 3rd failure, STOP
                        and escalate with the last failure reason.              [Reflexion / bounded retry]
```

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

## Calling the auditor (step 6.5)

Use the Agent tool to run the `test-quality-auditor` subagent. Pass it: the task
brief, the change diff (`git diff`), and the test file path(s). It returns:

```
VERDICT: PASS | FAIL
REASONS: ...
```

- `VERDICT: PASS` -> proceed to step 7.
- `VERDICT: FAIL` -> address REASONS by strengthening the tests/code (never by
  weakening tests), increment the attempt count, and loop back to step 3.

This subagent is bundled with the plugin, so it is always available. Do NOT call
other agents by name (e.g. a code-reviewer) — they may not exist in the user's
environment. For optional exploration you may delegate to the core Agent tool
generically, without depending on a specific agent name.

## Guardrails (do not violate)
- Never weaken, delete, or skip tests to make them pass. Green must be honest.
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
