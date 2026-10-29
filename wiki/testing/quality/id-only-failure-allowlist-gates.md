---
id: testing-quality-id-only-failure-allowlist-gates
domain: testing
category: quality
applies_to: [general]
confidence: field-tested
sources:
  - "Field reproduction 2026-10-29 (dev-loop orchestration, task orch-r268-t5): classify_failures.py and two planted negative-control runs under .claude/tmp/t5/classify-neg/"
last_verified: 2026-10-29
related: [testing-quality-checks-that-cannot-pass, testing-quality-harness-reverse-controls, testing-quality-surviving-mutant-equivalence-triage, qa-process-regression-scope]
---

# A Gate That Allows Known Test Failures by Id Alone

## When this applies

A gate judges a changed test suite's new failures by matching each failing
test's id (or its module/file) against an allowed list — a known-flaky
table, an "expected to fail in this PR" list, a baseline-diff that compares
only failure identifiers — and nothing else about the failure.

## Do this

1. **Require the failure's own cause text to match the expected cause for
   that id, not only the id.** Record, alongside each allowed id, the
   substring or pattern its traceback/error message must contain (the
   assertion line, the exception type, the message). A failure is "allowed"
   only when both the id and the cause text match.
2. **Prove the classifier with two planted bad cases before trusting it**,
   mirroring the known-good/known-bad proof in
   [testing-quality-checks-that-cannot-pass]:

| Planted case | Must produce |
|--------------|--------------|
| An unrelated failing test outside any allowed id/module | Reported as a real, unclassified failure |
| An allowed id whose failure output has had its expected cause text removed or changed | Reported as a real, unclassified failure — not silently waved through because the id matched |

3. **Fail closed on an unparseable failure report.** A failure whose
   traceback the classifier cannot extract text from is unclassified, not
   allowed — the same "target missing vs. content missing" split
   [testing-quality-checks-that-cannot-pass] applies to grep-based gates.

## Edge cases

| Case | Then |
|------|------|
| The allowed list is a whole module/file, not individual test ids | The cause-text requirement still applies per failing test inside that module; a module-wide pass that skips the per-test check is an id-only gate at a coarser grain |
| The expected cause text is itself a regex with metacharacters | Match it as a fixed string (`grep -F` or equivalent) unless the pattern is deliberately a regex, and say which in the allowlist entry — an unescaped bracket/dot in a literal error message silently widens what counts as "the same cause" |
| A flaky test's cause legitimately varies run to run (timeout vs. assertion) | List every cause variant the flake is known to produce, and require the observed failure to match one of them, not an open-ended "this id is known flaky" |
| The suite reports failures in a format the classifier has never parsed (a new runner, a new verbosity flag) | Treat it as unclassified until the parser is extended and re-proven with the two planted cases, not as implicitly allowed |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Allow a new failure because its test id is in a known-flaky or expected-failure list | Also require its cause text to match what that id is allowed to fail with | An id-only allowlist passes *any* new failure inside an allowed module or id, so a real regression with an unrelated cause is indistinguishable from the expected failure and slips through silently |
| Trust a failure classifier because it printed the right verdict on the real run | Plant an unrelated failure and a cause-stripped allowed failure and require both to come back unclassified | A classifier that has only ever been run on inputs it correctly allows has not demonstrated it can also reject |

## Sources

- Field reproduction 2026-10-29 (dev-loop orchestration, task orch-r268-t5): `classify_failures.py` printed `CLASSIFY_OK` on the real run; two planted bad outputs under `.claude/tmp/t5/classify-neg/` (an unrelated failing test, and an allowed id with its cause text removed) each produced exactly one `UNCLASSIFIED` line, confirming the classifier rejects both when cause text is required alongside the id
