---
id: testing-quality-path-resolver-fixtures-with-coincident-cwd
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://bats-core.readthedocs.io/en/stable/faq.html
  - https://en.wikipedia.org/wiki/Mutation_testing
  - https://arxiv.org/abs/2410.21904
last_verified: 2026-09-17
related: [testing-quality-default-values-under-test, testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, testing-data-test-data-and-isolation, testing-quality-surviving-mutant-equivalence-triage]
---

# Testing a Root Resolver Whose Fallback Is the Working Directory

## When this applies

The code under test finds a root by search — project root, config root, nearest
marker directory (`.git`, `wiki-local/`, `pyproject.toml`) — and falls back to
the working directory when the search finds nothing. The harness `cd`s into a
per-test temp directory and builds the fixture project right there, so the
expected root and the test's cwd are the same path.

The inverse failure — tests that skip the `cd` and read a real config through
the upward walk → [testing-data-test-data-and-isolation].

## Do this

1. **Build the fixture root and the test's cwd as two different directories.**
   Create the project under `$WORK/proj`, create `$WORK/elsewhere`, `cd` into
   `elsewhere`, and pass the resolver a path into `proj`. Assert in the test
   body that the cwd holds no marker (`[ ! -d wiki-local ]`), so a later fixture
   edit that re-merges the two directories fails loudly. While cwd equals the
   expected root, the fallback returns the expected answer, so every
   implementation of the search — including none — passes.
2. **Give each documented stage of the resolver its own case**, each with an
   expected value no other stage can produce:

| Stage the resolver documents | Fixture | Expected |
|------------------------------|---------|----------|
| The start directory itself holds the marker | Marker inside the start directory only; none above it, none in cwd | The start directory |
| An ancestor holds the marker | Marker two levels above the start directory; none in cwd | That ancestor |
| No marker anywhere → fallback | No marker above the start directory or in cwd | The cwd (`elsewhere`), asserted as that literal path |
| Marker name is a prefix of a sibling (`wiki-local` vs `wiki-localX`) | Both directories present | The exact-name match only |

3. **Prove the search with its deletion, not with whichever mutation is
   nearest.** Delete the walk so the function returns the fallback
   unconditionally, re-run, and require red in the ancestor case. Then shift
   the walk's start by one directory (start at the parent) and require red in
   the start-directory case. One red mutant establishes that one assertion
   discriminates ([testing-quality-tests-that-cannot-fail] step 2); an
   overshoot mutant reddens under a coincident layout while the deletion stays
   green.
4. **Read a surviving walk-deletion as a fixture defect.** The expected value is
   correct and the assertion compares it; the input makes two code paths agree.
   Audit the fixture for `expected root == cwd` before adding assertions — the
   same shape as a mechanism test whose value repeats the shipped default
   ([testing-quality-default-values-under-test]).

## Edge cases

| Case | Then |
|------|------|
| The runner sets the cwd for you | Check what it sets: bats runs tests in "the directory where you started when executing bats" and leaves enforcement to a `cd` in `setup`. A `setup` that `cd`s into the temp directory and a test that builds its project at `.` is the coincident layout |
| The fallback is a different ambient value (`$HOME`, the script's own directory, an env var) | Apply the same separation to that value: the fixture root must differ from every ambient value the resolver can fall back to |
| The temp directory sits under a real project (a repo-local scratch path) | The walk can climb out of the fixture and find the host repository's marker. Assert the no-marker case returns the fallback literal; when it returns the host repo, move the scratch root outside any marked tree or give the resolver a stop directory |
| The deletion mutant survives and cwd is already separate | Classify it before writing a test — missing case, equivalent mutant, or uncovered line ([testing-quality-surviving-mutant-equivalence-triage]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build the fixture project in the directory the harness already `cd`'d into | Build it in a sibling directory and run from another | With cwd equal to the root, the fallback supplies the expected answer and the search is unobserved |
| Cite "a mutation went red" as proof the resolver is tested | Delete the search outright and require red, then run one mutation per documented stage | An overshoot mutant reddens under a coincident layout while the walk-deletion and start-at-parent mutants stay green |
| Add assertions when the walk-deletion survives | Change the fixture layout first, then re-run the deletion | The defect is in the input; no assertion on an output both paths share can separate them |
| Cover "ancestor found" with one case and call the resolver covered | Add the start-directory case and the fallback case as separate tests | Start-at-parent is caught only by the start-directory case, and a wrong fallback only by the no-marker case |

## Sources

- https://bats-core.readthedocs.io/en/stable/faq.html — "The working directory is simply the directory where you started when executing bats. If you want to enforce a specific directory, you can use cd in the setup_file/setup functions."
- https://en.wikipedia.org/wiki/Mutation_testing — the kill conditions: a test must reach the mutated statement, infect the program state, and "The incorrect program state … must propagate to the program's output and be checked by the test." A coincident cwd blocks propagation: the deleted walk infects state, and the fallback maps it back to the expected output
- https://arxiv.org/abs/2410.21904 — Mirian-Hosseinabadi, "Formal Analysis of Reachability, Infection and Propagation Conditions in Mutation Testing": killing a live mutant "needs to calculate the Reachability, Infection and Propagation(RIP) conditions"
- Local reproduction 2026-09-17 (POSIX `sh`, macOS arm64): a marker-walk resolver with a `$PWD` fallback, three mutants, two layouts. Coincident (cwd is the root, 2 cases): original GREEN, walk-deleted GREEN, start-at-parent GREEN, overshoot (returns the found directory's parent) RED. Separated (`proj`/`elsewhere`, 3 cases): original GREEN, walk-deleted RED in ancestor and start-directory cases, start-at-parent RED in the start-directory case only, overshoot RED. Nested-fixture check: with a marker on a directory above the scratch tree, the no-marker case returned that host directory instead of the `elsewhere` fallback
- Field report 2026-09-17, as recorded by the originating session; this flush confirmed the resolver and the `elsewhere`-separated cases exist at that commit and did not re-run its mutants (dev-loop `skills/wiki-plan/scripts/plan-gate.sh` `project_root_for`, commit `5afddde`): with every fixture built in the bats `cd` target, deleting the ancestor walk left all 5 groundings cases green; moving the run to `$WORK/elsewhere` turned that deletion red, and the plan-dir-is-its-own-root and `wiki-localX` prefix cases each caught a further mutant no other case caught
