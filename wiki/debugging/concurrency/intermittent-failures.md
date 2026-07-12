---
id: debugging-concurrency-intermittent-failures
domain: debugging
category: concurrency
applies_to: [general]
confidence: verified
sources:
  - https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html
  - https://testing.googleblog.com/2017/04/where-do-our-flaky-tests-come-from.html
last_verified: 2026-07-10
related: [debugging-methodology-isolate-by-bisection, debugging-methodology-reproduce-first]
---

# Making an Intermittent Failure Reproducible

## When this applies

A failure happens only sometimes: the test passes on retry, the bug appears only
under load, only in CI, only occasionally in prod. You cannot debug it because
you cannot trigger it on demand.

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

4. Once the failure reproduces on demand, you have a reproduction — locate the
   cause with [debugging-methodology-isolate-by-bisection], using N runs per
   probe so a lucky pass cannot misdirect the search.
5. Keep the amplified reproduction (stress loop, ordering seed, sleep injection)
   until the fix is verified: the fix must survive the same amplification that
   made the bug reliable.

## Edge cases

| Case | Then |
|------|------|
| Adding logging/debugger makes it stop failing | The observation shifted the timing. Use lighter probes: counters, pre-buffered logs, post-mortem state dumps — and rely on loop statistics rather than stepping |
| Failure rate is so low that even loops rarely hit it | Amplify harder (more concurrency, fewer cores, smaller pools, injected delays at the suspected point) — raise the probability, don't raise patience |
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
