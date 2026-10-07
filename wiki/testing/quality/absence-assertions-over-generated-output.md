---
id: testing-quality-absence-assertions-over-generated-output
domain: testing
category: quality
applies_to: [general, python]
confidence: verified
sources:
  - https://github.com/python/cpython/blob/main/Lib/tempfile.py
  - https://docs.python.org/3/library/tempfile.html
  - https://github.com/pytest-dev/pytest/blob/main/doc/en/how-to/tmp_path.rst
  - https://github.com/coe0718/hermes-review-loop/issues/153
  - "Local measurement 2026-10-07 (CPython 3.14.6, macOS): 200,000 names from tempfile's own name sequence — `42` in 1,046 (0.52%), `7` in 19.6%, `192192192` and `FAKE-SECRET` in none; after `random.seed(0)` two runs still produced different temp names"
last_verified: 2026-10-07
related: [security-data-masking-verification, testing-flaky-diagnosing-flaky-tests, testing-quality-source-text-wiring-assertions, testing-quality-value-preserving-refactor-assertions, testing-quality-tests-that-cannot-fail, testing-data-artifact-leakage-from-a-suite]
---

# Asserting a Value Is Absent From Output That Carries Generated Names

## When this applies

A test asserts that a value does not appear in text — `assertNotIn("42", msg)`,
`expect(out).not.toContain(...)`, `grep -v`, a leak or redaction check — and the
same text also carries generated content: a temp-file path (`tempfile`, pytest
`tmp_path`), a run counter, a PID, port, timestamp, or random id. Also when such
a test fails on some runs, passes on rerun, and the failure message shows the
forbidden value inside a path.

## Do this

1. **List every generator in the text before choosing the forbidden value.** An
   absence check fails on any occurrence, including one inside a name the code
   under test only echoes back:

| Generator in the output | What it can contain |
|-------------------------|---------------------|
| Python `tempfile` (`mkdtemp`, `mkstemp`, `TemporaryDirectory`) | An 8-character random field drawn from `abcdefghijklmnopqrstuvwxyz0123456789_`. Measured: `42` appears in 0.52% of names (about 1 in 190), `7` in 19.6% |
| pytest `tmp_path` | `pytest-of-{user}/pytest-{num}/{testname}/` — `{num}` grows by one every suite run, so a short number is present on exactly the runs whose counter contains it |
| The system temp root (`$TMPDIR`, `/var/folders/…` on macOS) | Letters and digits chosen per machine and user |
| PIDs, ports, timestamps, byte counts | Runs of digits |

2. **Pick the remedy by who owns the forbidden text:**

| Case | Do |
|------|----|
| The test plants the value it later checks is absent (a secret, a config value, an input that must not leak into a message) | Plant a marker no generator in the output can produce: longer than any random field and built from characters outside their alphabets. Uppercase letters and `-` are outside `tempfile`'s alphabet and hex ids, so `FAKE-SECRET-MARKER` cannot arise by chance |
| The forbidden text is fixed by the product (a status code `404`, an error keyword) | Assert the absence of the whole phrase the defect would print (`"route /health returned 404"`), not the bare token |
| The generated part is context, not the subject of the test | Replace the known temp root with a placeholder before the check, or assert on the structured field (`err.path`, a JSON key) instead of the rendered text |

3. **Keep the check able to fail.** In the same output, assert that a control
   which must appear does appear (the field name, the path placeholder). An empty
   or uncaptured output passes every absence check
   ([security-data-masking-verification] step 3).
4. **Watch the test go red once.** Put the marker into the message by hand, or
   revert the fix, and require a failure; then restore and require a pass
   ([testing-quality-tests-that-cannot-fail]).

## Edge cases

| Case | Then |
|------|------|
| You are about to seed `random` to stop the flake | Change the marker instead: `tempfile` draws names from its own `random.Random()` instance, so `random.seed(0)` leaves them different on every run (measured: two seeded runs, two different name sets) |
| The failure appears on one suite run and every rerun passes | Read the run counter in the failing path (`pytest-42`); the next run moves past it, so a passing rerun proves nothing about the test |
| A digit-only marker (`192192192`) | It cannot occur in `tempfile`'s 8-character field, but timestamps, PIDs and byte counts produce digit runs; add uppercase letters and `-` when the output also carries numbers |
| The code under test transforms the value (case-folds, truncates, hashes) | Also assert the absence of the transformed form; lowercased, `fake-secret-marker` still contains `-`, which `tempfile`'s alphabet lacks |
| The absence check is part of a masking or redaction sweep across output channels | [security-data-masking-verification] owns the channel sweep; this page owns the choice of planted value |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert `"42" not in msg` for a value the test chose | Plant `FAKE-SECRET-MARKER` and assert it is absent | About 1 in 190 temp names contains `42`, so the test fails on correct code at random |
| Assert `"404" not in out` for a product message | Assert the absence of the full phrase the defect would print | A temp directory named like `tmp404…` contains the bare token with no product fault |
| Rerun until green | Read the failing message for the forbidden token inside a generated name | A rerun hides a test defect that recurs at the same rate |

## Sources

- https://github.com/python/cpython/blob/main/Lib/tempfile.py — `_RandomNameSequence`: "Each string is eight characters long", `characters = "abcdefghijklmnopqrstuvwxyz0123456789_"`; its `rng` property builds a private `_Random()` instance per process
- https://docs.python.org/3/library/tempfile.html — the default name prefix comes from `gettempprefix()`; the temp root search starts with the `TMPDIR` environment variable
- https://github.com/pytest-dev/pytest/blob/main/doc/en/how-to/tmp_path.rst — `{temproot}/pytest-of-{user}/pytest-{num}/{testname}/`, where `{num}` "is a number that is incremented with each test suite run"
- https://github.com/coe0718/hermes-review-loop/issues/153 — independent incident: `assertNotIn("404", out)` failed when the output's temp directory was named like `tmp404ad9f3`; the fix asserts the specific false-alarm wording instead of the bare substring
- Local measurement 2026-10-07 (CPython 3.14.6, macOS): 200,000 names drawn from `tempfile._RandomNameSequence` — `42` in 1,046 (0.52%; the estimate 7/37² is 0.51%), `7` in 39,123 (19.6%), `192192192` and `FAKE-SECRET` in none. Two runs of `random.seed(0)` followed by `tempfile._get_candidate_names()` printed the same module `random.random()` value and different temp names. Re-run 2026-10-07 on CPython 3.13.1 (200,000 names): `42` in 0.55%, `7` in 19.6%, `192192192` in none; the source still holds the alphabet line and the private `_Random()`; two seeded child runs printed different names
- Field evidence 2026-10-06 (a Python CLI's unittest suite): `test_error_file_not_a_string` asserted `"42"` absent from an error message that embedded a `tempfile` path under `.claude/tmp/`; it failed once with `42` inside the random directory name, and planting `192192192` made the result deterministic
