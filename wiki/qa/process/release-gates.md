---
id: qa-process-release-gates
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://sre.google/sre-book/release-engineering/
last_verified: 2026-07-10
related: [qa-process-regression-scope, qa-exploratory-exploratory-sessions]
---

# Deciding Whether a Build Is Ready to Ship

## When this applies

Deciding whether a build/release is ready to ship, or defining (or reviewing)
the checklist that makes that decision.

## Do this

A release gate is a **fixed, written checklist evaluated the same way every
release** — the decision comes from the checklist result, not from anyone's
feel for the diff. Evaluate every layer:

| Gate layer | What passes it | Required when |
|------------|----------------|---------------|
| Automated suite green | Full suite passes with zero tests skipped-or-quarantined-because-flaky counted as a pass — a skipped test is an unevaluated gate. Writing/fixing the automated tests themselves → wiki/testing/ | Every release |
| Smoke test | Short scripted walkthrough (≤15 min) of the top user-critical flows, run on the release build in the release environment — not on a developer branch build | Every release |
| Targeted regression | Changed areas re-tested; scope derived per [qa-process-regression-scope] | Every release with non-trivial changes (more than config values, copy, or a one-line covered fix) |
| Exploratory session | Chartered session on each new feature per [qa-exploratory-exploratory-sessions] | Feature releases |
| Rollback available | The rollback path for this release is verified usable before shipping (rollback mechanics → wiki/infrastructure/) | Every release |

Record exactly one of three outcomes in writing:

| Outcome | Condition |
|---------|-----------|
| Ship | Every required gate layer passed |
| Ship with known issues | Gates surfaced defects; each known issue is explicitly accepted by its owner and listed in the release notes |
| Block | A required gate failed and the failure is neither fixed nor owner-accepted |

There is no fourth outcome: an issue nobody accepted in writing blocks the
release.

## Edge cases

| Case | Then |
|------|------|
| Urgent hotfix, no time for the full gate | Run automated suite + smoke test + targeted regression on the fixed area + rollback check; drop only the exploratory layer. Time pressure narrows regression scope, never the smoke test or rollback check |
| A test fails and someone says "that one is just flaky" | Treat the run as red until the test is either fixed or formally quarantined with an owner and a tracking issue — a silently skipped flaky test converts the gate to "probably fine" |
| No pre-production environment matches production | Run the smoke test on the release build wherever it deploys first (canary/flagged slice), and gate full rollout on that smoke result |
| Release contains only reverts back to a previously shipped state | Automated suite + smoke test still required; targeted regression scope = the reverted areas |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Skip the smoke test because the diff "looks safe" | Run the fixed gate checklist unchanged | The gate exists because "looks safe" is exactly when regressions ship — the checklist is fixed so the safe-looking release gets the same scrutiny as the scary one |
| Ship on an unwritten "probably fine" | Record ship / ship-with-known-issues / block, with each known issue owner-accepted and in the release notes | An unwritten decision has no owner; when the issue bites, nobody agreed to it |
| Declare the suite green while flaky tests are skipped | Fix or formally quarantine (owner + tracking issue) before counting the layer as passed | Skipped-because-flaky tests hide exactly the intermittent failures that reach users |

## Sources

- https://sre.google/sre-book/release-engineering/ — releases gated by fixed, repeatable, policy-enforced process rather than per-release judgment
