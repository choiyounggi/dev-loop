---
id: qa-process-completion-claims
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/obra/superpowers
last_verified: 2026-08-22
related: [debugging-methodology-verify-the-fix, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, testing-quality-tests-that-cannot-fail, qa-process-release-gates]
---

# Claiming Work Is Done, Fixed, or Passing

## When this applies

About to report completion, success, or a green status — to a human, a
coordinator, a PR description, or a commit message; about to write "should
work now", "probably fixed", or "tests pass" without a run in front of you.

## Do this

1. Identify the command whose output proves the claim, run it fresh against the
   state you are reporting on, read the complete output and exit code, and
   claim exactly what the output shows — a claim without a same-session run
   behind it is a prediction, and gets labeled as one.
2. Match each claim to its evidence:

| Claim | Required evidence | Not evidence |
|-------|-------------------|--------------|
| "Tests pass" | A fresh run: zero failures and the expected total count | An earlier run; "should pass"; a subset run reported as the whole suite |
| "Bug fixed" | The recorded reproduction re-run per [debugging-methodology-verify-the-fix] | "The code changed"; the symptom gone after unrelated restarts |
| "Feature works" | The feature executed end-to-end with its observable output | A clean build; unit tests of the parts |
| "Worker/subagent finished its task" | Its diff and artifacts inspected per [infrastructure-agent-orchestration-control-signals-vs-primary-artifacts] | The worker's own completion report |
| "Regression test added" | The red-green flip: test fails with the fix reverted, passes with it ([testing-quality-tests-that-cannot-fail]) | A test written once and seen green once |

3. Treat hedge words in a completion sentence — "should", "probably", "seems
   to" — as markers of an unverified claim: run the proving command, or
   downgrade the sentence to a status report naming what remains unverified.
4. Report outcomes symmetrically: failures with their output attached, skipped
   steps named as skipped — a stated failure and an omitted one read the same
   to the next reader only when both are written down.

## Edge cases

| Case | Then |
|------|------|
| Full verification is expensive (multi-hour suite) | Run the targeted subset now and name it in the claim ("auth tests pass; full suite pending"); run the full suite at the merge gate ([qa-process-release-gates]) |
| The current environment cannot run the proving command | State the claim as unverified and hand over the exact command that would verify it |
| The proving run is green but its total dropped from the baseline | Read a dropped total as a lost module or import, not a pass — compare totals before claiming ([testing-quality-tests-that-cannot-fail]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write "everything works now" after a round of edits | Run the proving command and paste its result | Edits change code; only execution changes knowledge |
| Relay a subagent's "task completed successfully" | Inspect its diff and artifacts, then report what you saw | Self-reports over-claim systematically; artifacts cannot |

## Sources

- https://github.com/obra/superpowers — verification-before-completion skill: fresh-evidence gate, claim/evidence table, hedge-word red flags, distrust of delegated self-reports; field-tested across agentic coding sessions
