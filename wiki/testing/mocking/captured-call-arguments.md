---
id: testing-mocking-captured-call-arguments
domain: testing
category: mocking
applies_to: [general]
confidence: verified
sources:
  - https://docs.python.org/3/library/unittest.mock.html
  - https://jestjs.io/docs/expect
  - https://github.com/mockito/mockito/blob/main/mockito-core/src/main/java/org/mockito/ArgumentMatchers.java
  - https://pitest.org/quickstart/basic_concepts/
last_verified: 2026-08-10
related:
  [
    testing-mocking-what-to-mock,
    testing-quality-tests-that-cannot-fail,
    testing-quality-behavior-not-implementation,
    backend-common-change-impact-call-site-enumeration,
  ]
---

# Asserting a Wiring Call Through What the Stub Captured

## When this applies

A review, audit, or mutation run flagged one argument of one call — a port, a
host, a flag, an id passed at a constructor, factory, or server-startup site —
you fixed that argument, and you are writing the spy/stub test that holds the fix.
Also when such a test is green and a mutation of a *different* argument of the
same call survives, or when the fix was to extract the value into a resolver
function and you are choosing what the test asserts.

Deciding whether to stub this dependency at all →
[testing-mocking-what-to-mock].

## Do this

1. **Record the whole call, then assert every argument whose value the caller
   decides.** The defect this test exists to catch is "this call site passes the
   wrong value", and that defect has one instance per argument. Assert the full
   argument list in one assertion rather than reading one key out of a capture
   dict: `assert_called_with(host=…, port=…, tls=…)`,
   `toHaveBeenCalledWith(…)` — Jest's compares the arguments "with the same
   algorithm that `.toEqual` uses" — or Mockito's `verify(mock).f(eq(…), any(), …)`,
   whose rule is that "**all arguments** have to be provided by matchers".

2. **Diff the stub's signature against what it stores, and treat the difference
   as the unasserted part of the contract.** A stub written as
   `def runner(**kw): captured["port"] = kw["port"]` accepts `host` and `tls` and
   keeps neither, so no assertion can ever read them. Replace hand-rolled capture
   dicts with the framework's recorder (`Mock(spec=…)`, `jest.fn()`,
   `ArgumentCaptor`), which stores the call whole.

3. **Bind the stub to the real signature so positional and keyword forms are the
   same claim.** With a spec, unittest.mock "will introspect the specification
   object's signature when matching calls … regardless of whether they were
   passed positionally or by name", and autospec "will catch mistakes where the
   mock is called with the wrong signature". Without it, moving an argument from
   keyword to positional flips a passing assertion to failing with no behavior
   change.

4. **Separate the two claims a constant carries, and write one test for each:**

| Claim | Assert | What it catches |
|-------|--------|-----------------|
| The constant holds the right value | The constant, or the resolver's return, equals the expected value | An edit to the constant's own definition |
| The call site passes that constant on | The spy's recorded call carries the constant's current value (read the constant in the assertion, not a literal) | A call site that computes, hardcodes, or defaults the value instead of reading the constant |

5. **Prove each argument's assertion with its own mutation, and keep the other
   arguments intact.** Change that one argument at the call site and require the
   test to redden; a green run is the *survived* verdict — "the mutation was not
   detected by the covering test" — for that argument specifically
   ([testing-quality-tests-that-cannot-fail]).

6. **Re-run step 5 after extracting the value into a resolver.** Replacing
   `port=DEFAULT_PORT` with `port=resolve_port()` moves the gap rather than
   closing it: a wiring assertion that reads the constant stays green across the
   extraction and still reddens on a hardcoded value, while a test that only
   exercises `resolve_port()` says nothing about whether the caller calls it.

7. **Enumerate the other call sites of the same callee before finishing.** The
   spy proves one site; the sibling sites are a separate list
   ([backend-common-change-impact-call-site-enumeration]).

## Edge cases

