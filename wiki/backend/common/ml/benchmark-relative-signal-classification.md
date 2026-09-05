---
id: backend-common-ml-benchmark-relative-signal-classification
domain: backend
category: ml
applies_to: [general]
confidence: verified
sources:
  - https://corporatefinanceinstitute.com/resources/equities/abnormal-return/
  - https://www.wallstreetprep.com/knowledge/information-ratio/
  - "Field measurement 2026-08-26 (stock-signal-bot, KRX): a 5-day +4.44% move graded as entity-specific strength sat under the KOSPI's +5.21% over the same window"
last_verified: 2026-09-06
related: [backend-common-integrations-estimate-derived-thresholds, backend-common-ml-mape-aligned-point-prediction, infrastructure-observability-alerting]
---

# Rating a Per-Entity Signal While a Shared Driver Moves Every Entity

## When this applies

Code classifies a per-entity observation as entity-specific strength or weakness
— a stock's price move or buy-flow (institutional + foreign net buying), a
store's sales jump, a service's latency change, a cohort's conversion lift — and
a driver shared by every entity in the population (the market index, a holiday,
a platform-wide release, seasonality) moves all of them at once; deciding the
inputs a signal grader needs before it labels anything "strong".

## Do this

1. **Compute the benchmark's return over the same window as the entity's, and
   grade the difference, not the raw move.** Excess return = entity return −
   benchmark return over identical start and end points. A signal earns
   "entity-specific" only when the excess is positive (or beyond a floor you
   set); a raw +0.88% day on a +0.97% index day is a −0.09% excess, a lag.

| Observation | Read it as |
|-------------|------------|
| Entity up, excess > 0 | Entity-specific strength — grade the signal |
| Entity up, excess ≤ 0 | Benchmark-driven; the entity lagged — grade as neutral or weak |
| Entity flat or down, excess > 0 | Relative strength (held up while the population fell) — grade it |
| Benchmark unavailable for the window | Withhold the grade and log the missing benchmark; a grade computed without it is the raw move relabelled |

2. **Use one window for both sides and carry it in the record.** Store
   `window_start`, `window_end`, `entity_return`, `benchmark_return`, `excess`
   next to the grade so a reviewer can recompute; a same-day flow signal graded
   against a 5-day price window is two different claims.

3. **Treat a population-wide signal burst as a driver, not a discovery.** When
   the same "strong" label fires on most large entities on one day, the shared
   driver is the cause; gate the grade on excess return and on the share of the
   population also flagged (a flag on more than a set share of the universe is a
   market event, not that many signals).

4. **Choose the benchmark by what the entity is compared against in the
   consumer's decision** — a broad index for market-wide flow signals, a sector
   index for sector rotation, a control cohort for product experiments — and
   name it in the output.

## Edge cases

| Case | Then |
|------|------|
| The entity's window includes a day the benchmark did not trade (holiday, halt) | Align to the entity's trading days: take the benchmark's values on those exact dates; a calendar-day window mixes different day counts |
| The benchmark is a composite the entity dominates (a mega-cap in a cap-weighted index) | Use an equal-weighted or ex-entity benchmark; otherwise the entity is measured against itself |
| Only daily flow counts (buyer categories) exist, with no benchmark flow series | Grade the flow on the price excess return over the same window; flow direction alone is the population-wide signal this page warns about |
| The consumer wants the raw move too | Emit both fields; the grade is computed from the excess, the raw move is displayed |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Label "institutions and foreigners both net-bought and the stock rose" as strength | Compute the stock's excess return over the index for the window first | In an index rally nearly every large entity carries that pattern; without the benchmark the label's discrimination is near zero |
| Compare today's move to the index but grade a multi-day trend | Align both sides to the same window before grading | A one-day beat inside a five-day lag reverses the conclusion (measured: +0.88% vs +0.97% on the day, +4.44% vs +5.21% over five days) |
| Skip the benchmark when its feed is down | Withhold the grade and alert on the missing input | A grade emitted without its denominator is silently degraded output ([infrastructure-observability-alerting], fallback row) |

## Sources

- https://corporatefinanceinstitute.com/resources/equities/abnormal-return/ — "Excess Return = Actual Return − Expected Return", with the market index as the expected return in the worked example (12% − 14% = −2%)
- https://www.wallstreetprep.com/knowledge/information-ratio/ — active performance is "the excess return over a benchmark", the standard denominator for judging entity-specific performance
- Field measurement 2026-08-26 (stock-signal-bot, KRX): close 1,531,000 (08-18) → 1,599,000 (08-26) = +4.44% while the KOSPI 5-day return was +5.21%; the same day's +0.88% sat under the index's +0.97%; the buy-flow signal graded as strength was a lag once benchmarked, and the grader was changed to require positive excess return
