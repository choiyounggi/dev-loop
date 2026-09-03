---
id: infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: verified
sources:
  - https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
  - https://git-scm.com/docs/git-check-ignore
last_verified: 2026-09-03
related: [qa-deliverables-quantitative-claims-in-a-published-document, qa-document-verification-spec-document-gates, infrastructure-agent-orchestration-autonomous-decision-rulings, infrastructure-agent-orchestration-unattended-worker-questions]
---

# Numeric Claims and Symbol Contracts in a Plan You Did Not Write

## When this applies

A task in an orchestrated run adopts a plan authored by a coordinator or a
planning skill (the "plan already exists" path) and that plan states derived
numbers your tests will encode (contrast ratios, a monotonic ordering, hex
arithmetic), a fixed enumerated symbol set other tasks also consume, or a
deliverable file downstream tasks must read; the plan describes itself as
measured or verified.

## Do this

1. **Recompute every derived number from the plan's own fixed inputs before
   writing a test that asserts it.** For colors, re-derive WCAG relative
   luminance from the hex codes and the contrast ratio `(L1 + 0.05) / (L2 +
   0.05)`; for orderings, sort the recomputed values and compare position by
   position. The prose "measured" is a claim, the recomputation is the check.
2. **Check the declared symbol contract for collisions across its own rows**:
   a new canonical name against every "keep as deprecated alias" name, and each
   task's slice against the neighbouring slices — a duplicate is a compile error
   only once both sides land.
3. **Check that each decision the plan records as made has an enactment**: grep
   the rule file or page the decision→page map names for the decision's effect.
4. **Check that a cross-task deliverable file reaches its audience by the
   mechanism the audience uses**: for a file other tasks read from git, run
   `git check-ignore -v <path>` and require no match; for a generated file, run
   the generator and diff.
5. **Escalate every discrepancy through the run's blocking-question channel
   ([infrastructure-agent-orchestration-unattended-worker-questions]) and wait**,
   even when the fix is obvious: the plan is shared input, so a silent correction
   in your task leaves every other task building on the defect.

| Finding | Do |
|---------|----|
| Recomputed values agree with the plan | Record "recomputed, agrees" in the task report and proceed |
| A number, ordering, or collision disagrees | Escalate with the recomputation attached; do not encode either value in a test until the plan owner rules |
| A deliverable is gitignored or a decision has no enactment | Escalate as a plan defect; it blocks every consumer, not only you |

## Edge cases

| Case | Then |
|------|------|
| The discrepancy is confirmed and fixed on the plan side | Record it as a ruling in the run ledger ([infrastructure-agent-orchestration-autonomous-decision-rulings]) so the next worker reading the same paragraph sees the correction |
| The plan's numbers came from a tool you can also run | Run the tool on the plan's inputs; a tool the plan author ran by hand once is the same claim as prose |
| The plan pre-approves silent correction of arithmetic | Correct it, cite the pre-approval in the ruling, and still report the original value alongside |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert a plan's stated contrast ratio in a test because the plan says "measured" | Recompute it from the hex codes first | Internally consistent prose still carries arithmetic errors, and the test would pin the wrong value |
| Trust "the contract file is committed" from the plan's checklist | Run `git check-ignore -v` on the path | An ignored file passes every check its author ran and is invisible to every fresh clone |
| Rename your task's symbol to dodge a collision the plan missed | Escalate before renaming | Downstream tasks planned around the plan's names; a local rename fixes your build and breaks theirs |

## Sources

- https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html — relative luminance `L = 0.2126 * R + 0.7152 * G + 0.0722 * B` with the sRGB companding step; contrast ratio `(L1 + 0.05) / (L2 + 0.05)` with L1 the lighter colour
- https://git-scm.com/docs/git-check-ignore — checks "whether the file is excluded by .gitignore … and output the path if it is excluded"; `-v` prints the matching exclude pattern with the path
- Field evidence 2026-08-25 (wt-t1-foundation, coordinator-authored design-system plan): recomputing WCAG luminance from the plan's hex codes showed the neutral scale's stated monotonic ordering broke at 2 of 11 positions while every pairwise ratio was correct; two new canonical symbol names duplicated names marked "keep as deprecated alias" (a Swift duplicate-declaration error); one decision in the plan's decision→page map had no enacted rule; `git check-ignore -v DESIGN.md` matched a pre-existing rule, hiding the core deliverable from every downstream task. All four were escalated and fixed on the plan side
