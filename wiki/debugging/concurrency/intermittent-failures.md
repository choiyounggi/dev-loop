---
id: debugging-concurrency-intermittent-failures
domain: debugging
category: concurrency
applies_to: [general]
confidence: verified
sources:
  - https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html
  - https://testing.googleblog.com/2017/04/where-do-our-flaky-tests-come-from.html
last_verified: 2026-09-27
related: [debugging-methodology-isolate-by-bisection, debugging-methodology-reproduce-first, testing-flaky-diagnosing-flaky-tests, testing-quality-proving-a-critical-section-is-lock-protected, debugging-methodology-hypothesis-testing]
---

# Making an Intermittent Failure Reproducible

## When this applies

The intermittent failure is in the system itself: an occasional prod error, a
bug that appears only under load, or behaviour you can trigger only
sometimes. You cannot debug it because you cannot trigger it on demand — the
job is to amplify it into a reproduction. If the unreliable thing is a test in
your suite, go to wiki/testing/flaky/diagnosing-flaky-tests.md.

## Do this

1. Treat intermittency as information: the code path is fixed, so a hidden
   variable is deciding pass vs fail — timing, ordering, shared state, resources,
   or environment. The job is to find that variable, and the method is to
   amplify until the failure reproduces on demand.
2. Read the failure pattern for the likely hidden variable:

| Pattern | Likely hidden variable |
|---------|------------------------|
| Fails only under load / high concurrency | Contention: race windows that need concurrent access, pool/connection exhaustion, lock timeouts |
| Fails only in CI, passes locally | Environment: tighter CPU/memory limits (different timing), parallel test processes sharing DB/ports/files, missing local-only state |
| Passes on retry / fails only in full-suite runs | Inter-test dependence: leftover state (DB rows, globals, files) from earlier tests, or an order-dependent test |
| Fails at particular times / dates | Clock dependence: timezone boundaries, DST, month-end, expiring fixtures/certs |
| Fails on one machine or platform only | Platform variance: core count (parallelism), filesystem case sensitivity, dependency or OS version drift |

3. Amplify along the suspected variable until failure is on-demand:

| Suspected variable | Amplify by |
|--------------------|-----------|
| Race / timing | Run the operation in a tight loop (hundreds–thousands of iterations); insert sleeps/yields at suspected interleaving points to widen the race window (a sleep that makes it fail every time has located the window); reduce available cores or raise thread count |
| Load / contention | Drive concurrent load while looping the failing operation; shrink pool sizes and timeouts so exhaustion happens in seconds |
| Test order / leftover state | Run the suite in random order with a printed seed; re-run the failing test alone (passes alone + fails in suite = order dependence); bisect which preceding test poisons it |
| Environment (CI-only) | Reproduce CI's constraints locally: same container image, CPU/memory limits, and test parallelism |
| Clock | Freeze/set the clock in the reproduction to the suspicious boundary |

4. Before wiring diagnostic instrumentation into the loop, when the symptom is
   a value several code paths can produce (an error variant, a status code, a
   panic message built at one shared site), enumerate every producer with one
   exhaustive search (`grep -n '<SymptomValue>' <files>`) and classify each
   hit — assigns, produces independently, unreachable, consumes — by tracing
   its data flow, not by the shape of the surrounding code. Instrument every
   producer, and keep the loop's stop condition on the symptom text alone: a
   stop condition of "symptom AND my diagnostic line" classifies a genuine
   reproduction from an uninstrumented producer as "not the target", burns the
   run budget, and ends in a false "could not reproduce".
5. Once the failure reproduces on demand, you have a reproduction — locate the
   cause with [debugging-methodology-isolate-by-bisection], using N runs per
   probe so a lucky pass cannot misdirect the search.
6. Keep the amplified reproduction (stress loop, ordering seed, sleep injection)
   until the fix is verified: the fix must survive the same amplification that
   made the bug reliable.

## Edge cases

| Case | Then |
|------|------|
| Adding logging/debugger makes it stop failing | The observation shifted the timing. Use lighter probes: counters, pre-buffered logs, post-mortem state dumps — and rely on loop statistics rather than stepping |
| Failure rate is so low that even loops rarely hit it | Amplify harder (more concurrency, fewer cores, smaller pools, injected delays at the suspected point) — raise the probability, don't raise patience |
| A first pass labelled some producers of the symptom value "inert references" without tracing them | Treat every hit as a producer until its data flow says otherwise — a site that never reads the traced variable can still write the symptom (`handle.await.unwrap_or(Failed)`); re-run the exhaustive grep after any refactor of the symptom value |
| Retry-on-failure is already wallpapering over it in CI | Keep the retry data: a quarantined/retried test's failure rate is your reproduction-rate baseline; debug from the recorded failures rather than deleting them |
| It reproduces only in prod, never in any test rig | Capture evidence in place per [debugging-methodology-reproduce-first]: correlation-id logs, thread dumps at failure time, and replicate prod's concurrency shape in staging |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Re-run until it passes and merge | Amplify until it fails on demand, then diagnose | The hidden variable ships to prod, where load amplifies it for you |
| Add a sleep to the test to "fix" flakiness | Use the sleep as a diagnostic to locate the race window, then fix the synchronization and remove the sleep | A sleep narrows the window without closing it; it fails again on slower machines |
| Debug from a single failing run's evidence | Collect many amplified runs and compare failing vs passing | One intermittent run cannot separate the hidden variable from noise |

## Sources

- https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html — flaky test causes (concurrency, infrastructure) and why rerun-until-pass is insufficient
- https://testing.googleblog.com/2017/04/where-do-our-flaky-tests-come-from.html — flakiness correlates with test size/resource use; ordering and environment as sources
- Field evidence 2026-09 (a Rust orchestration controller, task t1-flaky-m5; integration test failing only under load): `grep -n 'RunOutcomeDto::Failed' controller.rs` → 5 hits — two assignments (:869, :918), one independent producer (:1479, `handle.await.unwrap_or(Failed)`), one unreachable (:1480), one consumer (:1487); the initial plan had instrumented only the two assignments and gated the loop on "panic AND diagnostic line". With every producer instrumented and the stop condition on the panic text alone, the failure reproduced on the first run and held a 3/21 rate for bisection
