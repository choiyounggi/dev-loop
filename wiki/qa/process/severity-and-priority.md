---
id: qa-process-severity-and-priority
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://www.atlassian.com/incident-management/kpis/severity-levels
last_verified: 2026-07-10
related: [qa-bug-reports-reproducible-reports, qa-process-release-gates]
---

# Assigning Severity and Priority to a Bug

## When this applies

Triaging a bug — deciding how bad it is and when it gets fixed; or a triage
meeting is stalled on a severity debate.

## Do this

Severity and priority are **separate axes set by different people**:

| Axis | Measures | Set by | Set how |
|------|----------|--------|---------|
| Severity | Impact on the user/system when the bug fires | Whoever observed/verified the bug | Against the fixed definitions below — factual, not negotiated |
| Priority | Fix order | The owning team | From the priority factors below — business judgment, freely negotiated |

Both off-diagonal combinations are legitimate: a data-loss bug in a rare edge
case is high-severity/low-priority; a typo on the pricing page is
low-severity/high-priority. A triage that forces the two to match loses
exactly this information.

Severity — fixed definitions, applied as observed:

| Level | Definition |
|-------|------------|
| S1 critical | Data loss, security breach, or a whole feature/service down — and no workaround exists |
| S2 major | A core flow is broken for a significant user segment; a workaround exists but is painful |
| S3 minor | Degraded behavior with a reasonable workaround |
| S4 trivial | Cosmetic; no functional impact |

Priority — weigh these factors, per bug:

| Factor | Ask |
|--------|-----|
| User reach | How many users hit the affected path? |
| Frequency | How often does a user on that path hit the bug? |
| Workaround cost | What does avoiding/recovering from it cost the user? |
| Business exposure | Revenue, trust, legal, brand — the pricing-page typo is S4 and P1 on this factor alone |

**Regression rule**: a bug that breaks previously-working behavior gets a
priority bump over an equal-severity bug in a new feature — users notice
losing something far more than they notice never having had it.

## Edge cases

| Case | Then |
|------|------|
| Severity depends on data you don't have (is the affected segment big?) | Reach/size belongs to priority, not severity — set severity from the per-user impact now, measure reach for the priority call |
| Bug fires intermittently | Severity = impact when it fires (a 1-in-100 data loss is S1); frequency enters through the priority factors |
| Reporter and triager disagree on severity | Re-read the observed behavior against the fixed definitions — a severity disagreement is a fact disagreement, so reproduce it ([qa-bug-reports-reproducible-reports]) rather than vote |
| S1 found during a release gate | Severity feeds the gate decision directly: an unaccepted S1 in the release scope is a block outcome ([qa-process-release-gates]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Inflate severity to get a bug fixed sooner | Keep severity factual; argue priority with reach, frequency, workaround cost, and business exposure | Inflated severity destroys the signal every other consumer of the field relies on (gates, SLAs, reporting) — and the priority factors are the argument that actually schedules work |
| Auto-derive priority from severity (S1→P1, S4→P4) | Score the priority factors per bug | The mapping erases the off-diagonal cases: rare-edge S1s over-schedule, pricing-typo S4s never ship |
| Stall triage debating one bug's severity | Record both candidate levels with the open question, set priority from the factors (they rarely depend on the contested level), move on | Priority is what schedules the fix; severity can be settled asynchronously by reproducing |

## Sources

- https://www.atlassian.com/incident-management/kpis/severity-levels — fixed severity-level definitions applied consistently, kept separate from scheduling judgment
