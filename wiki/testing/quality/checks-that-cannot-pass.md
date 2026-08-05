---
id: testing-quality-checks-that-cannot-pass
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://www.jamesshore.com/v2/books/aoad2/test-driven_development
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html
  - https://docs.semgrep.dev/writing-rules/testing-rules
  - https://docs.pytest.org/en/stable/reference/exit-codes.html
last_verified: 2026-07-29
related: [testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, qa-process-scope-purity-checks]
---

# Validating a Check Whose Target Does Not Exist Yet

## When this applies

You are authoring a check that will decide pass/fail for work not yet done —
a grep/regex gate on an unwritten file or doc section, a lint/scan rule, a
schema assertion against an unbuilt endpoint, a plan's verification command —
and the only run you have observed is a failing one. Also applies when
reviewing a plan whose gates have never been seen to pass.

## Do this

1. **Run the check against a known-good input before adopting it**, and require
   the exact expected result. A failing run against an absent target is produced
   by every pattern, correct or mistyped alike, so it is not evidence the check
   is right. The known-good input removes the absence variable and tests only
   the check.

| What the check is | Known-good input to run it against | Result to require |
|-------------------|------------------------------------|-------------------|
| Regex/grep gate on a file or section not yet written | An existing sibling artifact built to the same template or spec | The exact count (`grep -c` = the number the spec implies), not merely "nonzero" |
| Lint/scan rule (ESLint, Semgrep, custom AST rule) | One fixture that must match plus one that must not | Match on the first, silence on the second — both directions, per Semgrep's `ruleid:`/`ok:` split |
| Schema/contract assertion on an unbuilt endpoint | A shipped endpoint with the same response envelope | Assertion passes unmodified |
| Cross-artifact signature check (doc A must quote the signature in doc B) | Both existing documents of the same family | The expected match count in each |

2. **Predict the failure mode before running the check, then compare.** State the
   expected exit status and message. When the observed failure differs from the
   prediction, the check is what is unknown — fix it before it becomes a gate.

3. **Make "target missing" a distinct outcome from "content missing."** POSIX
   `grep` already separates them; keep that distinction instead of collapsing it
   into a boolean:

| Outcome | POSIX grep exit | What it means for the gate |
|---------|-----------------|----------------------------|
| One or more lines selected | 0 | The check passes |
| No lines selected | 1 | Target readable; content absent **or** pattern wrong — indistinguishable |
| Error (unreadable path, invalid regex) | >1 (2 in practice) | The check could not run at all |

4. **Give each of the three outcomes its own exit code and message**, so the
   gate's failure names its own cause. Keep grep's status before defaulting the
   count — `|| n=0` alone reports an invalid pattern as a count mismatch, which
   is the conflation this page exists to prevent:

```sh
[ -f "$f" ] || { echo "gate: target missing: $f" >&2; exit 3; }
n=$(grep -cE "$pat" "$f" 2>/dev/null); rc=$?
[ "$rc" -le 1 ] || { echo "gate: check could not run on $f (grep exit $rc)" >&2; exit 4; }
[ "${n:-0}" -eq "$expected" ] || { echo "gate: $f matched ${n:-0}, expected $expected" >&2; exit 1; }
```

Verified 2026-07-29 against four inputs: known-good file + correct pattern → 0;
known-good file + wrong anchor → 1; missing target → 3; invalid regex → 4.

## Edge cases

| Case | Then |
|------|------|
| No sibling artifact exists (first of its kind) | Hand-write a throwaway stub that satisfies the spec, run the check against it, require the expected result, delete the stub. The stub is the positive control |
| The gate globs paths that include the not-yet-created target, using `-q` | Drop `-q` and check each path separately: with `-q`, exit status is 0 when a line is selected **even if an error occurred** (POSIX), so a matching sibling hides the missing target. Measured 2026-07-29 (BSD grep 2.6.0-FreeBSD, ugrep 7.5.0): `grep -q pat missing.md matching.md` → exit 0 |
| The check's output is piped (`grep -c … \| tail -1`) | Set `set -o pipefail`, or capture into a variable and compare. Without it the pipeline reports the last command's status, so grep's error 2 becomes exit 0 — the absent target reads as a pass. Measured on the same runs |
| A count is compared without a value (`[ "$n" -eq 7 ]`, `$n` empty) | Default the capture (`n=${n:-0}`) after the existence guard: `grep -c` on an unreadable path writes nothing to stdout, and the empty comparison raises a shell error whose message hides the real cause |
| The check is a test for behavior you are about to implement | Red is the expected state; require that it fails with the assertion the behavior owns, not with a collection/import error. `pytest` exit 5 means "no tests were collected" — a selector typo, not a failing test |
| The check is already adopted and has never been observed passing | Run it against a known-good input now; when the expected result does not appear, treat the gate as defective rather than the work as incomplete |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Adopt a gate after seeing it fail on the missing target | Run it on an artifact that already satisfies the spec and require the exact expected count | Absence makes every pattern fail; the failure proves the target is missing, not that the pattern is correct |
| Write the gate as `grep -q pat docs/*.md` | Assert the specific path exists, then match it with an exact count | `-q` returns 0 on a match even when another path errored, so a sibling's match masks the missing target |
| Treat any nonzero exit as "not done yet" | Branch on 1 versus >1: content-absent versus check-could-not-run | An invalid regex and an unwritten file give different statuses; conflating them leaves a mistyped gate failing forever after the work is complete |
| Leave the expected failure unstated and just run the check | Predict the exit status and message first, then compare | An unpredicted failure that matches nothing you expected means the check, not the code, is the unknown |

## Sources

- https://www.jamesshore.com/v2/books/aoad2/test-driven_development — "Don't just predict that it will fail, though; predict *how* it will fail"; if it "fails in a different way than you expected, you're no longer in control of your code"
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html — EXIT STATUS 0 = lines selected, 1 = no lines selected, >1 = an error occurred; with `-q` "the exit status shall be zero if an input line is selected, even if an error was detected"
- https://docs.semgrep.dev/writing-rules/testing-rules — rule tests annotate `ruleid:` lines "for protecting against false negatives" and `ok:` lines "for protecting against false positives"; a rule is validated against inputs that must match and inputs that must not
- https://docs.pytest.org/en/stable/reference/exit-codes.html — exit code 5 = "No tests were collected", distinct from 1 = tests ran and failed
- Field reproduction 2026-07-29 (BSD grep 2.6.0-FreeBSD, ugrep 7.5.0, macOS): missing path → exit 2; wrong-but-valid pattern on a present file → exit 1; `grep -q` over missing + matching paths → exit 0; unpiped `grep -c missing | tail -1` → exit 0 without `pipefail`
