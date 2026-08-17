---
id: infrastructure-deploy-feature-flag-lifecycle
domain: infrastructure
category: deploy
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/feature-toggles.html
last_verified: 2026-08-17
related: [infrastructure-deploy-rollout-and-rollback]
---

# Managing a Feature Flag from Introduction to Removal

## When this applies

Adding a flag/toggle to gate a feature — deciding what kind of flag it is,
how long it should live, and who removes it. [infrastructure-deploy-rollout-and-rollback]
covers the mechanics of a gated rollout (canary, health-gated promotion); this
page covers the flag itself as an artifact with its own lifecycle, since an
unmanaged flag outlives the reason it was created.

## Do this

| Flag category | Expected lifetime | Do |
|----------------|-------------------|----|
| Release toggle (hide incomplete work, ship trunk-based) | Days to a couple of weeks | Add a removal task to the backlog at the same time the flag is introduced — once the feature is fully rolled out, the flag and both code branches it guarded should be deleted in the same change |
| Experiment toggle (A/B test, cohort routing) | Until the experiment reaches statistical significance | Name it with the experiment, not the feature, so it's obviously tied to a decision that concludes; remove it (keeping the winning branch) once the experiment is decided |
| Ops toggle (kill switch, load-shedding) | Long-lived by design | Document it as a permanent operational control, not debt — but still name and inventory it so an incident responder can find it |
| Permissioning toggle (per-plan/per-tenant feature access) | Long-lived by design (can be years) | Treat it as a first-class authorization concern, not a temporary toggle — route the check through the same place other entitlement checks live, not an ad hoc flag lookup |

## Deciding on cleanup

| Situation | Do |
|-----------|----|
| A release or experiment toggle has been fully rolled out | Remove the flag and the losing code path in the same PR that confirms rollout — do not leave a "temporary" flag live past the decision that made it temporary |
| You don't know how many flags currently exist in the system | Keep an inventory (flag name, category, owner, creation date) — treat flags as inventory with a carrying cost, and periodically audit it against what's still gating live decisions |
| A flag is checked in more than a handful of places | That is a signal the flag has outlived a single-decision scope — split it (e.g. one config value read once at a boundary) rather than letting call sites accumulate |

## Edge cases

| Case | Then |
|------|------|
| Removing a flag would delete the *disabled* branch, but you're not fully sure it's safe | Flip the flag to fully-on in production first, observe, then remove the flag and dead branch as a separate, easily revertible change |
| A flag is checked inside a hot path (e.g. per-request) | Cache/precompute the flag's evaluated value per request or per deploy, rather than re-evaluating a remote flag service on every call |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add a release/experiment flag with no plan for when it comes out | Add its removal to the backlog when you add the flag, or set an explicit expiration | Toggles multiply, and each live toggle multiplies the number of code paths that must be tested together |
| Let a release toggle become the permanent way a feature is enabled/disabled | Convert it to config/permissioning explicitly, or remove it and always-enable the code | A toggle meant to be transitional that never gets removed accumulates as untracked technical debt indistinguishable from a permanent flag |

## Sources

- https://martinfowler.com/articles/feature-toggles.html — flag category taxonomy (release/experiment/ops/permissioning), toggle-as-inventory framing, removal-task-on-introduction practice
