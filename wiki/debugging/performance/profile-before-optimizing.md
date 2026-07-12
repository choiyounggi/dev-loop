---
id: debugging-performance-profile-before-optimizing
domain: debugging
category: performance
applies_to: [general]
confidence: verified
sources:
  - https://www.brendangregg.com/flamegraphs.html
  - https://sre.google/sre-book/effective-troubleshooting/
last_verified: 2026-07-10
related: [debugging-methodology-hypothesis-testing, databases-query-optimization-reading-execution-plans]
---

# Locating Where Time Goes Before Optimizing

## When this applies

Something is slow — an endpoint, a job, a test suite, a page load — and you are
about to make it faster. Applies before any optimization work, including "I
already know what's slow".

## Do this

1. Measure where the time goes before changing anything. Suspicion selects a
   place to look, not a place to fix — the measurement decides.
2. Pick the measurement by what the process is doing while slow:

| Case | Measure with |
|------|--------------|
| CPU-bound (process busy the whole time) | CPU profiler / flame graph — widest frames = most CPU time; look for one dominant tower, not leaf noise |
| Waiting (I/O, network calls, DB, locks — CPU mostly idle) | Wall-clock tracing: spans or timestamped logs around each external call; CPU profiles are blind to time spent waiting |
| Not known yet which | Wall-clock first: bracket the whole operation, then bracket its major phases; recurse into the largest phase |
| Slowness is a single SQL statement | Diagnosis leaves this domain: take it to wiki/databases/query-optimization/reading-execution-plans.md |
| Slow only under load, fine alone | Contention, not code speed: measure queue/pool wait times and lock waits under the same load, per [debugging-concurrency-intermittent-failures] amplification |

3. Distinguish cold from warm runs. First runs pay one-time costs — empty
   caches, JIT compilation, connection/TLS setup, lazy initialization. Measure
   both, and report which one you measured. Optimize the run your users
   experience: steady-state traffic → warm; startup, cron jobs, serverless cold
   starts → cold.
4. Use multiple runs and compare distributions (median and p95+), not single
   runs — single measurements swing with noise. A regression visible only at
   p99 is a different bug (outliers/contention) than one visible at the median.
5. Optimize the top contributor only, then re-measure with the same method and
   inputs. The profile after each change is the decision point for the next —
   contributors shift once the top one shrinks.
6. Stop when the measurement meets the target. Set the target (latency budget,
   SLO, "faster than X ms") before optimizing so "done" is decidable.

## Edge cases

| Case | Then |
|------|------|
| Profile shows time spread thin across hundreds of small frames | No single hotspot: the cost is architectural (per-item overhead in a loop, chatty I/O, allocation churn). Aggregate by call site or by phase instead of by function |
| Slow in prod, fast locally | Profile in the slow environment (or replicate its data volume and concurrency); local profiles of a non-reproducing setup measure the wrong system |
| Measurement overhead changes the behavior (heavy instrumentation) | Use sampling profilers for CPU and coarse-grained spans for waits; verify the operation's total time with instrumentation off matches with it on |
| Endpoint slow because it makes many fast calls (N+1 pattern) | The trace shows the fan-out: fix the call count, not the per-call speed — for DB calls see wiki/databases (n-plus-one-queries) |
| Two candidate optimizations look equally promising | Cheaper-to-falsify first, one at a time, re-measuring between — per [debugging-methodology-hypothesis-testing] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Optimize the code you suspect is slow | Profile first; optimize the measured top contributor | Suspicion routinely lands on familiar code, not costly code; unmeasured fixes add complexity for ~0 ms |
| Benchmark once before and once after | Compare distributions over multiple runs, cold and warm identified | Single runs differ by noise larger than many real optimizations |
| Report a speedup from a first-run vs re-run comparison | Compare same-state runs (warm vs warm, cold vs cold) | The re-run is faster because caches/JIT warmed, not because of your change |
| Keep optimizing after the target is met | Stop; re-open only when the measured target moves | Past the target, added complexity costs more than the microseconds it buys |

## Sources

- https://www.brendangregg.com/flamegraphs.html — flame graphs: visualizing profiled stacks to find the widest (costliest) code paths
- https://sre.google/sre-book/effective-troubleshooting/ — diagnose from measured system behavior, not assumption
