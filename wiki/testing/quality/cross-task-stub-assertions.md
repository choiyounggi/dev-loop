---
id: testing-quality-cross-task-stub-assertions
domain: testing
category: quality
applies_to: [general]
confidence: field-tested
sources:
  - "Field evidence, a Rust + React orchestrated repo (commit de8c07c and its HANDOFF.md §5 item 18), verified by direct git show / read against the checkout 2026-09-08"
last_verified: 2026-09-08
related: [testing-quality-tests-that-cannot-fail, testing-quality-behavior-not-implementation, infrastructure-agent-orchestration-worktree-isolated-workers]
---

# A Test Asserting a Cross-Task Stub's Wording Instead of Its Structural Contract

## When this applies

In a multi-task (orchestrated or sequenced) run, one task lands a placeholder
or stub view or component (a shell task's UI, a scaffolded module) and its
test asserts the stub's literal content — placeholder text, a specific string
— while a different, later task is planned to replace that stub's content with
the real implementation.

## Do this

1. **Identify what the plan/contract states is stable across the stub-to-real
   transition** — a root DOM class, a component's exported type, a function's
   signature — and assert that instead of the stub's wording.
2. **When no such stable contract is written down yet, add it to the
   plan/contract document before writing the test**: state which element
   (class name, id, exported symbol) the replacing task is required to
   preserve, so the assertion has a named target instead of an implicit
   assumption about what will still be true after the swap.
3. **Route the test through the same selector the consuming code or other
   tests already use** to find the element (a `data-testid` or root class
   already used for tab-switching/routing logic), so the assertion tracks the
   same seam production code depends on rather than an independent guess.

## Edge cases

| Case | Then |
|------|------|
| The stub has no stable structural element yet (a bare text node, no wrapping container) | Add one (a root class/id) as part of landing the stub, specifically so downstream tests and the replacing task have a contract to target |
| The replacing task is not yet planned or known | Assert structure rather than wording for any content the plan flags as provisional — an unplanned replacement breaks a wording assertion just as surely as a planned one |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert a stub's placeholder text (`expect(screen.getByText("DAG view coming soon"))`) | Assert its root class or structural contract (`container.querySelector("section.dag-view")`) | The follow-up task that replaces the stub's content necessarily changes the wording; only the structural contract is what the plan guarantees stays stable |

## Sources

- Field evidence (a Rust + React orchestrated repo, commit `de8c07c` "assert stub root class instead of placeholder text in App.test.tsx", verified by `git show` against the checkout 2026-09-08): the tab-switch tests originally asserted the stubs' placeholder text; per the plan's §D4/D5 amendment establishing `section.dag-view`/`section.timeline-view` as the stable root across implementations, they were rewritten to `container.querySelector(...)` on those roots, so the later tasks that replaced the stub content did not break the integration seam
- Same repo, HANDOFF.md §5 item 18 (verified by direct read): records "a shell task's test asserting stub wording breaks at the follow-up replacement; assert cross-task stubs by root class / structural contract, not wording" as a standing pitfall for orchestrated runs
