---
id: debugging-signals-logs-and-correlation
domain: debugging
category: signals
applies_to: [general]
confidence: verified
sources:
  - https://sre.google/sre-book/effective-troubleshooting/
  - https://www.w3.org/TR/trace-context/
last_verified: 2026-07-10
related: [debugging-signals-stack-traces, debugging-methodology-hypothesis-testing]
---

# Diagnosing Across Services with Logs

## When this applies

A failure spans multiple services, processes, or components, and logs are your
evidence — you need to reconstruct what happened, in what order, and where the
first fault occurred.

## Do this

1. Establish the timeline before interpreting anything. Confirm every log
   source's timezone and clock: normalize to UTC when comparing (and emit logs
   in UTC — local-time logs across regions make cross-service ordering
   unreconstructable). Treat sub-second ordering across hosts as unreliable
   (clock skew); order across hosts by causality (request A logged a call to B
   before B logged receiving it), not by timestamp alone.
2. Follow one failing request end to end. Take its correlation id (request id /
   trace id — W3C `traceparent` if instrumented) from the error or the edge log,
   and grep that id across all services to get the request's full path.
3. When no correlation id exists, correlate manually: narrow each service's logs
   to a tight time window around the failure, then match on values unique to the
   request — user id, order id, payload values, source IP + port. Confirm the
   match by consistency (same values, plausible ordering) before trusting it.
4. Find the FIRST error on that request's path, not the loudest. A single fault
   cascades: one connection failure upstream produces hundreds of timeouts and
   5xx entries downstream. Sort the request's entries by time and diagnose the
   earliest anomaly; later errors are effects until proven otherwise.
5. Read the window before the first error too — the last normal entries show
   what the system was doing when it broke (deploy, config reload, burst).

| Symptom | Search for |
|---------|-----------|
| Request fails with a 5xx at the edge | The request id at the edge, then the same id in each downstream service; the deepest service that errored first |
| Timeouts everywhere at time T | The first error of any kind at or before T across services (cascades start at one point); plus deploys/config changes just before T |
| One user affected | That user's id in a window around their report; compare the failing request's path against a succeeding request's path |
| Errors began at a specific time | What changed then: deploy markers, config reloads, cron entries, traffic level, in the minutes before the first error |
| Silent wrong behavior, no errors logged | The request's id through all hops: find where a value or hop deviates from a known-good request's trace; missing hop = lost message |

## Edge cases

| Case | Then |
|------|------|
| Two candidate "first" errors in different services within clock-skew distance | Order by causality, not timestamp: which service called which, and did the callee log the error before responding to the caller |
| Correlation id changes across a queue/batch boundary | Search the producer's id up to the boundary, find the enqueue entry, take the consumer-side id (message id, batch id) from it, continue with that id |
| Logs sampled or rate-limited during the incident | Entries are missing, so absence is not evidence of absence — corroborate with metrics/counters before concluding a hop was skipped |
| The needed detail was never logged | Add the log line (with the correlation id) at that boundary, redeploy, re-trigger via your reproduction ([debugging-methodology-reproduce-first]) |
| First error is a slow SQL statement | Diagnosis done here; the query fix belongs to the databases domain — wiki/databases/query-optimization/reading-execution-plans.md |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Grep for ERROR and investigate the most frequent one | Follow one failing request's path and take its chronologically first anomaly | Cascades make downstream noise the most frequent; the origin is small and early |
| Compare raw timestamps across services in mixed timezones | Normalize all sources to UTC first, then order by causality across hosts | An hour's timezone offset or seconds of skew silently inverts cause and effect |
| Conclude "service B never received it" because B has no log | Check whether B logs that path at all, and whether sampling dropped it | Absence of a log line is only evidence when the line is provably always emitted |

## Sources

- https://sre.google/sre-book/effective-troubleshooting/ — examining the system's telemetry/logs to localize the fault
- https://www.w3.org/TR/trace-context/ — standard propagation of trace ids across services (`traceparent`)
