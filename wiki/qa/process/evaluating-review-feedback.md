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
  - https://github.com/choiyounggi/dev-loop/pull/164
  - https://pitest.org/quickstart/basic_concepts/
  - https://mutants.rs/using-results.html
last_verified: 2026-09-28
related: [qa-process-defect-class-resweep-after-review, qa-process-adversarial-change-review, qa-process-llm-review-pipelines, testing-quality-surviving-mutant-equivalence-triage, qa-process-fresh-context-code-review]
---

# Acting on Code Review Feedback

## When this applies

Review findings arrived — from a human, a bot, or a reviewer agent — and you
are deciding what to implement; a finding is unclear; a reviewer proposes new
robustness or supporting features; you disagree with a finding; a reviewer or
test-quality auditor returned PASS while its body records an observation it
did not count as a defect (a surviving mutant, an uncovered guarantee).

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
| A CI fact-checking review agent rules a claim "fabricated" because it cites a preview-gated or environment-local tool the runner cannot see | Split the verdict: accept the verifiability half (downgrade confidence to the experience tier, add public fetchable URLs, condition the directive on the tool being present in the session's roster) and refute the existence half with ground-truth evidence (roster listing, on-disk payload) in a PR comment |
| The verdict line is PASS and the body notes "this mutant survived" / "not covered, secondary" | PASS is scoped to the reviewer's FAIL list, not to coverage, and the reviewer classified the guarantee from whatever copy of the requirements it was handed. Map each surviving mutant to the brief's own requirement list: a guarantee the brief states literally is a missing test whatever label the reviewer gave it ([testing-quality-surviving-mutant-equivalence-triage] missing-test row) — add the case that kills it, then resume the same reviewer and have it reproduce the kill before treating the PASS as covering that guarantee |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Implement findings top-to-bottom as you read | Read all, verify all, then fix in dependency order | Later findings change what the earlier fixes should be |
| Reply "You're absolutely right!" and start editing | Verify the claim against the code, then let the fix speak | Performative agreement commits you before verification, and adds noise for the next reader |
| Build the "proper" version a reviewer sketched | Grep for real usage first; propose removal when unused | Unused robustness is dead weight that still has to be maintained and reviewed |
| Rebut an unanchored finding because the file you assumed does not contain the quoted code | Grep the quoted string across the changed set, then rule against the file it resolves to | A body-level finding names no file; rebutting from the wrong file rejects a real defect with an argument that looks verified |
| Fight a CI reviewer's whole "fabricated" verdict, or weaken true content to satisfy it | Accept the verifiability half and refute only the existence half with ground-truth evidence in the reply | The reviewer's environment is a different trust domain — absence there is not absence everywhere, but an un-fetchable source still fails a sourcing gate on its own terms |
| Read the `VERDICT: PASS` line and move on | Read the body's observations as findings and map every surviving mutant to the brief's requirement list | A surviving mutant is the tool's own statement that no test detects that change (PIT "Survived", cargo-mutants "missed"); the verdict only says none of the reviewer's FAIL conditions fired |

## Sources

- https://github.com/obra/superpowers — receiving-code-review skill: verify-before-implementing, clarify-all-before-any, performative-agreement ban, YAGNI usage check; field-tested across agentic coding sessions
- https://google.github.io/eng-practices/review/reviewer/standard.html — technical facts and data overrule opinions and personal preferences
- https://google.github.io/eng-practices/review/reviewer/looking-for.html — reviewers guard against over-engineering: solve the known problem, not the speculated future one
- Field measurement 2026-08-19 (PR #327, round 16): a bot's body-level finding quoted `label = r.get("key") if _nonempty_str(...)` with no file. The assumed file, `fill_plan.py:307`, already wrapped the call as `_label(x.get("key"))`, which read as a false positive. Grepping the quoted shape across the sibling modules resolved it to `report.py:393/416/425`, an exact match and a real defect — the two files implement the same contract and only one had been fixed
- https://github.com/choiyounggi/dev-loop/pull/164 — "docs(wiki): mandatory design-skill routing for visual-design deliverables" (merged, public); the PR whose agent gate flipped fail→pass after the split-verdict remediation
- Field evidence 2026-08-30 (dev-loop PR #164, commit `f5d2395` "fix(wiki): remediate agent-gate Check 3 on design-canvas-workflow"): the gate's "skill does not exist" finding was refuted with the authoring session's skill roster (the reviewer had conflated the preview `design` skill with `/design-sync`) while the un-fetchable-source half was accepted by downgrading confidence and adding public URLs; the gate passed on the next run
- https://pitest.org/quickstart/basic_concepts/ — "Survived: the mutation was not detected by the covering test": the survivor is a coverage statement independent of any reviewer's verdict scope
- https://mutants.rs/using-results.html — "missed — No test failed with this mutation applied, which seems to indicate a gap in test coverage"
- Local reading 2026-09-28 (this repo, `agents/test-quality-auditor.md`): the auditor's contract lists the FAIL conditions (no assertion, disabled cases, uncovered changed behavior, rubber-stamping, the case-count floor) and emits `VERDICT: PASS | FAIL` with one line of justification on PASS — coverage of every stated guarantee is not among the FAIL conditions, so a PASS body can carry a surviving mutant without contradiction
- Field evidence 2026-09 (a Rust `serde` wire-format crate, crew-proto task t5-proto; recorded by the originating session, not re-run in this flush): the auditor returned PASS and noted that a `deny_unknown_fields` mutant survived all 12 tests, classifying the guarantee as secondary; the brief's `<i_produce>` stated "unknown fields tolerated" literally. Adding `unknown_entry_fields_are_tolerated` took the file to 13 tests; under the mutant it read `FAILED`, and a `.rev()` mutant on sibling ordering failed `malformed_entry_is_dropped_and_valid_sibling_kept`; restored → 82 passed; the resumed auditor reproduced both kills and returned PASS
