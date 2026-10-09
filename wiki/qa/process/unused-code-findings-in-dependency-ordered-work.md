---
id: qa-process-unused-code-findings-in-dependency-ordered-work
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://google.github.io/eng-practices/review/developer/small-cls.html
  - https://google.github.io/eng-practices/review/reviewer/looking-for.html
  - https://github.com/choiyounggi/dev-loop/pull/246
last_verified: 2026-10-06
related: [qa-process-evaluating-review-feedback, qa-process-adversarial-change-review, testing-quality-cross-task-stub-assertions]
---

# Unused-Code Review Findings on One Slice of Dependency-Ordered Work

## When this applies

You write or apply a review rule that flags new code as unnecessary — "zero call
sites", "every caller passes the same value", "an interface with one
implementation" — to one slice of work that lands in dependency order: one task
of a multi-task plan, or one change of a stacked PR/CL series, where a producer
slice adds a function, type, parameter, or config key that a later slice
consumes.

## Do this

1. **Look for a consumer slice before searching for callers.** Read the plan or
   the series (a later task's Inputs, the next change in the stack). When a later
   slice names the element, it is that slice's seam: record "consumed by
   <slice>" in the review and raise no finding.
2. **Require two or more call sites before "every caller passes the same value"
   counts as evidence.** With one call site the statement is true by
   construction. With fewer than two, defer that check to the review of the last
   slice that adds a caller, or to the whole-series review; for a single-slice
   change with one call site, the check does not apply.
3. **Raise the finding only when both hold**: no slice consumes the element, and
   a search shows the zero-caller or same-value condition. Put the search
   command and its hit count in the finding.
4. **Re-run the same checks once over the merged series** (integration review).
   A seam whose consumer slice was dropped or rewritten shows up there as a true
   zero-caller element.

## Edge cases

| Case | Then |
|------|------|
| The plan's decision table names the element and the reviewer disagrees with the decision | Report it as a plan-conformance dispute, not as unused code — the element is there by an explicit decision |
| The consumer slice was removed from the plan or the stack after the producer merged | Raise the finding at the whole-series review: delete the element, or re-plan the consumer |
| You receive an "unused" finding on a seam a later slice consumes | Reply with the consuming slice and its line in the plan; keep the element (widen [qa-process-evaluating-review-feedback] step 4's usage search from one slice to the whole series) |
| A single-slice change with no later slices | Steps 1 and 4 are empty; apply step 3 directly, with step 2's two-call-site rule deciding whether the same-value check applies |
| The series has no written plan or stack description | Ask the author which later slice consumes the element before ruling, and write the answer into the change description |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Flag a producer slice's new function because no caller exists yet | Check the later slices for a consumer first (step 1) | Dependency-first ordering ships producers before their callers by design; the finding fires on correct seams and its only "fix" breaks the next slice |
| Cite "the only caller passes X, so the parameter is unneeded" | Wait for two or more call sites (step 2) | One call site always passes one value, so the observation carries no information |

## Sources

- https://google.github.io/eng-practices/review/developer/small-cls.html — "Write one small CL, send it off for review, and then immediately start writing another CL based on the first CL"; "Consider creating shared code or stubs that help isolate changes between layers of the tech stack"; "inform both sets of reviewers about the other CL that you wrote, so that they have context for your changes"
- https://google.github.io/eng-practices/review/reviewer/looking-for.html — reviewers guard against over-engineering: "solve the problem they know needs to be solved now, not the problem that the developer speculates might need to be solved in the future" — the rule this page scopes to the series instead of the slice
- https://github.com/choiyounggi/dev-loop/pull/246 — field evidence 2026-10-06 (merged, public): an adversarial review of the orchestrate per-task "Excess" lens found that a zero-caller check would fire on every producer task under wiki-plan's producer-before-consumer ordering, and that "all callers pass the same value" holds trivially at one call site; the lens text now exempts elements a later task's Inputs consume and requires two or more call sites (`skills/orchestrate/SKILL.md` lens 6, covered by `tests/orchestrate-review-pass.bats`)
