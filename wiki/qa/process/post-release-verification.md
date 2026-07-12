---
id: qa-process-post-release-verification
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://sre.google/workbook/canarying-releases/
last_verified: 2026-07-10
related: [qa-process-release-gates, qa-environments-test-environment-parity, qa-process-severity-and-priority, qa-process-regression-scope]
---

# Verifying a Release After It Reaches Production

## When this applies

A release just deployed to production; defining what "released safely" means
for your process; or an incident revealed a release was broken for hours
before anyone noticed.

## Do this

The release gate ([qa-process-release-gates]) ends at ship. Production is the
first environment with real users, real data, and real load — verify there
**deliberately**, not by waiting for complaints:

1. **Define the verification window before deploying**: a duration scaled to
   blast radius (minutes for a copy change, hours for a payment-path change),
   with a **named owner** watching for the whole window. "Whoever notices" is
   how a release stays broken for hours.
2. **Run the verification checklist inside the window:**

| Check | How |
|-------|-----|
| Prod smoke | Walk the changed flows plus the top critical flows — the same fixed list the gate uses — against production. Where a step writes destructively, use a test account or the flow's read-only variant |
| Dashboards | Read the release's error rate, latency, and the key business metric **compared to the pre-release baseline** — a diff against the same metric before the deploy, not absolute eyeballing of a graph (rollout automation and canary mechanics → wiki/infrastructure/deploy/) |
| Staging gaps | Every claim staging could not verify ([qa-environments-test-environment-parity] inventory: stubbed integrations, prod-scale performance, concurrency) gets its explicit prod check here |

3. **Pre-agree the rollback decision.** Thresholds — "error rate doubles vs
   baseline", "checkout conversion drops X%" — are decided BEFORE the release,
   so the rollback call is mechanical: threshold crossed → roll back. A
   threshold invented during the incident is a debate at 2am (rollback
   mechanics → wiki/infrastructure/deploy/).
4. **Record the outcome in the release history**: verified clean, or issues
   found → actions taken. That record is the evidence feed for the regression
   map ([qa-process-regression-scope] — which areas actually break per
   release) and the baseline for the next release's window.

## Edge cases

| Case | Then |
|------|------|
| Release is behind a feature flag | Verification covers flag-ON behavior for the enabled cohort — flag-OFF prod proves nothing about the feature. The flag kill switch is the first rollback lever; a full deploy rollback is the second |
| Staged/phased rollout (1% → 10% → 100%) | Repeat the verification per widening step, not once at the start — each step exposes new load, new data, new user segments; compare each step's metrics against its own control (the SRE-workbook canarying pattern — see Sources) |
| A regression is found during the window | Triage severity/priority per [qa-process-severity-and-priority]; the halt/rollback decision applies the pre-agreed thresholds, not a fresh debate. File it per [qa-bug-reports-reproducible-reports] with the release id |
| Deploy lands in a low-traffic period | Baseline comparison starves on sparse data: compare against the same time-of-day/day-of-week baseline, and extend the window until the changed flows have real traffic — a quiet hour of green proves quiet, not correct |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Declare "deployed successfully" because the pipeline is green | Run the verification window: prod smoke + baseline-compared dashboards + staging-gap checks | The pipeline proves the artifact was delivered; the window proves the release works for real users on real data |
| Debate rollback thresholds during the incident | Pre-agree thresholds per release, before deploying | At 2am with metrics moving, every party argues from adrenaline; a pre-agreed number makes the call mechanical |
| Eyeball the error graph for "looks normal" | Compare the metric against its pre-release baseline value | "Normal" drifts with memory; a doubled error rate on a low-traffic service still looks like a flat line |
| Leave watching to whoever happens to be online | Name the owner and the window length before the deploy | An unowned window is an unwatched window — the incident review will find nobody was assigned, because nobody was |

## Sources

- https://sre.google/workbook/canarying-releases/ — evaluate a release by comparing its metrics against a control/baseline with evaluation criteria defined in advance; widen exposure stepwise
