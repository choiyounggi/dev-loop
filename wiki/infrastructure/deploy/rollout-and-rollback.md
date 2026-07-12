---
id: infrastructure-deploy-rollout-and-rollback
domain: infrastructure
category: deploy
applies_to: [general]
confidence: verified
sources:
  - https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
  - https://sre.google/workbook/canarying-releases/
  - https://martinfowler.com/bliki/ParallelChange.html
  - https://martinfowler.com/articles/feature-toggles.html
last_verified: 2026-07-10
related: [infrastructure-containers-image-builds, infrastructure-observability-alerting, databases-schema-design-column-data-types, databases-schema-design-naming-conventions]
---

# Rolling a Release Out — and Being Able to Roll It Back

## When this applies

Designing how a service reaches production (rollout strategy, health gating),
or preparing a risky release and deciding its rollout and rollback mechanics.

## Do this

1. Expose the new version gradually — a deploy is not a binary switch:
   - Health/readiness checks gate instance rotation: an instance receives
     traffic only after its readiness check passes, and replacement proceeds
     instance by instance.
   - Canary or percentage rollout: send a small traffic fraction to the new
     version, compare its error rate and latency against the baseline (the
     untouched control population), and roll back automatically on regression.
2. Be rollback-ready BEFORE the deploy starts:
   - Previous artifact retained and directly deployable (immutable release tags:
     [infrastructure-containers-image-builds]).
   - Rollback is one rehearsed command, not an improvisation during an incident.
   - Every DB change is backward-compatible with the previous app version,
     because rollback runs the previous app against the already-migrated schema.
3. Pick the strategy by change type:

| Change type | Strategy |
|-------------|----------|
| Stateless code change | Rolling or canary rollout with health gating |
| Schema change | Expand-contract, never lockstep app+schema in one deploy: add-new → migrate/dual-write → switch readers → remove-old in a LATER release (column type/rename mechanics: [databases-schema-design-column-data-types], [databases-schema-design-naming-conventions]) |
| Config/flag change | Runtime flag with a kill switch — disabling must not require a redeploy |
| Irreversible data migration (destructive backfill, format rewrite) | Snapshot/backup first + dry-run on prod-like data; run it separately from app deploys |

4. Use feature flags to decouple deploy from release: ship the code dark behind
   a flag, enable per cohort/percentage, disable instantly on trouble. Remove
   the flag after full rollout — leftover flags are debt that multiplies
   untested code-path combinations.

## Edge cases

| Case | Then |
|------|------|
| Canary traffic too sparse to show a regression (low-traffic service) | Lengthen canary duration or raise the canary share until the comparison has signal; add synthetic checks as a gate |
| Rollback needed after the contract step (remove-old) already ran | The app cannot roll back past the removal — this is why remove-old waits a full release cycle after switch-readers |
| Release changes a queue-message or cache-entry format | Same expand-contract discipline: every version reads both formats before any version writes the new one |
| Deploy tooling only supports all-at-once replacement | Flag-gate the behavior change so exposure is still gradual even when the binary swap is not |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Deploy app + breaking schema change in one lockstep release | Expand-contract across separate releases | The previous app version must survive against the new schema for rollback to exist |
| Verify a release by watching logs manually after 100% rollout | Canary against a baseline with automatic rollback on error/latency regression | Humans notice regressions after users do |
| Leave the feature flag in place "temporarily" after 100% rollout | Schedule flag removal as part of rollout completion | Flag debt leaves dead branches and untested combinations |
| Improvise rollback steps during an incident | Rehearse the one-command rollback before deploying | Untested rollback paths fail exactly when needed |

## Sources

- https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ — readiness checks gate whether an instance receives traffic
- https://sre.google/workbook/canarying-releases/ — canary vs control comparison, rollback on regression
- https://martinfowler.com/bliki/ParallelChange.html — expand → migrate → contract for backward-compatible change
- https://martinfowler.com/articles/feature-toggles.html — decoupling deploy from release; toggle debt and removal
