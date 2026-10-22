---
id: testing-quality-tuned-constant-assertions
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://learn.microsoft.com/en-us/dotnet/core/testing/mutation-testing
  - https://pitest.org/quickstart/basic_concepts/
  - https://testing.googleblog.com/2014/07/testing-on-toilet-dont-put-logic-in.html
  - https://splishsplash.readthedocs.io/en/2.10.0/api/class_s_p_h_1_1_time_integration.html
last_verified: 2026-10-20
related: [
    testing-quality-default-values-under-test,
    testing-quality-tests-that-cannot-fail,
    testing-quality-harness-reverse-controls,
    testing-quality-surviving-mutant-equivalence-triage,
    frontend-design-pointer-attracted-particle-fields,
  ]
---

# Asserting Code Driven by Tuned Constants (Springs, Easing, Durations)

## When this applies

You are testing a function whose output is shaped by tuned constants — spring
stiffness and damping, named easing tokens (`standard`, `exit`), duration
tokens, a preset table (`bounce`, `settle`) — and the tests check only the
curve's shape ("overshoots 1", "ends near 1", "fades from 1 to 0", "is
monotonic"). Also when a mutation run or an auditor swapped one preset or token
for another and the suite stayed green.

A single numeric constructor default (`ttl_s=600`) → [testing-quality-default-values-under-test].

## Do this

1. **Pick mid-window sample points, where the variants differ most.** The start
   and the end of a curve are fixed by its family (every spring starts at 0 and
   settles at 1; every easing maps 0→0 and 1→1). Sample at points inside the
   motion — for a spring, the first peak and one point on each side of it; for
   an easing or duration, 25 %, 50 % and 75 % of the window.
2. **Compute the expected value at each point independently of the code under
   test.** Take the first row that fits:

| The constant feeds | Independent oracle |
|--------------------|--------------------|
| A spring with a closed-form solution (an underdamped `m·x'' = k(1−x) − c·x'`) | The analytic solution evaluated at the sample time |
| A spring integrated step by step | A separate step-by-step simulation (semi-implicit Euler: update the velocity, then the position with the new velocity) at a fine step, written in the test helper, not imported from the code |
| An easing token (`cubic-bezier(...)`) | The token's control points applied by hand at the sample progress |
| A duration token | The elapsed time at which the value crosses a midpoint, derived from the token's milliseconds |

3. **Set the tolerance between two numbers you measured:** above the gap between
   the oracle and the correct code (integrator step error, rounding), and below
   the smallest gap between the correct value and any sibling preset's value at
   that point. Print all three numbers once when you choose it.
4. **Swap one constant at a time and require red.** For each tuned value: replace
   the preset or token with each sibling (`bounce`→`settle`, `exit`→`standard`),
   and nudge each raw constant (`k`, `c`, the duration) by a step a designer
   would notice. Every swap must turn at least one test red; the unmutated run
   must stay green ([testing-quality-harness-reverse-controls]).
5. **Keep the shape checks** (overshoot, settle, monotonic). They state the
   intent; the exact values in steps 1-3 are what pin the constants.

## Edge cases

| Case | Then |
|------|------|
| The oracle helper is itself more than a few lines (a simulation loop) | Give it one known-answer test of its own (a case you can solve by hand, such as zero damping at a quarter period). Logic in a test is hard to check by reading, and a wrong oracle passes wrong code |
| Two presets are equal at your sample points | Move the sample points; the swap between those two presets otherwise survives every exact check too |
| The code clamps or rounds its output (pixels, frames) | Apply the same clamp or rounding to the oracle before comparing, and keep the tolerance under one rounding unit |
| The constant is meant to change during tuning | Record the derivation next to the expected values (the formula and inputs), so a retune updates the oracle inputs instead of pasting the new output |
| The library owns the integrator (react-spring, framer-motion) | Pin the parameters the code passes to the library ([testing-mocking-captured-call-arguments]) and sample the library's output at mid-window points once, to prove the parameters change what the user sees |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert only "overshoots 1 and ends near 1" for a spring preset | Add exact values at mid-window points from an independent oracle | Every underdamped spring overshoots and settles at 1; in the reproduction, swapping the preset, lowering `k` alone and raising `c` alone all passed the shape checks |
| Paste the code's current output as the expected values | Compute them with the oracle in step 2 and record how | A pasted output agrees with whatever constant the code had that day, including a wrong one |
| Pick the tolerance by feel | Measure the oracle-vs-code gap and the code-vs-sibling gap and set it between them | Too wide and a sibling preset passes; too narrow and the integrator error fails correct code |

## Sources

- https://learn.microsoft.com/en-us/dotnet/core/testing/mutation-testing — a mutant is a deliberate small change; if the tests still pass, the suite may be too weak (the reading applied to a swapped preset that stays green)
- https://pitest.org/quickstart/basic_concepts/ — "'Survived' means the mutation was not detected by the covering test"
- https://testing.googleblog.com/2014/07/testing-on-toilet-dont-put-logic-in.html — Testing on the Toilet, "Don't Put Logic in Tests": logic in a test makes it harder to check by reading; the basis for the oracle-helper edge row
- https://splishsplash.readthedocs.io/en/2.10.0/api/class_s_p_h_1_1_time_integration.html — semi-implicit (symplectic) Euler: `v(t+h) = v(t) + a(t)·h`, then `x(t+h) = x(t) + v(t+h)·h`
- Local reproduction 2026-10-20 (Node 26.7.0): a spring tween integrated with semi-implicit Euler at 1 ms, presets `bounce {k: 300, c: 12}` and `settle {k: 170, c: 14}`; oracle = closed-form underdamped solution; tolerance 0.02. Shape check (peak > 1, |x(2 s) − 1| < 0.01): correct code passes, `bounce`→`settle` passes, `k 300→250` passes, `c 12→16` passes. Exact values at 100/200/300 ms: correct code passes (0.8346 / 1.3095 / 1.0297 vs oracle 0.8273 / 1.3114 / 1.0336), and all three mutants fail (`settle` gives 0.4983 / 1.0203 / 1.1316)
- Field evidence 2026-10 (a 3D game's motion module; recorded by the originating session): an auditor's swaps `bounce`→`settle`, `exit`→`standard` and settle→slow durations — 26 mutations — all survived the shape-only tests. After exact-value tests (including a semi-implicit Euler run of `m·x'' = k(1−x) − c·x'`), every replayed mutant failed and the re-audit passed
