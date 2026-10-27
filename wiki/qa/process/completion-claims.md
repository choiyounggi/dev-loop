---
id: qa-process-completion-claims
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/obra/superpowers
  - https://docs.claude.com/en/docs/test-and-evaluate/strengthen-guardrails/reduce-hallucinations
  - "Field case 2026-10-11 (dev-loop knowledge-flush: a PR body's URL-check count recounted from the session's own loop output)"
  - https://testanything.org/tap-version-14-specification.html
  - https://bats-core.readthedocs.io/en/latest/usage.html
last_verified: 2026-10-27
related: [debugging-methodology-verify-the-fix, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, testing-quality-tests-that-cannot-fail, qa-process-release-gates, testing-quality-mutation-harness-file-custody, infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge, infrastructure-agent-orchestration-verify-command-in-a-worker-brief, testing-strategy-real-cli-spot-check-for-new-execution-paths, infrastructure-agent-orchestration-gate-evidence-exit-code-class, qa-deliverables-quantitative-claims-in-a-published-document]
---

# Claiming Work Is Done, Fixed, or Passing

## When this applies

About to report completion, success, or a green status — to a human, a
coordinator, a PR description, or a commit message; about to write "should
work now", "probably fixed", or "tests pass" without a run in front of you; about
to repeat a count an agent, a worker or a script reported about its own run ("24
of 24 URLs returned 200") in a PR body, report, blog post or wiki page.

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
| "That stage is healthy — its existing test passes" | The test's last assertion lies past the point where the symptom appears (it waits for, or reads, the state that goes wrong) | A green test whose assertions stop before the symptom: a pump test that awaits events 1–2 says nothing about event 3 ([debugging-methodology-reproduce-first]) |
| "Feature works" | The feature executed end-to-end with its observable output | A clean build; unit tests of the parts |
| "Worker/subagent finished its task" | Its diff and artifacts inspected per [infrastructure-agent-orchestration-control-signals-vs-primary-artifacts] | The worker's own completion report |
| "N of N passed", "24 of 24 URLs returned 200" — a count taken from an agent's, a worker's or a script's own summary and repeated in a PR body, report, blog post or wiki page | Your own recount over the raw output that produced it (the runner's summary line, the loop's per-item lines), with the denominator named: which items were counted and which were excluded | The summary figure — its writer can miscount or move the denominator (sources vs. every URL in the diff), and a well-formed number passes review as a measurement |
| "Regression test added" | The red-green flip: test fails with the fix reverted, passes with it ([testing-quality-tests-that-cannot-fail]) | A test written once and seen green once |
| "Gate ledger row is `[x] MET` with `EVIDENCE: exit=0`" and the CHECK command matches a test runner's console text | Your own re-run of the exact CHECK command in the executor's cwd and with the executor's tool version, output read to the end | The checkbox and the recorded exit code — a CHECK that greps runner text (`Tests 1 passed`) passes or fails on the reporter's wording and spacing, and a `-t` filter that matches nothing exits 0 with `skipped`; a re-run from a different cwd (repo root instead of `server/`) fails a correct ledger for the same reason |
| "The auditor mutated files and restored them" (a test-quality auditor or any delegated agent that ran mutation testing on your uncommitted tree) | Your own byte comparison of the tree against a patch saved before delegating — `git diff > pre-audit.patch` before, `diff <(git diff) pre-audit.patch` after — plus a fresh suite run with the pre-audit total | The agent's "restored" sentence; a clean `git status --porcelain`, which an untracked file shows whether restored or destroyed ([testing-quality-mutation-harness-file-custody]) |

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
| The CHECK you are re-running depends on a runner's exact summary line | Re-run in the executor's cwd with the executor's runner version and compare the summary line byte for byte before judging either side; a version bump or a zero-match filter changes the wording while the exit code stays 0, and the mistake runs in both directions (the worker assumed the text, the reviewer assumed the cwd) |
| A gate or monitor reads a runner's output file that may still be written (a backgrounded suite, a `tee`d log); the runner prints its TAP plan `1..N` before any result (bats does) | Mark the gate met only when the finished-result count equals the planned total — `grep -c '^ok '` equals N from `1..N` — and the `not ok` count is 0; until then report "running, k of N". A leading plan is written before the results, so "plan present + 0 `not ok`" already holds after the first test (field case: MET recorded at 55/1731) |
| The proving run is green but its total dropped from the baseline | Read a dropped total as a lost module or import, not a pass — compare totals before claiming ([testing-quality-tests-that-cannot-fail]) |
| The raw output behind a relayed count is gone, or the count cannot be rebuilt from it | Publish the output lines (or the per-item list) in place of the count and state that the count was not reproduced — the lines are the measurement, a number without them is a claim ([qa-deliverables-quantitative-claims-in-a-published-document] for counts in a published document) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write "everything works now" after a round of edits | Run the proving command and paste its result | Edits change code; only execution changes knowledge |
| Relay a subagent's "task completed successfully" | Inspect its diff and artifacts, then report what you saw | Self-reports over-claim systematically; artifacts cannot |
| Copy "24 of 24 returned 200" from a worker's or an earlier run's report into the PR body | Recount from the loop's lines and name the denominator; when the lines are gone, paste what exists and say the count is unreproduced | The figure is formatted like a measurement, so review passes it; only the lines can be re-counted |

## Sources

- https://github.com/choiyounggi/linkly-crew/pull/10 — field reproduction 2026-09-02: `core.rs:426-431` waited for `RunStarted` + `SpecReady` and was cited as "core is fine"; the app stopped exactly after `SpecReady`, so the evidence ended where the symptom began, and a whole run proceeded on that premise until a test asserting `TaskStateChanged` + message after `SpecReady` reproduced it
- https://github.com/obra/superpowers — verification-before-completion skill: fresh-evidence gate, claim/evidence table, hedge-word red flags, distrust of delegated self-reports; field-tested across agentic coding sessions
- https://docs.claude.com/en/docs/test-and-evaluate/strengthen-guardrails/reduce-hallucinations — "Verify with citations: Make Claude's response auditable by having it cite quotes and sources for each of its claims. You can also have Claude verify each claim by finding a supporting quote after it generates a response. If it can't find a quote, it must retract the claim."
- https://git-scm.com/docs/git-checkout — `git checkout -- <path>` replaces the file with the index version and discards unstaged changes; an auditor that runs it on your uncommitted work has discarded that work until its restore lands
- Local reproduction 2026-09-27 (vitest 2.1.9, Node 26.7.0): `npx vitest run` on one passing test prints `Tests  1 passed (1)` — two spaces after `Tests`, so a CHECK grepping the single-spaced `Tests 1 passed (1)` never matches a genuine pass; `npx vitest run -t nomatch` prints `Tests  1 skipped (1)` and exits 0
- Field evidence 2026-09 (dev-loop orchestration, task t2-browser-lifecycle, reviews r1 F1 and r2): the worker's ledger CHECK assumed the `Tests 1 passed (1)` wording and a `-t` filter; the coordinator's re-check ran from the worktree root instead of `server/` and marked a correct ledger failed; the gate returned 0 once re-run in the executor's cwd
- Field reproduction 2026-08-18 (dev-loop task lo-t1-teardown): the test-quality auditor reported running `git checkout --` on `safe-cleanup.sh` during mutation testing and restoring it with `git apply`; the implementing session's own `diff <(git diff) <pre-audit patch>` was byte-identical and `bats tests/safe-cleanup.bats` re-ran 44/44 — that, not the auditor's sentence, established the restore
- Field case 2026-10-11 (dev-loop knowledge-flush; recounted on 2026-10-11 from the session transcript): the body of PR choiyounggi/dev-loop#270 states "24 of 24 distinct source URLs returned HTTP 200" and calls "the 8 remaining URLs in the diff" fixtures; the session's only URL check (the one Bash call whose command contains `http_code`; the session spawned no subagent) printed 32 lines, 21 `200` and 11 `000`, and the first "24 of 24" in the transcript is the run's own report text, not tool output; every `000` line is a host-disguise fixture (`a.example.com@evil.test` and the like) and two `200` lines (`https://example.com/`, `https://evilexample.com/`) are fixtures from the same page, so the output supports "19 source URLs, all 200", not 24 of 24
- https://testanything.org/tap-version-14-specification.html — the plan appears exactly once, "either before any Test Point lines, or after all Test Point lines"; it exists to guard against truncated output, so a leading plan says how many results will follow, not that they have arrived
- https://bats-core.readthedocs.io/en/latest/usage.html — bats's TAP output examples print the `1..N` plan line before the `ok` lines, and bats defaults to TAP when stdout is not a terminal (a redirected log)
- Field case 2026-10-27 (dev-loop orchestration, task t1-trust-select): a gate-check over a backgrounded bats run's `full.out` recorded the "plan line + 0 failures" gate MET while 55 of 1731 tests had run; tightened to `grep -c '^ok '` = 1731, it stayed unmet until the run finished (1731 ok, 0 not ok)