| Case | Then |
|------|------|
| An argument is a large object or one the caller does not decide (a logger, a session) | Assert it with a placeholder matcher — `expect.anything()`, `any()`, `ANY` — so the argument stays named in the assertion while its value is out of scope; an omitted argument and a deliberately-unpinned one read the same in review otherwise |
| The argument is an options object and only some keys matter | Name the keys that matter and state the rest as out of scope in the test name: `expect.objectContaining` matches "a received object which contains properties that are present in the expected object", so the keys you omit are unasserted by construction |
| The call happens more than once (retry, per-item loop) | Assert the recorded call list, not the last call — `assert_called_with` "is a convenient way of asserting that the **last** call has been made in a particular way", so an extra later call with different arguments can satisfy it |
| The value is only reachable by editing source (a module-local constant with no injection seam) | Assert the wiring at the level that reads it — a startup/integration test that boots the component and reads back the effective value — since no unit-level substitution can vary it |
| The mutated argument has a default in the callee, so the mutation changes nothing observable | Classify it before strengthening the assertion: an argument whose two values behave identically at this level needs the assertion at the level where they diverge |
| The stub is a fake with behavior, not a recorder | Keep the recording separate from the behavior: a fake that computes a result and also stores its inputs tends to store only the inputs it computes from |
| The argument is a deployment-visible value (bind host, port, path) | Add one assertion at the level the platform reads it — a bind host mutated from `0.0.0.0` to `127.0.0.1` passes every in-process test and fails only a container's readiness probe |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Capture just the argument the review flagged (`captured["port"] = kw["port"]`) | Record the call whole and assert every caller-decided argument | Reproduced 2026-08-10: with only `port` captured, mutating `host` from `0.0.0.0` to `127.0.0.1` at the same call left the assertion green; `assert_called_with(host=…, port=…, tls=…)` reddened on it and stayed green on the unmutated call |
| Assert `DEFAULT_PORT == 8914` as the regression test for a call site that was passing the wrong port | Assert the spy's recorded argument equals `DEFAULT_PORT` | Reproduced 2026-08-10: the constant's own assertion stayed green while the caller passed a hardcoded `8770`; only the recorded-call assertion reddened |
| Call the gap closed once the value is extracted into `resolve_port()` | Assert that the caller's recorded argument matches the resolver's value | The extraction adds a second unasserted hop — the caller can bypass the resolver, and the resolver's own unit test cannot see that |
| Write the expected value as a literal in the assertion (`port=8914`) | Read the constant in the assertion (`port=DEFAULT_PORT`) | A literal makes the test fail on every legitimate change to the constant, which trains the next author to update the literal rather than to read the failure |
| Drop an argument from the assertion because its value is uninteresting | Keep it with a placeholder matcher | A dropped argument and an unpinned one are indistinguishable later; the placeholder records that the omission was a decision |
| Accept a green suite as proof the fixed argument is now guarded | Mutate that argument alone and require the owning test red | A test can be green because it never reads the argument; the red run is what distinguishes the two |

## Sources

- https://docs.python.org/3/library/unittest.mock.html — `assert_called_with` is "a convenient way of asserting that the last call has been made in a particular way" (whole-call, and last-call only); `call_args` exposes `.args`/`.kwargs` for the last call; a mock created with a *spec* "will introspect the specification object's signature when matching calls to the mock … regardless of whether they were passed positionally or by name", and "using autospec will catch mistakes where the mock is called with the wrong signature"
- https://jestjs.io/docs/expect — `.toHaveBeenCalledWith` checks arguments "with the same algorithm that `.toEqual` uses"; `expect.anything()` "matches anything but `null` or `undefined`" and is usable "inside `toEqual` or `toHaveBeenCalledWith` instead of a literal value"; `expect.objectContaining(object)` matches "a received object which contains properties that are present in the expected object" — a subset match, which is why omitted keys stay unasserted
- https://github.com/mockito/mockito/blob/main/mockito-core/src/main/java/org/mockito/ArgumentMatchers.java — "If you are using argument matchers, **all arguments** have to be provided by matchers", with `verify(mock).someMethod(anyInt(), anyString(), eq("third argument"))` shown as the correct form; the API's own rule is that a verified call is specified argument-complete
- https://pitest.org/quickstart/basic_concepts/ — "'Survived' means the mutation was not detected by the covering test"; step 5 reads a per-argument green run as this verdict for that argument
- Reproduction 2026-08-10 (Python 3, `unittest.mock`): a stub storing only `kw["port"]` reported `assertion_passes=True` both for the correct call and for one whose `host` was mutated `0.0.0.0` → `127.0.0.1`; a `Mock(spec=…)` with `assert_called_with(host=…, port=…, tls=…)` reported `True` for the correct call and `False` for the mutated one — the no-op control that shows the stronger assertion discriminates rather than always failing. A second run held `DEFAULT_PORT == 8914` green across three call-site variants (reads the constant, reads an extracted `resolve_port()`, hardcodes `8770`) while the recorded-call assertion was green for the first two and red only for the hardcoded one
- Field measurement 2026-08-10 (a Python service's startup wiring, 6-round audit): a `DEFAULT_PORT` value assertion left `main()`'s `port = resolve_port()` free — a `8770` mutation survived; after extracting the resolver, the same mutation survived again because no assertion said `main()` calls it; after adding the wiring assertion for `port`, the same call's `host` argument was still unasserted and `"0.0.0.0"` → `"127.0.0.1"` survived, a change whose only failure surface is a Kubernetes readiness probe. Each surviving mutant sat inside the previous round's own fix
