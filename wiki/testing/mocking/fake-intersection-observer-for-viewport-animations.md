---
id: testing-mocking-fake-intersection-observer-for-viewport-animations
domain: testing
category: mocking
applies_to: [general, react]
confidence: verified
sources:
  - framer-motion 13.2.0 `dist/es/motion/features/viewport/observers.mjs` (read 2026-09-28) — `observers` WeakMap keyed by root then `JSON.stringify(options)`; `fireObserverCallback` reads `observerCallbacks.get(entry.target)`; `observeIntersection` calls `observer.observe(element)` per element
  - https://developer.mozilla.org/en-US/docs/Web/API/IntersectionObserverEntry/target
  - https://developer.mozilla.org/en-US/docs/Web/API/IntersectionObserver/observe
  - https://vitest.dev/api/vi.html
last_verified: 2026-09-28
related: [testing-quality-tests-that-cannot-fail, testing-mocking-what-to-mock, testing-async-async-testing, frontend-data-fetching-infinite-scroll, testing-quality-alias-table-contract-tests]
---

# A Fake IntersectionObserver Under a Viewport-Triggered Animation Library

## When this applies

Unit-testing in jsdom (vitest/jest) a component whose entrance animation starts
on viewport entry through a library that wraps `IntersectionObserver` — motion /
framer-motion `whileInView` + `viewport`, or any wrapper that keeps its own
observer registry — with `IntersectionObserver` replaced by a fake class, and
you want to assert "this element registered a viewport trigger" or "the
entrance animation ran with these timing props (stagger, delay, duration)".

## Do this

1. **Count `observe(element)` calls, not constructor calls, and assert the
   observed node's identity (`toBe(node)`).** The wrapper caches one observer
   per `(root, serialised options)` pair in a module-level `WeakMap`, so the
   constructor runs once per module lifetime: from the second test in a file it
   is called 0 times, and a constructor probe fails on a correct implementation.
   `observe` is called once per registered element, so an element count is
   immune to the cache and to test order.
2. **Record `observe()` calls in a file-level list that `beforeEach` clears,
   not in per-instance fields.** The instance the wrapper cached in the first
   test is the one every later `observe()` reaches — a fresh fake class stubbed
   per test is never constructed again.
3. **Give the fake entry a `target`:** `this.cb([{ isIntersecting: true,
   target }], this)`. The wrapper resolves the per-element callback by
   `entry.target`; an entry without it makes the lookup return `undefined`, the
   callback becomes a silent no-op, and the animation never starts — while the
   first-paint styles (`opacity: 0`, `translateY(16px)`) still match, so the
   suite stays green.
4. **Pair every timing assertion with a positive control** that waits for the
   element to reach its visible end state (`opacity: 1`) — a suite whose
   animation never fired is green for every mutation of the transition props.
5. **Mutation-check the prop plumbing once:** hardcode the defaults in place of
   `staggerChildren` / `delayChildren` / `duration` and require red
   ([testing-quality-tests-that-cannot-fail]). Record the red output in the
   task report.

| You want to prove | Assert |
|-------------------|--------|
| The element registered a viewport trigger | `observe` was called with exactly that node (count and identity) |
| The entrance animation ran | The awaited end-state style, after firing the entry with `target` |
| Stagger/delay reach the transition | A timing difference between siblings after entry, plus the mutation from step 5 turning red |

## Edge cases

| Case | Then |
|------|------|
| The constructor count is 0 in every test after the first | That is the cache, not a defect; move to `observe` counting (step 1) |
| Items with their own `whileInView` are a bug you want to catch | The element count exposes it (`expected [Array(4)] to have a length of 1 but got 4` on a mutant that gave each item its own trigger) |
| Timing tests run in ~1 ms and pass | The animation never fired; check the fake entry for `target` — a real run takes about the animation's duration (1 ms → 1018 ms after the fix) |
| Two viewport option sets are in play (`once`, `margin`, `amount` differ) | Each set gets its own cached observer; count `observe` per element, not per observer |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Count `new IntersectionObserver(...)` calls to prove registration | Count `observe(element)` calls and assert the node | The observer is cached per root + options in a module WeakMap |
| Fire `[{ isIntersecting: true }]` without `target` | Include `target` on every fake entry | The wrapper looks the callback up by `entry.target` |
| Accept a green timing suite as proof that props reach the transition | Add an end-state wait and a hardcoded-defaults mutation | Without a fired entry, only first-paint styles are observable |

## Sources

- framer-motion 13.2.0 `dist/es/motion/features/viewport/observers.mjs` (read 2026-09-28) — `initIntersectionObserver` stores observers in `observers: WeakMap<root, { [JSON.stringify(options)]: IntersectionObserver }>`; `fireObserverCallback = (entry) => { const callback = observerCallbacks.get(entry.target); callback && callback(entry); }`; `observeIntersection` sets the callback for the element and calls `observer.observe(element)`
- https://developer.mozilla.org/en-US/docs/Web/API/IntersectionObserverEntry/target — `target` is the element whose intersection changed; the wrapper keys its callbacks on it
- https://developer.mozilla.org/en-US/docs/Web/API/IntersectionObserver/observe — one `observe()` call per element added to the observed set
- https://vitest.dev/api/vi.html — `vi.stubGlobal` replaces a global for the test; it does not reset module-level state inside an already-imported library
- Field evidence 2026-09-27 (cover-letter, t1-motion-stagger, vitest + jsdom): constructor probe on a single group mount read `expected +0 to be 1`; the element probe read 1 on the correct implementation and `expected [ Array(4) ] to have a length of 1 but got 4` on a mutant giving each item its own `whileInView`. Without `target` on the fake entry, all 10 tests were green and so was a mutant hardcoding `transition: { staggerChildren: 0.06, delayChildren: 0 }`; with `target`, the same mutant turned 2 timing tests red (`expected '0.250279879765003' to be '0'`) and the run time went from 1 ms to 1018 ms
