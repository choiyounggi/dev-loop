---
id: testing-async-async-testing
domain: testing
category: async
applies_to: [general]
confidence: verified
sources:
  - https://jestjs.io/docs/asynchronous
  - https://jestjs.io/docs/timer-mocks
  - https://jestjs.io/docs/expect
  - https://testing-library.com/docs/dom-testing-library/api-async/
  - https://martinfowler.com/articles/nonDeterminism.html
last_verified: 2026-07-10
related: [testing-quality-tests-that-cannot-fail, testing-flaky-diagnosing-flaky-tests, testing-data-test-data-and-isolation]
---

# Testing Asynchronous Code Deterministically

## When this applies

You are testing async code — promises, timers, retries, debounce, event-driven
flows; a test passes but the runner warns about assertions after completion or
un-awaited promises; or an async test intermittently interferes with the next test.

## Do this

1. **Root rule: the test must not finish before the work and its assertions
   do.** Return or await every promise created in the test body. A test that
   completes while work is pending passes vacuously ([testing-quality-tests-that-cannot-fail])
   and leaks that work into the next test.
2. Pick the pattern by the async shape:

| Async shape | Do |
|-------------|-----|
| Promise result | `await` it, then assert on the resolved value |
| Expected rejection | `await expect(promise).rejects.toThrow(ErrorType)`-style assertion — a `try/catch` with a loose assert in the catch passes when nothing throws ([testing-quality-tests-that-cannot-fail]) |
| Code driven by `setTimeout`/`setInterval`/debounce/retry backoff | Enable fake timers and advance time explicitly (`advanceTimersByTime(ms)`) to the exact instant; real sleeps are slow and race under load ([testing-flaky-diagnosing-flaky-tests] sleep row) |
| UI or state that appears asynchronously | Poll the **condition** with a bounded-timeout wait (`waitFor`/`findBy`-style) and assert the final state; the test proceeds the moment the condition holds |
| Event-emitter / callback API | Wrap the event in a promise (`once`-style helper) and `await` it, then assert |
| Fire-and-forget side effect | Expose a completion handle (returned promise, flush/drain hook) and await it in the test; when no handle can exist, poll the durable outcome (row above) |

3. **Contain leaked work.** A promise or timer that outlives its test corrupts
   the next test's state and assertions. In each test's teardown, unsubscribe
   listeners and cancel in-flight work the test started; where the framework
   supports it, assert there are no pending timers or open handles (e.g. fail
   teardown when `jest.getTimerCount() > 0`). Suite-level isolation rules →
   [testing-data-test-data-and-isolation].
4. **Fake-timer hygiene.** Faking time freezes every timer in the process,
   including timeout-based internals of libraries the test does not control
   (HTTP client timeouts, a wait utility's own polling). Enable fake timers
   only in tests that advance them, and restore real timers in that test's
   teardown (`useRealTimers` in `afterEach`).

## Edge cases

| Case | Then |
|------|------|
| Testing a debounce/throttle interval | Advance to just before the interval and assert nothing fired, then advance past it and assert it fired — both sides of the boundary |
| A condition wait (`waitFor`) is needed while fake timers are active | Advance the fake clock explicitly before/while awaiting the condition, or use the wait utility's fake-timer-aware mode; otherwise the poll's own timers never fire |
| Runner reports an unhandled rejection after the suite passes | A promise was created without `await`/`return` — find it and await it; do not silence the warning |
| Assertions run inside a `.then`/callback the test never awaits | Add `expect.assertions(n)` / `expect.hasAssertions()` so the test fails when the callback is skipped, then restructure to await-then-assert |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `await sleep(500)` before asserting | Fake timers with explicit advance, or a bounded condition wait | A fixed sleep is too slow on every run and too short under load; the race remains |
| Assert inside `.then()` without returning the promise | `await` the promise, then assert on the main path | The test finishes before the callback runs; it passes with zero assertions executed |
| Catch an expected rejection with `try/catch` and assert loosely in the catch | `await expect(...).rejects.toThrow(...)`-style API | The catch-block assert never runs when the code succeeds, and the test still passes |
| Enable fake timers globally for the whole suite | Enable per test/suite that advances them; restore real timers in teardown | Frozen time deadlocks unrelated tests' timeouts, polling waits, and library internals |

## Sources

- https://jestjs.io/docs/asynchronous — return/await every promise or the test finishes first; `.rejects` for rejections
- https://jestjs.io/docs/timer-mocks — `useFakeTimers`, `advanceTimersByTime`, `useRealTimers`; selective faking for APIs that must stay real
- https://jestjs.io/docs/expect — `expect.assertions` / `expect.hasAssertions` verify callback assertions ran
- https://testing-library.com/docs/dom-testing-library/api-async/ — `waitFor`/`findBy`: polling on a condition with interval and bounded timeout
- https://martinfowler.com/articles/nonDeterminism.html — poll/callback on the completion condition instead of bare sleeps
