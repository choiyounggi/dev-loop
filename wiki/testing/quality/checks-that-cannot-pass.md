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
  - https://www.gnu.org/software/bash/manual/html_node/Pipelines.html
  - https://nodejs.org/api/path.html
  - "Local reproduction 2026-10-11 (Node v26.7.0): path.posix.normalize around path.posix.join over fixed and random segments, and an inner-input mutant"
  - "Field reproduction 2026-10-27 (dev-loop orchestration, task orch-prereq-1026-t268c): a gates-ledger CHECK searching the repo for a removed phrase"
last_verified: 2026-10-29
related: [testing-quality-tests-that-cannot-fail, testing-quality-surviving-mutant-equivalence-triage, testing-quality-minimum-case-set, backend-common-change-impact-call-site-enumeration, platforms-processes-tool-diagnostics-without-a-failing-exit-code, qa-process-scope-purity-checks, testing-quality-history-dependent-checks-on-shallow-clones, platforms-tools-deny-rules-under-bypassed-permissions, testing-quality-assertion-scanner-false-positive-on-unittest-convention, infrastructure-agent-orchestration-gate-evidence-exit-code-class, infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan, platforms-toolchains-no-html-link-for-pages-misses-app-router-routes, platforms-tools-search-evidence-from-a-wrapped-grep, testing-quality-id-only-failure-allowlist-gates]
---

# Validating a Check Whose Target Does Not Exist Yet

## When this applies

