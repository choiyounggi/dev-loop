---
id: testing-mocking-wrapper-label-pinned-by-a-boundary-fault
domain: testing
category: mocking
applies_to: [general, vitest]
confidence: verified
sources:
  - https://vitest.dev/api/vi
  - https://vitest.dev/guide/mocking/modules
  - https://pitest.org/quickstart/basic_concepts/
last_verified: 2026-10-15
related:
  [
    testing-mocking-what-to-mock,
    testing-mocking-captured-call-arguments,
    testing-quality-tests-that-cannot-fail,
    testing-quality-surviving-mutant-equivalence-triage,
  ]
---

# A Wrapper's Own Error Label Pinned by a Fault Injected at Its Boundary

## When this applies

A wrapper turns errors from a lower layer into fixed log lines (or messages,
metrics), and for the lower layer's own typed fault it forwards the message that
layer built, while for any other error it prints its own label (an operation
name, an action id). The suite injects faults only at the lower layer (a fake
repository that throws `DatabaseFaultError`, a fault flag in the store), so a
renamed wrapper label leaves every fault test green. Also when choosing how to
inject one rejection at a module boundary under Vitest while the rest of the
file keeps the real module.

## Do this

1. **Classify each line the wrapper writes by who built its text.** The lower
   layer's typed fault always takes the forwarding branch, so its tests can only
   prove the forwarding:

| The line's text comes from | A lower-layer fault test proves | To pin the wrapper's label |
|----------------------------|----------------------------------|----------------------------|
| The lower layer's error message (`err.message` of its typed fault) | The forwarding | Nothing more — the label is not in this line |
| The wrapper's own constant, written for an error that is not the typed fault | Nothing — that branch never runs | Inject a generic error at the wrapper's boundary (step 2) |

2. **Inject the generic fault at the boundary the wrapper calls and keep every
   other call real.** Under Vitest, put `vi.mock("./lower", { spy: true })` at
   the top of the file: the module is automocked but each export keeps its
   original implementation, so the file's other tests still run the real lower
   layer. In the one test that pins the label, call
   `vi.mocked(lower.fn).mockRejectedValueOnce(new Error("boom"))` and assert the
   whole log line: the wrapper's label plus `boom`. When the lower layer reaches
   the wrapper through an injected dependency rather than an import, pass a fake
   whose one call rejects instead ([testing-mocking-what-to-mock]).

3. **Reset the override on the autospied function itself.** Call
   `vi.mocked(lower.fn).mockReset()` in `beforeEach`; it empties the call record
   and puts the real implementation back. `vi.restoreAllMocks()` acts on spies
   created with `vi.spyOn` and leaves a mock created by automocking untouched —
   a persistent `mockRejectedValue` set in one test survives it into the next.

4. **Prove the test by the rename mutant.** Change the wrapper's label constant
   and require exactly this test to redden while the lower-layer fault tests
   stay green; a green run is the *survived* verdict for the label
   ([testing-quality-tests-that-cannot-fail]). A surviving rename after this
   test exists means the assertion reads the lower layer's message, not the
   wrapper's line — re-read step 1's table.

## Edge cases

| Case | Then |
|------|------|
| The wrapper rethrows after logging | Assert the rejection as well (`await expect(run()).rejects.toThrow(...)`), so a wrapper that swallows the error reddens too |
| Several wrappers share one lower layer and each has its own label | Write one boundary-fault test per wrapper; a rename of each label must redden its own test — one mutation per assertion, not one per file |
| The label also reaches a metric name or a second log line | Pin each line with its own assertion from the same injected fault; the first line's assertion says nothing about the second |
| The override was `mockRejectedValue` (persistent) and a later test expects the real call | `vi.restoreAllMocks()` leaves it in place on an autospied export; call `mockReset()` on that spy (step 3) |
| The project runs Jest or another runner without a `spy` module-mock option | Use the runner's own spy-on-export seam where the module shape allows it, or move the lower layer behind an injected dependency and pass a fake whose one call rejects |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add more lower-layer fault cases to cover the wrapper's own label | Inject one generic error at the wrapper's boundary | The typed fault always takes the forwarding branch; the label never reaches the log from that path |
| Replace the lower module with a factory mock for the whole file | `vi.mock(path, { spy: true })` plus one `mockRejectedValueOnce` | The other tests keep exercising the real lower layer, and the one override is scoped to one call |
| Clean up the autospy with `vi.restoreAllMocks()` in `beforeEach` | `vi.mocked(lower.fn).mockReset()` | `restoreAllMocks` targets `vi.spyOn` spies and leaves automock-created mocks as they are; the persistent override leaks into the next test |

## Sources

- https://vitest.dev/api/vi — `vi.mock(path, { spy: true })`: with `spy: true` Vitest automocks the module but does not override the implementation of its exports (available since Vitest 2.1); `vi.restoreAllMocks` restores the original implementations of spies created with `vi.spyOn` and does not affect mocks created during automocking (page wording as retrieved 2026-10-15; the Vitest 5.0.3 bundled type comment on `restoreAllMocks` still reads "every mocked function", which the reproduction below contradicts for automock spies)
- https://vitest.dev/guide/mocking/modules — the `spy` option spies on every export of the module without replacing them with fakes
- https://pitest.org/quickstart/basic_concepts/ — "Survived: The mutation was not detected by the covering test"; step 4 reads a green run under the rename as this verdict for the label
- Local reproduction 2026-10-15 (Vitest 5.0.3, Node, scratch directory deleted after the run; `lower.ts` with a typed `LowerFault`, `wrapper.ts` that forwards `LowerFault.message` and otherwise prints `wrapper-op[createInvite]`, `vi.mock("./lower", { spy: true })`): the typed fault logged only `lower-op[faulty] failed`; the spied export still returned the real value and recorded the call; `mockRejectedValueOnce(new Error("boom"))` logged `fault: wrapper-op[createInvite] boom`; after `mockRejectedValue(new Error("sticky"))` + `vi.restoreAllMocks()` the next real call still logged `… sticky`; after `mockRejectedValue(...)` + `mockReset()` the next call ran the real implementation (empty log). 5/5 tests passed
- Field evidence 2026-10-15 (linkly-invitation task t4e, `runAdminWrite` logging `DatabaseFaultError.message`; recorded by the originating session, not re-run in this flush): renaming both action operation labels kept 8/8 tests green with faults injected only at the database layer; after the autospy rejection test was added, rename mutants 46d and 46e reddened
