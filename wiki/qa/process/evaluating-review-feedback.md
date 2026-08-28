---
id: qa-process-evaluating-review-feedback
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/obra/superpowers
  - https://google.github.io/eng-practices/review/reviewer/standard.html
  - https://google.github.io/eng-practices/review/reviewer/looking-for.html
last_verified: 2026-08-27
related: [qa-process-defect-class-resweep-after-review, qa-process-adversarial-change-review, qa-process-llm-review-pipelines]
---

# Acting on Code Review Feedback

## When this applies

Review findings arrived — from a human, a bot, or a reviewer agent — and you
are deciding what to implement; a finding is unclear; a reviewer proposes new
robustness or supporting features; you disagree with a finding.

## Do this

1. Read every finding before changing anything, and restate each in your own
   words — implementing while reading optimizes the first finding at the
   expense of the ones coupled to it.
2. Verify each finding against the code before editing: open the cited lines
   and confirm the defect exists and the suggestion is correct for this
   codebase — reviewers, human and agent alike, work from partial context.
3. When any finding is unclear, get every unclear finding clarified before
   implementing any of them — related findings implemented from partial
   understanding produce fixes that contradict each other.
4. When a reviewer proposes supporting code ("handle X properly", "make this
   configurable"): search for actual usage first; when nothing uses the
   capability, propose removing the dead surface instead of building it —
   solve the problem that exists now, not the speculated one.
5. On disagreement, push back with evidence — cited code, observed behavior, a
   failing case — and accept the resolution; technical facts and data override
   opinion in both directions.
6. Implement in this order: clarifications → correctness-blocking findings →
   simple fixes → complex fixes; test each finding's fix individually before
   moving to the next.
7. Acknowledge with the fix itself: the commit or reply states what changed
   and why. Replace agreement or praise phrasing ("great catch!") with that
   statement — the fix carries the information; the phrase does not.
8. When your fix wave adds new code, re-sweep the whole diff for the same
   defect class per [qa-process-defect-class-resweep-after-review].

## Edge cases

| Case | Then |
|------|------|
| You pushed back and turn out to be wrong | State the correction factually and implement the fix — the correction is the apology |
| Two findings conflict with each other | Surface the conflict to the reviewer(s) and get a resolution before implementing either |
| A reviewer agent flagged pre-existing code outside the diff | Verify it, then file it as separate work — expanding the current change silently mixes concerns for every later reader |
| The finding sits in the review **body** rather than an inline comment, so it quotes code without naming a file | Step 2 has no cited lines to open: grep the quoted string across the whole changed set before ruling on it, and rule only against the file the grep resolves it to |
| The quoted code does not match the file you assumed, and sibling files implement the same contract | Read it as "not yet located", not as a false positive — the usual shape is that one sibling was already fixed and another still carries the defect, so the quote matches the file you did not check |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Implement findings top-to-bottom as you read | Read all, verify all, then fix in dependency order | Later findings change what the earlier fixes should be |
| Reply "You're absolutely right!" and start editing | Verify the claim against the code, then let the fix speak | Performative agreement commits you before verification, and adds noise for the next reader |
| Build the "proper" version a reviewer sketched | Grep for real usage first; propose removal when unused | Unused robustness is dead weight that still has to be maintained and reviewed |
| Rebut an unanchored finding because the file you assumed does not contain the quoted code | Grep the quoted string across the changed set, then rule against the file it resolves to | A body-level finding names no file; rebutting from the wrong file rejects a real defect with an argument that looks verified |

## Sources

- https://github.com/obra/superpowers — receiving-code-review skill: verify-before-implementing, clarify-all-before-any, performative-agreement ban, YAGNI usage check; field-tested across agentic coding sessions
- https://google.github.io/eng-practices/review/reviewer/standard.html — technical facts and data overrule opinions and personal preferences
- https://google.github.io/eng-practices/review/reviewer/looking-for.html — reviewers guard against over-engineering: solve the known problem, not the speculated future one
- Field measurement 2026-08-19 (PR #327, round 16): a bot's body-level finding quoted `label = r.get("key") if _nonempty_str(...)` with no file. The assumed file, `fill_plan.py:307`, already wrapped the call as `_label(x.get("key"))`, which read as a false positive. Grepping the quoted shape across the sibling modules resolved it to `report.py:393/416/425`, an exact match and a real defect — the two files implement the same contract and only one had been fixed
