---
id: infrastructure-observability-logs-metrics-signals
domain: infrastructure
category: observability
applies_to: [general]
confidence: verified
sources:
  - https://sre.google/sre-book/monitoring-distributed-systems/
  - https://prometheus.io/docs/practices/naming/
  - https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
last_verified: 2026-07-10
related: [infrastructure-observability-alerting]
---

# Instrumenting a Service with Logs and Metrics

## When this applies

Adding instrumentation to a new or existing service, or an incident revealed
you could not see what happened and you are closing that gap.

## Do this

1. Pick the signal by the question it must answer:

| Question | Signal |
|----------|--------|
| What happened in this one request/case? | Structured log line carrying the correlation id |
| How much, how often, how slow — over all requests? | Metric (counter, histogram) |

2. Emit structured logs: JSON key-value, UTC timestamps, machine-parseable
   fields — no prose sentences you will regex later. Use levels semantically:
   ERROR means a human should look at this; expected business events and
   handled rejections are INFO/WARN. When everything notable is ERROR, the
   error signal is noise.
3. Correlation id: accept or generate a request id at the edge, propagate it on
   every downstream call, include it in every log line on that request path.
   This id is the handle incident investigation pulls (debugging domain,
   wiki/debugging/).
4. Instrument the four golden signals per service: latency — as percentiles
   p50/p95/p99, never averages alone (an average looks fine while p99 is 10×) —
   traffic, errors, saturation.
5. Keep metric label cardinality bounded: label values come from small fixed
   sets (route template, status class, region). Never user ids, UUIDs, emails,
   or raw URLs as label values — each unique value creates a new time series
   (cardinality explosion).
6. Never log secrets or PII. Mask at the logger (one central
   serializer/filter), not at each call site — call sites get forgotten.

## Edge cases

| Case | Then |
|------|------|
| Per-user investigation needed but user ids cannot be labels | Put the user id in log lines and trace attributes; keep metrics aggregated, join via the correlation id |
| A dashboard is needed on data that today only exists in logs | Add a counter/histogram at the code site; keep log parsing for one-off retro analysis only |
| Per-request logging too expensive on a high-traffic path | Sample INFO logs; never sample ERROR; leave metrics unsampled — aggregation makes them cheap by design |
| Endpoint label would come from raw URL paths | Label with the route template (`/users/{id}`), not the concrete URL |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Log expected validation failures at ERROR | INFO/WARN plus a rejection counter | ERROR must keep meaning "someone should look" |
| Build a latency/traffic dashboard by parsing log lines | Emit a histogram/counter metric at the code site | Log parsing is fragile and expensive; "how much/how often" is metrics' job |
| Chart average latency | Chart p50/p95/p99 | Averages hide the tail latency users actually feel |
| Add user_id as a metric label | User id in logs/traces; metrics stay aggregated | Unbounded label values explode time-series cardinality |
| Strip passwords manually in each handler before logging | One masking filter in the logger pipeline | A single choke point cannot be forgotten by the next handler |

## Sources

- https://sre.google/sre-book/monitoring-distributed-systems/ — four golden signals; latency distributions over averages
- https://prometheus.io/docs/practices/naming/ — no high-cardinality values (user ids, emails) as label values
- https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html — never log secrets, session tokens, or sensitive PII
