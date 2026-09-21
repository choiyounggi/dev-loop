---
id: testing-mocking-producer-wire-format-in-mocks
domain: testing
category: mocking
applies_to: [general]
confidence: verified
sources:
  - https://testing.googleblog.com/2020/07/testing-on-toilet-dont-mock-types-you.html
  - https://martinfowler.com/bliki/ContractTest.html
  - https://docs.pact.io/
  - https://github.com/choiyounggi/linkly-crew/pull/10
last_verified: 2026-09-06
related: [testing-mocking-what-to-mock, testing-quality-tests-that-cannot-fail, qa-process-completion-claims]
---

# A Mock That Fabricates an Identifier the Real Producer Formats Differently

## When this applies

Consumer-side logic (a UI store, a derived view, a matcher) keys on an
identifier another process produces — a correlation id, request id, run id —
and its tests run only against a mock that invents that id; a "covered" or
"matched" matrix is full in tests and empty in the real application; deciding
what the mock may assume about the id's shape.

## Do this

1. **Copy the id's wire shape from the producer's own tests, not from the
   consumer's reading of it.** Open the producer's test for the message that
   carries the id and lift the literal it asserts (`"corr-<id>"`, a prefixed
   UUID, a compound key) into the mock. A mock written from the consumer's
   assumption (`corr = task.id`) reproduces the assumption, and the test then
   verifies the assumption against itself.
2. **Treat the id as an opaque token in the consumer.** Build the mapping from
   the message that binds the token to its subject (an `assign`/`started`
   event carrying both) and look the token up in that map, rather than parsing
   the subject out of the token. A consumer that parses breaks the first time
   the producer changes its prefix; one that maps survives it.
3. **Add one test that feeds the consumer a producer-shaped fixture end to
   end** — the literal from step 1, through the binding message, to the derived
   view — and assert the derived matrix is non-empty. This is the assertion the
   mock-only suite could not make.
4. **When the producer is in the same repository, use its fixture rather than a
   hand-written one:** import or replay a recorded message from the producer's
   tests so the two sides cannot drift silently.

## Edge cases

| Case | Then |
|------|------|
| The producer has no test that pins the id's shape | Write one there first (it is the contract), then mirror it in the consumer mock — a shape pinned on one side only is not a contract |
| The id shape is documented and the docs disagree with the producer's code | The code that runs wins; pin the code's shape and file the docs mismatch |
| Several producers emit the same message with different id prefixes | Treat the prefix as data: the binding map is keyed on the full token, so no consumer branch needs to know which producer sent it |
| The verification runs are green three times and the real app still shows nothing | Stop re-running: the runs re-execute the same mock; one real-app probe (`covered 0/125`) is the evidence that reroutes the search to the fixture |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build the mock's correlation id as the bare task id because "that is what it means" | Lift the producer's literal and map through the binding message | The consumer's meaning is not the producer's format |
| Parse the task id out of the correlation id with a prefix strip | Map token → subject from the binding event | Parsing couples the consumer to a format the producer owns |
| Cite three green verification runs as proof the matrix fills | Probe the real app once and compare | Runs against the same mock repeat the same assumption |

## Sources

- https://testing.googleblog.com/2020/07/testing-on-toilet-dont-mock-types-you.html — "The assumptions built into mocks may get out of date as changes are made to the library, resulting in tests that pass even when the code under test has a bug"
- https://martinfowler.com/bliki/ContractTest.html — contract tests "check that all the calls against your test doubles return the same results as a call to the external service would"
- https://docs.pact.io/ — consumer-driven contracts: "The contract is generated during the execution of the automated consumer tests"
- https://github.com/choiyounggi/linkly-crew/pull/10 — field reproduction 2026-09-02 (Tauri app, `derive.ts:146/152` vs `dispatch.rs:266-268`): the frontend mock used the bare `task.id` as `corr` while the Rust producer emitted `corr-<id>`; the covered matrix stayed `0/125` in the real app through three green verification runs; mapping the opaque token via the assign message brought it to `25/25`
