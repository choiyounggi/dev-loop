---
id: testing-data-artifact-leakage-from-a-suite
domain: testing
category: data
applies_to: [general]
confidence: verified
sources:
  - https://pkg.go.dev/testing#T.TempDir
  - https://docs.pytest.org/en/stable/how-to/tmp_path.html
  - https://docs.python.org/3/library/tempfile.html
  - https://docs.semgrep.dev/writing-rules/testing-rules
  - https://eslint.org/docs/latest/extend/custom-rule-tutorial
last_verified: 2026-08-05
related: [testing-data-test-data-and-isolation, testing-quality-checks-that-cannot-pass, debugging-methodology-hypothesis-testing, debugging-methodology-isolate-by-bisection]
---

# A Suite That Leaves Working Directories Behind

## When this applies

Temp directories, build outputs, or scratch files accumulate in the repo or the
system temp area after a suite runs; a clone grows without an obvious owner;
`git status` shows untracked artifacts nobody created by hand. You suspect
"they leak from everywhere" and are deciding where to start.

## Do this

1. **Count the leftovers by name prefix before reading any code**, and treat the
   distribution as the diagnosis:

```sh
ls "$SCRATCH_DIR" | sed 's/-[a-z0-9]*$//' | sort | uniq -c | sort -rn
```

   Concentration is the normal shape — a few call sites produce nearly all of
   them. Match the top prefixes against the call sites that create scratch
   directories; when the counts line up with the sites that have no cleanup, the
   cause is identified without guessing.

2. **Attribute each artifact to the creation call site**, not by the prefix string
   — a helper can pass the prefix in from elsewhere. Enumerate the call sites by
   the creating API (`mkdtemp`, `mkstemp`, `TemporaryDirectory`, `mktemp -d`,
   `TempDir()`), not by the prefix string.

3. **Fix by adopting the runner's owned-temp API at those sites**, not by adding
   a `rm` at the end of each test. The API ties removal to the test's lifetime,
   so it also runs when the test fails or panics:

| Runner | Use |
|--------|-----|
| Go | `t.TempDir()` — the directory "is automatically removed when the test and all its subtests complete" |
| pytest | the `tmp_path` fixture; set `tmp_path_retention_policy`/`tmp_path_retention_count` when you want failed runs kept for inspection |
| Anything without such an API | Create in setup and remove in a teardown that runs on failure too (`finally`, fixture teardown, `t.Cleanup`) |

4. **Encode the convention as a static check once most sites already follow it.**
   A convention that N−2 of N call sites obey is machine-checkable: write an
   AST/lint rule that flags a raw `mkdtemp`/`TempDir`-equivalent call outside the
   approved helper. Fixing only the instances leaves the next author free to
   repeat it.

5. **Watch the new check fail before you fix the code.** Run it against the
   unfixed tree and require it to report exactly the known-bad sites; a rule
   authored after the fix has only ever been observed green
   ([testing-quality-checks-that-cannot-pass]).

6. **Assert the invariant, not the cleanup call.** Add one test that records the
   scratch area's entry count before and after the suite and requires a delta of
   zero. That survives refactors of how directories are created.

7. **Measure the delta, not the impression.** Count the artifact root before and
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
| A crashed or killed run leaves directories no teardown could remove | Give the suite a session-scoped root it creates and removes wholesale, so one removal reclaims every orphan from prior aborted runs |
| Cleanup code exists but the directory survives | The path being removed is not the path being created — log both at one failing site before editing; a `cd` or a relative path resolved from a different working directory is the usual gap |
| The leak is outside the repo (system temp), so `git status` is clean | Measure the scratch area's size and entry count as the signal; repo-only checks report a suite that fills the disk as healthy |
| Artifacts are produced by a subprocess (a compiler, a bundler) the test invokes | Point the subprocess at the test-owned directory via its output flag or `cwd`; a subprocess inherits neither the fixture nor its teardown |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read every call site because "it leaks from everywhere" | Count leftovers by prefix and compare the distribution with the call-site list | Leftovers concentrate: a few sites produce the bulk, so the counts close the question without a code sweep |
| Add a `rm -rf` at the end of each affected test | Adopt the runner's owned-temp API, or a teardown that runs on failure | A trailing removal is skipped exactly when the test fails, which is when artifacts pile up fastest |
| Fix the offending sites and move on | Add the static rule and a zero-delta assertion as well | The instances are the symptom; the convention is what the next author will or will not follow |
| Add `*.tmp`-style entries to `.gitignore` | Remove the artifacts at their source | Ignoring hides the growth from `git status` while the disk keeps filling |
| Adopt the new lint rule after seeing it pass on the fixed tree | Run it on the unfixed tree first and require it to flag exactly the known-bad sites | A rule that matches nothing passes on clean code whether it is correct or mistyped |
| Declare the leak fixed because the directory "looks smaller" | Count the root before and after a full suite run and require zero growth | An impression cannot separate a fixed leak from a smaller test selection |

## Sources

- https://pkg.go.dev/testing#T.TempDir — `T.TempDir()` creates a directory and "is automatically removed when the test and all its subtests complete"
- https://docs.pytest.org/en/stable/how-to/tmp_path.html — the `tmp_path` fixture provides a per-test temporary directory; `tmp_path_retention_policy` and `tmp_path_retention_count` settings retain directories on failure for inspection
- https://docs.python.org/3/library/tempfile.html — `TemporaryDirectory` as context manager automatically removes the directory on exit
- https://docs.semgrep.dev/writing-rules/testing-rules — writing rules to catch test-fixture misuse patterns
- https://eslint.org/docs/latest/extend/custom-rule-tutorial — writing custom linting rules to enforce conventions
- Field reproduction 2026-08-04 (task-board monitor): artifact prefixes concentrated on two call sites; `grep -n mkdtemp src/*.py` showed one site with cleanup and one without; adding context-manager form at the bare site eliminated the leak. 2026-08-05 (test suite): artifact count was 47 before run and 94 after; rewriting three `mkstemp` calls to use `pytest tmp_path` reduced delta to 0 on subsequent runs