You are authoring a check that will decide pass/fail for work not yet done —
a grep/regex gate on an unwritten file or doc section (including an unwritten spec, RFC, or schema document), a lint/scan rule, a schema assertion against
an unbuilt endpoint, a plan's verification command — and the only run you have observed is a failing one. Also applies when reviewing a plan whose gates
have never been seen to pass. This owns unwritten-target gate patterns for spec, RFC, and schema documents too; wiki/qa/document-verification/spec-document-gates.md does not.

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
| The gate extracts two failure lists (`grep PAT new.log \| sort -u > new.txt`, the same for the baseline log) and passes when they are equal | After it passes, count both files (`wc -l new.txt base.txt`) and record whether 0 was compared with 0 or real entries with real entries. The pipeline's status is `sort`'s, so a `grep` that selected nothing (exit 1) keeps the `&&` chain going: a clean run and a mistyped pattern both print "no new failures". When both counts are 0, cite the runner's own success line from each log (`OK`, `N passed`) as the pass evidence, and run the pattern once on a log that has a known failure line to prove it can select one |
| A count is compared without a value (`[ "$n" -eq 7 ]`, `$n` empty) | Default the capture (`n=${n:-0}`) after the existence guard: `grep -c` on an unreadable path writes nothing to stdout, and the empty comparison raises a shell error whose message hides the real cause |
| The check is a test for behavior you are about to implement | Red is the expected state; require that it fails with the assertion the behavior owns, not with a collection/import error. `pytest` exit 5 means "no tests were collected" — a selector typo, not a failing test |
| The check is already adopted and has never been observed passing | Run it against a known-good input now; when the expected result does not appear, treat the gate as defective rather than the work as incomplete |
| The pre-implementation test cannot go red at all — the failure it asserts (usage error, exit 1) is exactly what the not-yet-implemented path already produces (unknown subcommand, catch-all 404) | Record it as vacuously green during the red run, and after implementation prove it by mutating the specific guard it targets (e.g. flip the arg-count check), requiring red, then restoring ([testing-quality-tests-that-cannot-fail]) — a test green for the wrong reason before the code exists never demonstrated it can catch the guard breaking |
| A plan's red control deletes or replaces a wrapper around an inner call that may already do the wrapper's work (`path.posix.normalize(path.posix.join(d, s))` → `String(path.posix.join(d, s))`) and names a test that must go red | Before adopting the plan, evaluate the original and the mutated expression on that test's own inputs. Equal outputs mean this control cannot go red for that test: move the mutation to the inner call's input (`join(dirname(importer), s)` → `join(importer, s)`) and confirm the output changes on those inputs. Calling the wrapper mutant equivalent for every input takes a domain argument ([testing-quality-surviving-mutant-equivalence-triage]); for this example, Node documents that `path.join` normalizes its result |
| A CHECK scans the whole repo for "no file still contains phrase X", and the gate's own ledger (which records that CHECK's command line) lives inside the scanned tree | Exclude the ledger's own directory from the scan (`--exclude-dir=.dev-loop` or equivalent) — the ledger file now contains phrase X literally, in its own recorded CHECK line, so an unscoped scan always finds itself and the gate never clears. Validate the fix by running the exact CHECK string once under plain `sh -c`, not your interactive shell: an interactive session's `grep` can be a function or alias that skips files (ignored-file rules, a different binary) that `sh -c`'s plain executor would scan, so a hand-run check and the gate runner's own execution can disagree ([platforms-tools-search-evidence-from-a-wrapped-grep]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Adopt a gate after seeing it fail on the missing target | Run it on an artifact that already satisfies the spec and require the exact expected count | Absence makes every pattern fail; the failure proves the target is missing, not that the pattern is correct |
| Write the gate as `grep -q pat docs/*.md` | Assert the specific path exists, then match it with an exact count | `-q` returns 0 on a match even when another path errored, so a sibling's match masks the missing target |
| Treat any nonzero exit as "not done yet" | Branch on 1 versus >1: content-absent versus check-could-not-run | An invalid regex and an unwritten file give different statuses; conflating them leaves a mistyped gate failing forever after the work is complete |
| Leave the expected failure unstated and just run the check | Predict the exit status and message first, then compare | An unpredicted failure that matches nothing you expected means the check, not the code, is the unknown |
| Adopt a plan whose red control removes a wrapper call | Evaluate the original and the mutated expression on the named test's inputs first and require different outputs | A mutant equal to the original on those inputs never goes red, so a "must be red" gate stalls the worker partway through execution |
| Trust a phrase-absence gate after running its `grep` yourself in your interactive shell | Re-run the exact CHECK string via plain `sh -c` once, and scope the scan away from the ledger's own directory | An interactive shell's `grep` can behave differently from the plain executor that actually runs the gate, and an unscoped scan matches the ledger's own recorded CHECK line |

## Sources

- https://www.jamesshore.com/v2/books/aoad2/test-driven_development — "Don't just predict that it will fail, though; predict *how* it will fail"; if it "fails in a different way than you expected, you're no longer in control of your code"
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html — EXIT STATUS 0 = lines selected, 1 = no lines selected, >1 = an error occurred; with `-q` "the exit status shall be zero if an input line is selected, even if an error was detected"
- https://docs.semgrep.dev/writing-rules/testing-rules — rule tests annotate `ruleid:` lines "for protecting against false negatives" and `ok:` lines "for protecting against false positives"; a rule is validated against inputs that must match and inputs that must not
- https://docs.pytest.org/en/stable/reference/exit-codes.html — exit code 5 = "No tests were collected", distinct from 1 = tests ran and failed
- https://www.gnu.org/software/bash/manual/html_node/Pipelines.html — "The exit status of a pipeline is the exit status of the last command in the pipeline, unless the pipefail option is enabled" (the two-list comparison edge case)
- Field case 2026-10-22 (a linkly task worktree, gate G4; recorded by the originating session): a new-vs-baseline failure-list comparison built from `grep … | sort -u` passed; `wc -l` then showed both lists at 0 lines, and the pass was confirmed by each log's `OK (skipped=1)` line
- Field reproduction 2026-07-29 (BSD grep 2.6.0-FreeBSD, ugrep 7.5.0, macOS): missing path → exit 2; wrong-but-valid pattern on a present file → exit 1; `grep -q` over missing + matching paths → exit 0; unpiped `grep -c missing | tail -1` → exit 0 without `pipefail`
- https://nodejs.org/api/path.html — `path.join()` "joins all given `path` segments together using the platform-specific separator as a delimiter, then normalizes the resulting path"
- Local reproduction 2026-10-11 (Node v26.7.0): `path.posix.normalize(path.posix.join(d, s)) === path.posix.join(d, s)` held for 10 fixed pairs (including `./`, `../`, `a//b`, two empty strings, `/` with `..`, and a trailing `x/`) and for 200,000 random calls of 1–4 segments, each segment 0–3 pieces drawn from `a`, `b`, `.`, `..`, empty, `/`, `//`, `./`, `../`, `x/..`, `/..` — 0 differences. The inner-input mutant `join(importer, s)` for `join(dirname(importer), s)` changed the output for `./a`, `../b` and `./c/d`
- Field case 2026-10 (linkly-invitation task t7; recorded by the originating session): a plan's red control replaced `path.posix.normalize(path.posix.join(...))` with `String(path.posix.join(...))`; the two agreed on 6 of 6 test specifiers, so the "must be red" check could not be met. Mutating the inner input instead (`dirname(importer)` → `importer`) changed the output in all 3 relative cases
- Field reproduction 2026-10-27 (dev-loop orchestration, task orch-prereq-1026-t268c): under plain `sh -c`, a repo-wide phrase search matched `./.dev-loop/gates/t268c-03.md` (the ledger's own CHECK line) and the gate stayed UNMET; `type grep` in the authoring zsh session showed "grep is a shell function"; adding `--exclude-dir=.dev-loop` to the scan returned the gate to MET
