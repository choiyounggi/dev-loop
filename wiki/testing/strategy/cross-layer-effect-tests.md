---
id: testing-strategy-cross-layer-effect-tests
domain: testing
category: strategy
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/EveryInc/compound-engineering-plugin
last_verified: 2026-08-22
related: [testing-strategy-test-level-choice, testing-mocking-what-to-mock, testing-quality-write-path-assertions, testing-quality-minimum-case-set]
---

# Testing a Change Whose Execution Reaches Other Layers

## When this applies

About to mark a change tested when its tests exercise only the changed unit;
the changed path fires framework callbacks, middleware, event handlers,
enqueued jobs, or DB triggers; the change persists state in more than one step;
or more than one surface (API, CLI, job, admin UI) exposes the changed logic.

## Do this

Answer five questions before declaring the change tested; each question carries
its own action:

| Question | Action |
|----------|--------|
| What else fires when this runs? | Trace two levels outward from the change — callbacks, middleware, lifecycle hooks, DB triggers, enqueued jobs — and write the list down; the list is the test surface |
| Do the tests exercise the real chain? | Keep at least one test that runs the real collaborators through the integration seam ([testing-strategy-test-level-choice]); a chain where every collaborator is mocked verifies the mocks ([testing-mocking-what-to-mock]) |
| Can a failure leave orphaned state? | Add the partial-failure case: fail the later step and assert the earlier one rolled back or compensates ([testing-quality-write-path-assertions]) |
| Which sibling surfaces expose the same behavior? | Enumerate every surface that reaches the changed logic; cover each one, or route them all through one shared, tested path |
| Do error strategies align across layers? | Check that thrower and catcher agree on error type and contract — a layer catching by message string under a layer that changed its error class drifts silently |

Skip condition: when the change is a leaf node — nothing fires beyond it, no
multi-step state, a single surface — unit-level tests suffice; record that
reasoning in the PR so the reviewer sees a decision, not an omission.

## Edge cases

| Case | Then |
|------|------|
| The framework chain is implicit (ORM lifecycle hooks, global middleware) | Read the model's/app's registered hook list before concluding the trace is empty |
| The two-level trace reveals a fan-out too large to cover | Test first-level effects directly and pin the second level with one integration test through the production entry point |
| The fired effect is asynchronous (job, event) | Assert on the effect's own observable (job enqueued with expected args, event payload), then test the consumer separately at its level |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Declare done because the changed function's unit tests pass | Answer the five questions first | Unit tests cannot see cascade effects, orphaned state, or sibling-surface drift |
| Mock the whole chain "to keep the test fast" | Mock only the slow external boundary; keep one real-chain test | An all-mock chain stays green while the real wiring is broken |

## Sources

- https://github.com/EveryInc/compound-engineering-plugin — ce:work "System-Wide Test Check": trace two levels out, real-chain requirement, orphaned-state and interface-parity questions; field-tested in the plugin's shipped review workflow
