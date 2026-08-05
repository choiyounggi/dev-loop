---
id: testing-data-leaked-test-artifacts
domain: testing
category: data
applies_to: [general]
confidence: verified
sources:
  - https://docs.python.org/3/library/tempfile.html
  - https://docs.pytest.org/en/stable/how-to/tmp_path.html
  - https://docs.semgrep.dev/writing-rules/testing-rules
last_verified: 2026-08-05
related: [testing-data-test-data-and-isolation, testing-quality-checks-that-cannot-pass, debugging-methodology-hypothesis-testing]
---

# Attributing Leaked Test Artifacts to the Call Sites That Create Them

## When this applies

A repository, workspace, or scratch root keeps accumulating directories or files
left behind by test runs, and more than one place in the code looks capable of
creating them. Also when you have fixed one leak and want the convention enforced
so the next contributor cannot reintroduce it.

## Do this

1. **Count the leftovers by name prefix before reading any code.** Creation APIs
   stamp a fixed prefix and a random suffix, so the population is already grouped
   by producer:

```sh
ls scratch-root | sed 's/-[a-z0-9]*$//' | sort | uniq -c | sort -rn
```

2. **Compare that distribution against the list of creation call sites.** Enumerate
   the call sites by the creating API (`mkdtemp`, `mkstemp`, `TemporaryDirectory`,
   `mktemp -d`), not by the prefix string — a helper can pass the prefix in from
   elsewhere. When the prefixes carrying nearly all the volume map to exactly the
   call sites that lack cleanup, the cause is closed and no further hypothesis is
   needed ([debugging-methodology-hypothesis-testing]).
3. **Fix each attributed call site by moving to an API that cleans up**, rather
   than adding a removal line: the raw creators hand ownership to the caller
   ("The user of `mkdtemp()` is responsible for deleting the temporary directory
   and its contents when done with it"), while the managed forms remove the tree
   "On completion of the context or destruction of the temporary directory
   object". In a test, prefer the runner's own fixture (`tmp_path`) so cleanup and
   retention policy are the runner's problem.
4. **Promote the convention to a static check once most call sites already follow
   it.** Uniform existing usage is what makes the rule expressible: match the raw
   creator on the syntax tree (Semgrep pattern, `ast`-walking lint, ESLint rule)
   rather than by grep, so a renamed import or a wrapped call cannot slip past.
5. **Require the new check to go red on the unfixed code before you fix it.** Run
   it while the offending call sites are still present and require it to name
   exactly them; a rule authored against already-clean code passes for every
   reason, including being wrong ([testing-quality-checks-that-cannot-pass]).
   Keep both directions as fixtures — one file that must match, one that must not.
6. **Measure the delta, not the impression.** Count the artifact root before and
   after a full suite run and require zero growth.

## Edge cases

| Case | Then |
|------|------|
| The prefixes are spread evenly across many producers | The leak is a convention gap, not a few defects — go straight to step 4 and let the check enumerate the call sites for you |
| Prefixes do not match any call site | A dependency or a subprocess is creating them; find the producer with the creating process (`lsof`, a run with the root freshly emptied) before editing your own code |
| A test legitimately needs its artifact to survive the run (debug bundle, golden output) | Give it a distinct prefix and an explicit retention rule, and exclude that prefix from the check by name so the exception is visible |
| The runner keeps the last few directories on purpose | `pytest`'s `tmp_path` retains recent runs by design — measure the delta against that policy's steady state rather than requiring an empty root |
| Cleanup exists but does not run on failure | Move it to the context manager / fixture teardown; a removal statement after the assertions is skipped by the exception that made the test fail ([testing-data-test-data-and-isolation]) |
| The check cannot see calls made through a project wrapper | Match the wrapper too, and assert the wrapper itself cleans up — one rule per creator, each with its own must-match fixture |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read every file that could create temp directories | Count leftovers by prefix and intersect that distribution with the call-site list | The count names the producers carrying the volume without reading anything; when it spreads evenly instead, that answer is itself the routing signal (edge case row 1) |
| Add a `shutil.rmtree` / `rm -rf` line after the test body | Switch to the context-managed or fixture-provided form | A trailing cleanup line is skipped on the failure path, which is exactly when artifacts pile up |
| Fix the offending call sites and move on | Add the AST check in the same change, verified red against the pre-fix tree | The convention is what regresses; without a check the next contributor repeats the same call |
| Adopt the new lint rule after seeing it pass on the fixed tree | Run it on the unfixed tree first and require it to flag exactly the known call sites | A rule that matches nothing passes on clean code whether it is correct or mistyped |
| Declare the leak fixed because the directory "looks smaller" | Count the root before and after a full suite run and require zero growth | An impression cannot separate a fixed leak from a smaller test selection |

## Sources

- https://docs.python.org/3/library/tempfile.html — `mkdtemp()`: "The user of `mkdtemp()` is responsible for deleting the temporary directory and its contents when done with it"; `TemporaryDirectory()`: "On completion of the context or destruction of the temporary directory object, the newly created temporary directory and all its contents are removed from the filesystem"
- https://docs.pytest.org/en/stable/how-to/tmp_path.html — the runner-provided per-test temporary directory and its retention policy
- https://docs.semgrep.dev/writing-rules/testing-rules — rule tests annotate `ruleid:` lines "for protecting against false negatives" and `ok:` lines "for protecting against false positives"; a rule is validated against inputs that must match and inputs that must not

## Field context

2026-08-04, `linkly`: 998 leftover directories under the scratch root reduced to
two prefixes at 686 and 306 by the `sed`/`uniq -c` count above; of the six files
calling `mkdtemp`, exactly those two lacked cleanup. Converting them to the
context-managed form and adding an AST rule that flags bare `mkdtemp` took the
full-suite artifact delta to 0 (measured before/after) and the root from 72M to
3.3M.
