# debugging — Domain Index

Route here for: diagnosing a failure — finding what is wrong and why. Fixing the
diagnosed fault belongs to the owning domain.

Match your situation to a "load when" line; load only matching pages.

## methodology

| Page | Load when |
|------|-----------|
| [reproduce-first](methodology/reproduce-first.md) | A bug is reported or behavior is wrong and you are about to investigate or fix; deciding what to capture when full reproduction is impossible (prod-only, timing-dependent, one-off crash) |
| [isolate-by-bisection](methodology/isolate-by-bisection.md) | A bug reproduces but its location is unknown; it worked before / works in env A but not env B / fails with one input but not another — binary-searching versions (git bisect), code paths, data, or environment diffs |
| [hypothesis-testing](methodology/hypothesis-testing.md) | You have a suspect cause and are about to "try a fix"; several suspects compete and you must pick what to test next; verifying that a fix that "worked" actually addressed the mechanism |
| [verify-the-fix](methodology/verify-the-fix.md) | You believe a bug is fixed and are about to close or ship it; the bug "cannot be reproduced anymore" after changes; a previously fixed bug came back; deciding what must pass (repro re-run, both directions, regression test) and what to clean up before closing |

## signals

| Page | Load when |
|------|-----------|
| [stack-traces](signals/stack-traces.md) | Interpreting an exception/stack trace from a log, test failure, or error tracker; wrapped/rethrown causes, NPE on a chained call, async traces missing the origin, minified JS frames |
| [reading-error-messages](signals/reading-error-messages.md) | Any error output you are about to act on — compiler/build failure, runtime error without a stack trace, config/startup error, a wall of errors from one run; deciding which of many errors to fix first (cascades); about to search for a fix or evaluate a fix found online |
| [logs-and-correlation](signals/logs-and-correlation.md) | Diagnosing a failure that spans services/components using logs; reconstructing a timeline, following one request via (or without) a correlation id, finding the first error in a cascade |

## performance

| Page | Load when |
|------|-----------|
| [profile-before-optimizing](performance/profile-before-optimizing.md) | Something is slow (endpoint, job, test suite, page) and you are about to optimize; choosing CPU profiling vs wall-clock tracing; cold vs warm measurement; verifying a speedup (a single slow SQL statement → databases/query-optimization/reading-execution-plans) |

## concurrency

| Page | Load when |
|------|-----------|
| [intermittent-failures](concurrency/intermittent-failures.md) | A failure happens only sometimes: passes on retry, fails under load, fails only in CI, flaky test, occasional prod-only error — amplifying it into an on-demand reproduction |
