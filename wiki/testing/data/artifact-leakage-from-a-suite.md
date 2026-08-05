---
id: testing-data-artifact-leakage-from-a-suite
domain: testing
category: data
applies_to: [general]
confidence: verified
sources:
  - https://pkg.go.dev/testing#T.TempDir
  - https://docs.pytest.org/en/stable/how-to/tmp_path.html
  - https://eslint.org/docs/latest/extend/custom-rule-tutorial
last_verified: 2026-08-05
related: [testing-data-test-data-and-isolation, testing-quality-checks-that-cannot-pass, debugging-methodology-isolate-by-bisection]
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

2. **Fix by adopting the runner's owned-temp API at those sites**, not by adding
   a `rm` at the end of each test. The API ties removal to the test's lifetime,
   so it also runs when the test fails or panics:

| Runner | Use |
|--------|-----|
| Go | `t.TempDir()` — the directory "is automatically removed when the test and all its subtests complete" |
| pytest | the `tmp_path` fixture; set `tmp_path_retention_policy`/`tmp_path_retention_count` when you want failed runs kept for inspection |
| Anything without such an API | Create in setup and remove in a teardown that runs on failure too (`finally`, fixture teardown, `t.Cleanup`) |

3. **Encode the convention as a static check once most sites already follow it.**
   A convention that N−2 of N call sites obey is machine-checkable: write an
   AST/lint rule that flags a raw `mkdtemp`/`TempDir`-equivalent call outside the
   approved helper. Fixing only the instances leaves the next author free to
   repeat it.
4. **Watch the new check fail before you fix the code.** Run it against the
   unfixed tree and require it to report exactly the known-bad sites; a rule
   authored after the fix has only ever been observed green
   ([testing-quality-checks-that-cannot-pass]).
5. **Assert the invariant, not the cleanup call.** Add one test that records the
   scratch area's entry count before and after the suite and requires a delta of
   zero. That survives refactors of how directories are created.

## Edge cases

| Case | Then |
|------|------|
| The artifacts are wanted on failure for debugging | Keep them under a retention policy the runner owns (pytest's retention settings) rather than by skipping cleanup; an unconditional leak is not a debugging feature |
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

## Sources

- https://pkg.go.dev/testing#T.TempDir — "TempDir returns a temporary directory for the test to use. The directory is automatically removed when the test and all its subtests complete."
- https://docs.pytest.org/en/stable/how-to/tmp_path.html — the `tmp_path` fixture provides a per-test temporary directory; by default recent directories are retained, configurable via `tmp_path_retention_count` and `tmp_path_retention_policy`, so retention is an explicit policy rather than a leak
- https://eslint.org/docs/latest/extend/custom-rule-tutorial — authoring an AST-based rule that reports a disallowed call pattern, the mechanism for enforcing a call-site convention once it is established
- Field observation 2026-08-05: in one repository, 998 leftover directories carried two name prefixes (686 + 306); of the six files calling `mkdtemp`, the two with no cleanup were exactly those two prefixes' owners. After adopting an owned-temp helper at those sites, a full-suite run measured a scratch-directory delta of 0 and the scratch area shrank from 72M to 3.3M
