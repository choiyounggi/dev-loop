---
id: testing-quality-assertion-scanner-false-positive-on-unittest-convention
domain: testing
category: quality
applies_to: [python, general]
confidence: verified
sources:
  - https://docs.python.org/3/library/unittest.html
  - https://docs.pytest.org/en/stable/how-to/assert.html
last_verified: 2026-09-03
related: [qa-process-evaluating-review-feedback, testing-quality-checks-that-cannot-pass, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, testing-quality-harness-reverse-controls]
---

# A Regex Assertion Scanner Flagging unittest's `self.assertX` as No-Assertion

## When this applies

A test-quality floor check greps test files for bare `assert` or `pytest.raises` and
reports "no assertion" or "no error case" on a file whose convention is unittest's
`self.assertX` / `self.assertRaises`; a worker reports the floor failure and you must
decide whether to trust it, re-run it, or change the tests to satisfy it.

## Do this

1. Read the flagged file before acting on the verdict. unittest's own docs state
   its assert methods "are used instead of the assert statement" — a file with no
   bare `assert` and several `self.assertEqual` / `self.assertRaises` calls is not
   assertion-free; the scanner's pattern set does not match this repo's framework.
2. Adjudicate by running the canonical checker yourself in that worktree and reading
   its own exit code, rather than accepting a worker's report of the failure — the
   report is a control signal, the script's result is the primary artifact
   ([infrastructure-agent-orchestration-control-signals-vs-primary-artifacts]).
3. Choose the fix by where the disagreement lives:

| Finding | Do |
|---------|----|
| The canonical checker passes; only the worker's pre-check failed | Record the pre-check as a false positive and let the task proceed; no test change |
| The canonical checker also fails on a file full of `self.assertX` calls | Fix the checker's accepted pattern (add `self\.assert\w+\(` and `assertRaises`) so it matches the framework in use; leave the tests as they are |
| The file has no assertion of either form | The scanner is right — add the missing assertion that checks the behavior under test |

4. When the failures are uniform across many freshly written files, run the same
   canonical checker against an already-merged, shipped commit of the same
   convention (`git worktree add <dir> <shipped-sha>`, then the checker in that
   tree) before changing any test. The same uniform failure on reviewed, shipped
   code proves the defect is the gate's, not the diff's — the negative control a
   checker's verdict needs before it is trusted
   ([testing-quality-harness-reverse-controls]).
5. Keep the repo's test convention intact: a redundant bare `assert` or
   `pytest.raises` added only to clear the scanner degrades the file below its own
   convention for no coverage gain, and the next scanner run flags the next file.

## Edge cases

| Case | Then |
|------|------|
| The repo mixes pytest-style and unittest-style files | Scope the scanner's accepted patterns per file (a `unittest.TestCase` subclass, or a directory convention) rather than one global pattern |
| The floor also requires an "error case" and the file uses `self.assertRaises` / `assertRaisesRegex` | Add those names to the error-case pattern alongside `pytest.raises`; they are the same assertion in the other framework |
| Two workers in the same run report the identical false positive | Fix the scanner once at the coordinator level; do not dispatch per-file rework to each worker |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `assert True` or a redundant `pytest.raises` to a `self.assertX` file to clear the floor | Run the canonical floor script; when it also fails, fix its accepted pattern | The scanner's heuristic, not the test, disagrees with the framework; patching the file breaks the convention for zero new coverage |
| Re-dispatch the task because a worker reported "floor failed" | Run the canonical script yourself in that worktree first | A regex floor has a known convention-specific blind spot; the report is a control signal, not the primary artifact |
| Rewrite freshly written tests because the floor mass-failed them with one uniform reason | Run the same gate against a shipped commit first; when it fails there too, fix the gate's pattern | A gate that fails known-good, already-shipped code is discriminating on convention, not detecting a defect in the new work |

## Sources

- https://docs.python.org/3/library/unittest.html — "The crux of each test is a call to assertEqual() … assertTrue() or assertFalse() … or assertRaises() … These methods are used instead of the assert statement so the test runner can accumulate all test results and produce a report"
- https://docs.pytest.org/en/stable/how-to/assert.html — "pytest allows you to use the standard Python assert for verifying expectations and values in Python tests"; assertion rewriting puts introspection information into the failure message
- Field reproduction 2026-08-25 (linkly, `test-floor.sh` run against shipped commit 305f8e2 from merged PR #81): exit 3 "no-assertion" on already-reviewed code; the pattern `/assert[ \t]/` misses unittest's `self.assertEqual(`, the convention of 108 of the repo's 112 test files
- Field evidence 2026-08-24 (linkly, two orchestration runs): workers t96 and t85 each reported the same "no assertion" floor failure on `self.assertX`-convention files; the canonical `test-floor.sh`, run by the coordinator in each worktree, passed both diffs (rc 0)
