---
id: infrastructure-ci-cd-write-time-limit-guards
domain: infrastructure
category: ci-cd
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/apiserver/pkg/admission/plugin/resourcequota/controller.go
  - https://kubernetes.io/docs/concepts/policy/resource-quotas/
  - https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#validation-ratcheting
  - https://eslint.org/docs/latest/use/suppressions
last_verified: 2026-09-17
related: [backend-common-change-impact-corpus-sweep-before-a-rejection-rule, infrastructure-ci-cd-changed-files-only-gates, infrastructure-agent-orchestration-session-completion-gates]
---

# Write-Time Limit Guards Over a State That Already Exceeds the Limit

## When this applies

You are building or reviewing a guard that rejects a write when the result
would exceed a budget, quota, or size limit — an editor/agent hook, a
pre-commit or pre-receive check, an admission controller, an upload validator.
Also when such a guard blocks every write to a resource, including the write
that would bring it back under the limit.

Introducing a brand-new rejection rule over an existing corpus →
[backend-common-change-impact-corpus-sweep-before-a-rejection-rule].

## Do this

1. **Reject on two conditions joined by AND: the result exceeds the limit, and
   the result is larger than the current state.** `deny = after > limit AND
   after > before`. A write that shrinks or holds the measured quantity passes
   whatever the current state is.

2. **Measure `before` from the stored state at decision time**, in the same
   unit and with the same function as `after` (bytes with bytes, rule count
   with rule count). A `before` taken from a cache or a different counter turns
   the direction test into a second, disagreeing limit.

3. **Evaluate every limited quantity on its own.** With two limits (bytes and
   item count), deny when any quantity both exceeds its limit and grew; a write
   that shrinks bytes and grows an over-limit count is still denied.

4. **Put the recovery path in the denial message**: current value, limit,
   attempted value, and the statement that a smaller result is accepted. The
   reader of that message is deciding between fixing the state and disabling
   the guard.

5. **Test from an over-limit starting state.** The suite needs four cases:
   under → under passes, under → over is denied, over → smaller-but-still-over
   passes, over → larger is denied. The third case is the one a limit-only
   guard fails.

| Guard input | Compute `after` by |
|-------------|--------------------|
| Whole-content write (file replace, object PUT) | Measuring the submitted content |
| Patch-shaped write (string replacement, JSON patch) | Applying the patch to the stored content in memory, then measuring |
| Patch whose exact result the guard cannot reproduce (replace-all, server-side merge) | An approximation whose sign is exact: `before − len(old) + len(new)` per replaced occurrence, using the occurrence count the edit actually performs (zero matches means zero delta), keeps the grew/shrank verdict correct even when the magnitude is off |

## Edge cases

| Case | Then |
|------|------|
| The limit was lowered below current usage | Existing state stays; only growth is denied. Kubernetes states the same contract for quotas: changes to quota do not affect already created resources |
| The resource does not exist yet (create) | `before` is 0, so rule 1 reduces to the plain limit check |
| A write leaves the measured quantity unchanged (rename, metadata edit) | Passes — `after > before` is false. Kubernetes short-circuits admission when the usage delta of an update is zero, for each quota the previous object already matched |
| The guarded quantity is a set of violations from a linter, not a size | Same mechanism, different unit: compare sets, not counts. Record the existing violations as a baseline, deny a write that leaves any violation outside the baseline, accept a write whose violation set is a subset of it. A before/after count passes a write that removes one violation and adds a different one (ESLint bulk suppressions, CRD validation ratcheting) |
| Shrinking requires two writes whose intermediate state is larger (move content between files) | Order the writes so the removal lands first, or perform the move as one whole-content write per file |
| The guard cannot read the current state (file unreadable, API error) | Fail closed with the read error in the message; a missing `before` must not default to 0, which would deny every write to an over-limit resource |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Deny whenever `after > limit` | Deny when `after > limit AND after > before` | Once the state is over the limit, a limit-only guard blocks the edits that would fix it; the only remaining move is to disable the guard, and a disabled guard stays disabled |
| Add a bypass flag or env var for "cleanup" writes | Make direction part of the predicate | A bypass admits growth as well as shrinkage and depends on the writer remembering to unset it |
| Test the guard only from an under-limit fixture | Start two cases from an over-limit fixture | The defect exists only in the over-limit state, which an under-limit fixture never reaches |

## Sources

- https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/apiserver/pkg/admission/plugin/resourcequota/controller.go — on `Update`, quota admission charges `deltaUsage := quota.SubtractWithNonNegativeResult(inputUsage, prevUsage)`, removes zero entries, and returns without a quota check when nothing remains ("if there is no remaining non-zero usage, short-circuit and return"). The delta replaces the full usage only for a quota that `evaluator.Matches` the previous object; an update that newly brings the object into a quota's scope is charged its full usage, as on create. So a non-growing update is admitted regardless of current usage for every quota the object was already counted under (raw source read 2026-09-17)
- https://kubernetes.io/docs/concepts/policy/resource-quotas/ — "Neither contention nor changes to quota will affect already created resources."
- https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#validation-ratcheting — "The API server is willing to accept updates to resources that are not valid after the update, provided that each part of the resource that failed to validate was not changed by the update operation … You cannot use this mechanism to update a valid resource so that it becomes invalid."
- https://eslint.org/docs/latest/use/suppressions — "While the rule will be enforced for new code, the existing violations will not be reported. This way, you can address the existing violations at your own pace."
- The two-condition predicate in rule 1 is this page's statement of the mechanism the sources above implement (charge or reject only what the write adds); rules 2–5 and the patch-shaped table rest on the field evidence below
- Field evidence 2026-09-17 (`groundwork`, `habits-budget-guard.sh`, a PreToolUse hook enforcing an 8000-byte / 24-rule budget on one file): implemented with the two-condition predicate; two bats cases start from a 12000-byte over-budget file and assert that a shrinking whole-file write and a shrinking string-replacement edit both pass. An independent reviewer confirmed by hand that the replace-all length approximation keeps the grew/shrank verdict exact
