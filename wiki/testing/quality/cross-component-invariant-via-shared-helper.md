---
id: testing-quality-cross-component-invariant-via-shared-helper
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://pitest.org/quickstart/basic_concepts/
  - https://github.com/kenjudy/pdca-agentic-coding-framework/issues/181
last_verified: 2026-09-27
related: [testing-quality-tests-that-cannot-fail, testing-quality-behavior-not-implementation, testing-mocking-captured-call-arguments, testing-quality-path-resolver-fixtures-with-coincident-cwd, testing-data-harness-vs-run-path-fixtures]
---

# A Cross-Component Invariant Asserted by Calling the Same Helper Twice

## When this applies

A test claims that two components agree on a value — "the browser step runs in
the same worktree as the CLI step", "the CLI prints what the renderer
produces" — and builds both sides of the assertion by calling one shared
helper with the same arguments, instead of reading each side from what
production assembled or from what an executed process observed; or a review
found such an assertion green while the production wiring it names was
broken.

## Do this

1. **Mutate the wiring and require red.** Change one production call site so
   it no longer uses the helper (pass `None`, a different argument, a
   hard-coded value) and run the test. Green means the assertion compares the
   helper with itself; a pure function called twice with equal inputs agrees
   regardless of what production does.
2. **Take at least one side from an independent oracle.** Read the value from
   the object production built (the spawn command actually constructed, the
   config the service loaded) or from an observation the executed process
   reported (a child that writes `pwd -P` to a file, a response body, a
   database row) — not from a second call to the helper.
3. **Find the expected value in a production artifact too.** For "same
   worktree" claims the expected path is the worktree production created,
   read from its output, not `helper(args)` evaluated in the test.
4. **Check that the remaining assertions can discriminate.** A binary spawned
   by absolute path keeps its exit code and argv when the cwd is wrong; an
   assertion on those passes under the mutation from step 1. Add an
   observation that changes with the wiring.

| Component shape | Independent oracle |
|-----------------|--------------------|
| Two in-process objects built by production | Assert on fields of the built objects, captured through the seam production already exposes ([testing-mocking-captured-call-arguments]) |
| A spawned process | A fixture executable that records what it observed (`pwd -P`, its env, its argv) into a file the test reads |
| A caller/wrapper pair | Assert on the wrapper's output for an input whose result differs when the wrapper skips the callee |

## Edge cases

| Case | Then |
|------|------|
| The helper's own unit test also calls it twice | That is a different test with a different claim (the helper is deterministic); keep it, and add the wiring test above beside it |
| No child-observable artifact exists (the process writes nothing) | Inject a recording seam — a stub binary on a controlled `PATH`, or an argument spy on the spawn call — and assert its record |
| The two components are meant to diverge under some configuration | Assert equality only for the configurations where the invariant holds and assert the divergence explicitly for the others; a blanket equality assertion hides the second case |
| The mutation from step 1 is caught by a compile error rather than a test | Choose a mutation the type system accepts (`None` for an `Option`, the parent directory for a path) so the runtime assertion is what has to catch it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `assert_eq!(role_cli_cwd(a), role_cli_cwd(a))` for "both steps use the same cwd" | Compare the cwd the child reported against the worktree production created | Two calls of a pure function agree whether or not production calls it |
| Prove a cwd invariant with exit code and argv of an absolute-path spawn | Have the fixture record `pwd -P` and assert that | Exit code and argv do not change when only the cwd is wrong |

## Sources

- https://pitest.org/quickstart/basic_concepts/ — a mutant that "Survived" means "the mutation was not detected by the covering test"; the test that does not redden under the wiring mutation is exactly such a covering test
- https://github.com/kenjudy/pdca-agentic-coding-framework/issues/181 — a CLI test asserted `expect(cliOutput).toBe(applyBlock('', entries))` where `applyBlock` is the function the CLI calls; the recorded fix rule: "Oracle: where does the expected value come from, and is that source independent of the code under test? A literal, observable state (a file on disk, an HTTP response, a database row), or an external tool counts"
- Field evidence 2026-09 (an orchestration run's audit of `controller.rs`, task t3-browser-wiring; recorded by the originating session, not re-run in this flush): mutating the browser closure to `role_cli_cwd(None, ..)` left all 10 unit and integration tests green; after the fixture recorded `pwd -P` and the integration test compared it with the worktree production created, the same mutation went red with a path diff
