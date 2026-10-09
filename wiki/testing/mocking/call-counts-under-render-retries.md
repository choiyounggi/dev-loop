---
id: testing-mocking-call-counts-under-render-retries
domain: testing
category: mocking
applies_to: [react, testing-library, nextjs]
confidence: verified
sources:
  - https://github.com/facebook/react/blob/v19.3.0/packages/react-reconciler/src/ReactFiberWorkLoop.js
  - https://github.com/facebook/react/blob/v19.3.0/packages/react/src/ReactAct.js
  - https://github.com/testing-library/react-testing-library/issues/1291
  - https://react.dev/reference/rules/rules-of-hooks
  - "Local reproduction 2026-10-08 (react/react-dom 19.3.0, @testing-library/react 16.3.3, jsdom 30.1.2, plain Node and Vitest 5.0.3): call counts per render in sequence, thrown error, hook and async limits"
  - "Field case 2026-10-07 (Next.js page test, React 19.3, Vitest 5.0.3 jsdom): mocked notFound() called 3 times by one render()"
last_verified: 2026-10-08
related: [testing-quality-behavior-not-implementation, testing-mocking-what-to-mock]
---

# Counting Calls Made by a Component That Throws While Rendering

## When this applies

A test renders a React component (`createRoot`, Testing Library `render()`)
whose render throws — a Next.js page whose guard calls a mocked `notFound()` or
`redirect()` that throws, an error-boundary test — and asserts how many times
the guard, a spy, or another side effect inside the render ran
(`toHaveBeenCalledTimes(1)`).

## Do this

1. **Count on a path React does not retry.** After a render-phase error,
   React renders the root again synchronously (`recoverFromConcurrentError` →
   `renderRootSync`) before `act()` rethrows the error; the cause of the extra
   pass on the first render was not isolated. So
   one `render()` runs the component body several times: with Testing Library
   16.3.3 on React 19.3.0, 3 times on the first `render()` in a process and
   twice on each later one; a React 18.2 report saw 4. Pick the assertion by
   the component's shape:

| Component | Assert |
|-----------|--------|
| Calls the guard before any hook (a server component page, a guard on its first line) | Call it directly: `expect(() => Page(props)).toThrow('NEXT_NOT_FOUND')`, then `expect(guard).toHaveBeenCalledTimes(1)` |
| `async` (a server component) | `await expect(Page(props)).rejects.toThrow('NEXT_NOT_FOUND')`, then `toHaveBeenCalledTimes(1)` |
| Calls a hook before the guard | Stay with `render()` and assert the guard's arguments (`toHaveBeenCalledWith(...)`) and the throw, leaving the count unpinned. A direct call fails with "Invalid hook call" before the guard runs |

2. **Assert the render outcome in its own test.**
   `expect(() => render(<Page />)).toThrow('NEXT_NOT_FOUND')`, then assert that
   `document.body` holds none of the page's content. `render()` throws before
   it returns `container`, so read `document.body`.

3. **Match the thrown error by message or by one shared instance.** When the
   mock creates a new `Error` per call, `render()` rethrows the error from the
   last pass, so an identity check against the first call's error fails.

## Edge cases

| Case | Then |
|------|------|
| The mock throws one shared error object (`const err = new Error('NEXT_NOT_FOUND'); notFound.mockImplementation(() => { throw err })`) | `toThrow(err)` and an identity check both hold; every pass throws the same instance |
| The test only needs "the guard ran" | `toHaveBeenCalled()` holds on every path; it is the count that varies |
| A pinned count through `render()` passes when its test runs alone and fails in the full file, or the reverse | The first render in a process runs one extra pass (3, then 2, 2, …), so the count depends on test order; move the count to the direct call (step 1) |
| A React or Testing Library upgrade changes the number of passes | Assertions built as in step 1 do not move; a pinned count through `render()` is what breaks |
| The page is a client component that must call hooks first and the count matters | Extract the guard decision into a plain function, unit-test its call count there, and keep the render test to step 2 |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `expect(notFound).toHaveBeenCalledTimes(1)` after `render(<Page />)` | Call `Page(props)` directly for the count; keep `render()` for the throw and the empty DOM | React re-runs a throwing render, so the count through `render()` is 2-4 depending on version, harness and test order |
| Loosen the assertion to "at least once" to make it pass | Move the count to the direct call (step 1) | "At least once" cannot catch code under test that calls the guard twice |

## Sources

- https://github.com/facebook/react/blob/v19.3.0/packages/react-reconciler/src/ReactFiberWorkLoop.js — `exitStatus = recoverFromConcurrentError(` (line 1268); `function recoverFromConcurrentError(` runs `const exitStatus = renderRootSync(root, errorRetryLanes, false);` (line 1357); "The root errored yet again. Proceed to commit the tree." (line 1285)
- https://github.com/facebook/react/blob/v19.3.0/packages/react/src/ReactAct.js — after a synchronous callback, `act()` runs `flushActQueue(queue)` (line 187), where the queued render throws, then `if (ReactSharedInternals.thrownErrors.length > 0) {` … `const thrownError = aggregateErrors(ReactSharedInternals.thrownErrors);` … `throw thrownError;` (lines 228-232): `act()` rethrows the render error, so `render()` throws. Lines 94-101 are the same rethrow for an error the callback itself throws
- https://github.com/testing-library/react-testing-library/issues/1291 — "Calling render on a component that throws, results in 4 renders" (React 18.2, open)
- https://react.dev/reference/rules/rules-of-hooks — "Don't call Hooks from regular JavaScript functions"; hooks run only inside React function components and custom hooks
- Installed react-dom 19.3.0 `cjs/react-dom-client.development.js:10026` — "There was an error during concurrent rendering but React was able to recover by instead synchronously rendering the entire root."
- Local reproduction 2026-10-08 (react/react-dom 19.3.0, @testing-library/react 16.3.3, jsdom 30.1.2; plain Node and Vitest 5.0.3 jsdom): five sequential `render()` calls of a page whose first statement calls a throwing guard ran the guard `[3,2,2,2,2]` times in both runners; a direct call ran it once; every path threw the guard's error and `document.body` held no page content. With a new `Error` per call, `render()` threw the last one created (a plain `Error`, not an `AggregateError`). A component calling `useState` before the guard never reached the guard: Vitest threw `Error: Invalid hook call…`, plain Node logged that message and threw `TypeError: Cannot read properties of null (reading 'useState')`. An `async` page returned a Promise rejected with the guard's error after one call. Under Vitest, the step-1 and step-2 assertions passed and `toHaveBeenCalledTimes(1)` after `render()` failed
- Field case 2026-10-07 (a Next.js page test, React 19.3, Vitest 5.0.3 jsdom): one `render(<Page />)` invoked the mocked `notFound()` 3 times; `Page()` called directly invoked it once
