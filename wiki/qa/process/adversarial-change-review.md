---
id: qa-process-adversarial-change-review
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/EveryInc/compound-engineering-plugin
last_verified: 2026-08-22
related: [qa-process-evaluating-review-feedback, qa-process-regression-scope, qa-process-post-release-verification, infrastructure-agent-orchestration-inbound-validation-ownership-in-task-decomposition]
---

# Constructing Failure Scenarios for a High-Risk Diff

## When this applies

Reviewing a diff that is large (≥50 changed lines) or touches auth, payments,
data migrations, or external-API consumption; a checklist review returned
nothing on a change whose blast radius is high; deciding how deep a review
must go before merge.

## Do this

1. Set the depth from the diff, before reviewing:

| Diff | Review depth |
|------|--------------|
| <50 changed lines, no high-risk domain | Standard checklist review only |
| 50–199 lines, or one minor risk signal | Techniques 1–2 below |
| ≥200 lines, or any auth/payment/migration/money path | All four techniques, with multi-step traces |

2. Construct scenarios with the four techniques — each produces concrete
   inputs traced through the code, not pattern labels:

| Technique | Construct |
|-----------|-----------|
| 1. Assumption violation | List the diff's data-shape, timing, ordering, and value-range assumptions; build one violating input per assumption and trace it through |
| 2. Composition failure | Pair components that are correct alone: contract mismatches at their boundary, shared state mutated without coordination, thrower/catcher error-type divergence |
| 3. Cascade construction | Chain failures across steps: timeout → retry → added load → more timeouts; partial write → wrong downstream decision → compounding corruption; recovery that fails (a retry duplicating a side effect, a rollback stranding state, a circuit breaker blocking its own recovery probe) |
| 4. Abuse cases | Legitimate-looking misuse: the 1000th identical submission, a request landing mid-deploy or mid-cache-invalidation, two actors racing one resource, inputs walking the exact boundary (max size, exactly at the rate limit) |

3. Name each finding as a scenario — input/state → consequence ("payment
   timeout triggers unbounded retry loop") — a scenario can be checked and
   reproduced; a pattern label cannot.
4. Route adversarial findings to human judgment rather than autofix, and
   confirm a scenario (run it, or trace it with line references) before it
   blocks a merge; label unconfirmed scenarios with their confidence.

## Edge cases

| Case | Then |
|------|------|
| A scenario needs prod-only conditions to trigger | Record it as a post-release monitoring item with the signal to watch ([qa-process-post-release-verification]) |
| All four techniques return nothing on a high-risk diff | State the null result with what was searched (techniques × assumptions listed) — a stated null and an omitted one read the same to the merge decision, so state it |
| The diff is high-risk and also very large | Partition by risk surface (auth paths first, then money paths) and run the techniques per partition, so depth lands where the blast radius is |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Clear a payment/auth diff with a style-and-correctness checklist alone | Run the four techniques at the depth the table sets | Checklists find known single-point patterns; constructed scenarios find interactions between correct-looking parts |
| Report "potential race condition" as a finding | Construct the interleaving: which two operations, which shared state, what wrong outcome | An unconstructed finding cannot be verified, prioritized, or fixed |

## Sources

- https://github.com/EveryInc/compound-engineering-plugin — adversarial-reviewer persona: depth calibration by size/risk, the four scenario-construction techniques, scenario-oriented finding titles, advisory-to-human routing; field-tested in the plugin's shipped review workflow
