---
id: testing-quality-injected-clock-duration-assertions
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://peps.python.org/pep-0564/
  - https://docs.python.org/3/tutorial/floatingpoint.html
  - https://docs.python.org/3/library/math.html#math.isclose
  - https://docs.pytest.org/en/stable/reference/reference.html#pytest-approx
last_verified: 2026-08-04
related: [testing-async-async-testing, testing-data-test-data-and-isolation, testing-flaky-diagnosing-flaky-tests, testing-quality-tests-that-cannot-fail]
---

# Asserting a Duration Between Two Readings of an Injected Clock

## When this applies

Code under test records two readings of an injected/fake clock that returns a
float of seconds, and the test asserts the elapsed gap against an exact bound —
a rate limiter's minimum interval, a retry backoff, a debounce window, a TTL.
The assertion is `gap >= interval`, `gap == interval`, or `gap <= interval`.

Choosing the seam (injecting the clock at all) → [testing-data-test-data-and-isolation].

## Do this

1. **Put the tolerance on the bound, and pick the bound's direction
   deliberately.** A float clock makes `start + interval - start` differ from
   `interval`, so an exact comparison fails on correct code:

| Assertion you mean | Write |
|--------------------|-------|
| "at least `interval` elapsed" (rate limit, min backoff) | `assert gap >= interval - TOL` |
| "at most `interval` elapsed" (deadline, max wait) | `assert gap <= interval + TOL` |
| "exactly `interval` elapsed" (computed duration) | `math.isclose(gap, interval)` / `gap == pytest.approx(interval)` |

   Use a symmetric closeness helper only for the equality row. On a lower bound,
   `isclose` also accepts a gap that is *smaller* than the interval — which is
   the defect a rate-limiter test exists to catch.

2. **Start the fake clock at `0.0`.** `0.0 + x - 0.0` is exact for every `x`, so
   the arithmetic error disappears at the source. This is what CPython itself
   does: PEP 564 records that Python "starts `monotonic()` and `perf_counter()`
   clocks at zero on some platforms which indirectly reduce the precision loss".

3. **Set `TOL` from the magnitudes, not by widening until green.** Pick a value
   at least three orders of magnitude below the smallest interval the test must
   distinguish, and above the representation error at your clock's magnitude.
   `1e-6` seconds satisfies both for second-scale intervals, and matches
   `pytest.approx`'s default relative tolerance of `1e-6`.

4. **When the assertion must be exact, count integer nanoseconds** and keep the
   fake clock's counter an `int`. Integers do not lose precision, so no
   tolerance is needed and the test states an exact fact.

## Edge cases

| Case | Then |
|------|------|
| The fake clock's start value was chosen to look "realistic" (an epoch, a machine uptime, `1000.0`) | Set it to `0.0` and keep the tolerance. Realism buys the test nothing and is exactly what reintroduces the error — measured below, a start of `1.0` is already enough to break an exact `>=` |
| The gap comes out *larger* than the interval, not smaller | Expected — the rounding direction depends on the start value's exponent (measured: start `1e6` yields `1.0500000000465661` for a `1.05` step). Tolerate both directions on an equality or upper-bound assertion, not just the low side |
| The test seeds the fake clock from `time.monotonic()` | Seed it from `0.0` instead; a real monotonic reading is a large float (measured 90474.0 on an ordinary session) and carries the same error class |
| Only one test in the suite fails after a clock change, with a gap that differs from the bound in the 13th decimal | Read it as a representation artifact, not a behavior regression — confirm by checking the delta's magnitude before touching the implementation |
| The chosen `TOL` is within an order of magnitude of the interval | The assertion no longer distinguishes "waited" from "did not wait"; shrink `TOL` or assert on an integer-nanosecond clock ([testing-quality-tests-that-cannot-fail]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `assert gap >= interval` against a float fake clock | `assert gap >= interval - TOL` with `TOL` chosen by magnitude | Most decimal fractions have no exact binary representation, so a correct implementation produces a gap a few ulps short and the test fails on working code |
| Give the fake clock a large "realistic" start value | Start it at `0.0` | `0.0 + x - 0.0` is exact; any other start makes the recoverable gap depend on that start's exponent |
| Widen the tolerance until the suite goes green | Compute the tolerance from the smallest interval the test must distinguish | A tolerance sized to silence a failure eventually exceeds the defect and the test stops detecting it |
| Use `math.isclose(gap, interval)` for an "at least" assertion | One-sided `gap >= interval - TOL` | Symmetric closeness also accepts a too-short gap — the exact violation a minimum-interval test guards |

## Sources

- https://peps.python.org/pep-0564/ — "Internally, Python starts `monotonic()` and `perf_counter()` clocks at zero on some platforms which indirectly reduce the precision loss"; "The problem is that the `float` type starts to lose nanoseconds after 104 days"
- https://docs.python.org/3/tutorial/floatingpoint.html — "Unfortunately, most decimal fractions cannot be represented exactly as binary fractions… the decimal floating-point numbers you enter are only approximated by the binary floating-point numbers actually stored in the machine"
- https://docs.python.org/3/library/math.html#math.isclose — `math.isclose(a, b, *, rel_tol=1e-09, abs_tol=0.0)`; symmetric closeness, with `abs_tol` required for comparisons against zero
- https://docs.pytest.org/en/stable/reference/reference.html#pytest-approx — default relative tolerance `1e-6`, default absolute tolerance `1e-12`; equal if either tolerance is met
- Local reproduction 2026-08-04 (CPython 3.14.6, macOS): for a `1.05` step, `start + 1.05 - start` yields `1.05` at `start=0.0`; `1.0499999999999998` at `1.0`; `1.0499999999999972` at `100.0`; `1.0499999999999545` at `1000.0`; `1.0500000000465661` at `1e6`; `1.0499999523162842` at `1e9`. Only `start=0.0` satisfies `gap >= 1.05`; every listed start satisfies `gap >= 1.05 - 1e-6`
