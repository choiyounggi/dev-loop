---
id: backend-common-integrations-estimate-derived-thresholds
domain: backend
category: integrations
applies_to: [general]
confidence: verified
sources:
  - https://www.freqtrade.io/en/stable/stoploss/
  - https://en.wikipedia.org/wiki/Slippage_(finance)
  - "Live incident 2026-08-13/14 (KIS auto-trading bot): 6 positions exited TAKE_PROFIT at +0.06%–+0.42% against a +2% design; re-anchor in mark_filled() restored the band, regression tests red on pre-fix code"
last_verified: 2026-08-14
related: []
---

# Absolute Thresholds Derived from a Pre-Execution Estimate

## When this applies

You submit an action to an external system whose actual outcome can differ
from the estimate you decided on (market order → fill price vs the quote at
decision time), and you persist **absolute** trigger values derived from that
estimate — stop-loss/take-profit prices, alert thresholds, budget cutoffs.
The actual outcome arrives later as a separate confirmation event (fill
report, webhook, reconciliation).

## Do this

1. **Persist the intent as ratios/offsets relative to the anchor** (e.g.
   SL −2% / TP +2% of entry), alongside any precomputed absolutes. The ratio
   is the durable design value; the absolute is a cache of it.
2. **Re-anchor at the confirmation-recording point.** In the single function
   that records the action as confirmed (`mark_filled()`, the fill-webhook
   handler), recompute the absolute triggers from the actual outcome,
   preserving the stored ratios. Fix it there — not per entry path: entry
   paths multiply (daily run, intraday redeploy, manual), while every one of
   them funnels through the confirmation recorder.
3. **Treat the estimate/actual gap as expected behavior, not an error.**
   Slippage — execution at a price different from the one at decision time —
   is a normal property of market orders and widens at opens and in volatile
   periods (Wikipedia: Slippage). Reference practice: freqtrade defines
   stoploss as a ratio of the entry ("a stoploss of -10% is placed exactly
   10% below the entry point") and places the exchange stoploss order only
   after the buy order fills — the anchor follows the fill, not the quote.

## Edge cases

| Case | Then |
|------|------|
| Partial fills | Re-anchor on the volume-weighted average fill price — either at each fill event or once on completion; pick one and record which in the recorder |
| The confirmation event can arrive twice (webhook redelivery, reconciliation re-run) | Make the re-anchor idempotent: derive from stored ratios + fill price, never by mutating the previous absolutes incrementally |
| The estimate-derived absolute was already shown or notified to users | Recompute the display from the same anchor (or emit a correction); a UI still quoting the stale absolute contradicts the triggers actually armed |
| The confirmation payload lacks the actual value (no fill price reported) | Keep the estimate-derived values and log loudly that triggers are estimate-anchored; silently treating the estimate as the actual hides the gap this page exists to close |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Fix a stale-anchor bug in each entry path that computes SL/TP | Re-anchor once where the fill is recorded | Entry paths keep multiplying; the confirmation recorder is the funnel they all pass through |
| Keep absolute triggers computed from the pre-order quote after the fill confirms | Recompute from the fill price, preserving the design ratios | Slippage/gap eats the margin: a +2% designed take-profit band collapsed to +0.06%–+0.42% observed triggers, exiting positions for less than fees |

## Sources

- https://www.freqtrade.io/en/stable/stoploss/ — stoploss defined as a ratio of the entry price ("a stoploss of -10% is placed exactly 10% below the entry point"); with stoploss-on-exchange, the stoploss order "is placed on the exchange immediately after buy order fills"
- https://en.wikipedia.org/wiki/Slippage_(finance) — execution price differing from the decision-time price is inherent to market orders, larger under volatility
- Live incident 2026-08-13/14, Korea Investment & Securities auto-trading bot: SL/TP absolutes computed from the pre-order signal price survived fills at higher prices; 6 real positions triggered TAKE_PROFIT at +0.06%–+0.42% against a +2% design. Re-anchoring in `mark_filled()` (ratio-preserving recompute from the actual fill price) restored the band; regression tests fail on the pre-fix code and pass after (464-test suite green)
