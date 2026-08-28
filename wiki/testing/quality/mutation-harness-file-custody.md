---
id: testing-quality-mutation-harness-file-custody
domain: testing
category: quality
applies_to: [general]
confidence: field-tested
sources:
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states/
  - https://pitest.org/quickstart/basic_concepts/
  - https://git-scm.com/docs/git-status
  - https://docs.python.org/3/library/pathlib.html
last_verified: 2026-08-27
related:
  [
    testing-quality-tests-that-cannot-fail,
    testing-quality-harness-reverse-controls,
    testing-quality-surviving-mutant-equivalence-triage,
    testing-quality-completion-predicates,
    testing-data-artifact-leakage-from-a-suite,
    qa-process-scope-purity-checks,
  ]
---

# A Hand-Rolled Mutation Harness That Edits and Restores Files In Place

## When this applies

You wrote a script that backs up source files, mutates them, runs the suite, and
restores them — rather than using PIT or Stryker. You are choosing how it keys
its backups, or you are reading the tree (a `git diff`, a `grep`, a file) while
such a harness is running, or you are about to cite its SURVIVED/KILLED verdicts.

## Do this

1. **Key each backup by the file's full path with separators flattened**
   (`src/routers/deal.ts` → `src__routers__deal.ts`), not by its basename. In a
   repo organised by layer, the same domain noun names a file in several
   directories — `routers/deal.ts`, `schemas/deal.ts` — and a basename key makes
   the second backup overwrite the first, so restore writes one file's contents
   into the other.

2. **Verify each restore by comparing bytes against the backup before starting
   the next mutation.** Read both files and require equality
   (`Path(a).read_bytes() == Path(b).read_bytes()`, or `cmp -s`); stop the run on
   the first mismatch. A cross-restore leaves a syntactically valid file, so the
   next mutation's failures come from the corruption rather than from the
   mutation, and every verdict after that point is unattributable.

3. **Confirm the restore with the harness's own evidence, not `git diff`.** A
   file the repo does not track produces an empty `git diff` whether the restore
   worked or not, so "clean diff" and "file destroyed" are the same observation.
   Assert instead on content: the mutation marker is absent, and a token unique
   to the original file is present at its original count.

4. **Read the tree only when the harness is not holding it.** Between backup and
   restore the files are *deliberately* wrong, so a `git diff` or `grep` taken
   inside that window describes the mutation, not the code. Require both signals
   before reading: the process is gone (`pgrep -f`, or the harness's own exit)
   **and** the backup directory is empty. Discard anything read earlier rather
   than reasoning from it.

5. **Prove the harness discriminates before quoting a score** — a
   semantics-preserving no-op must SURVIVE ([testing-quality-harness-reverse-controls]).
   Uniform results across every mutant (all killed, or all survived) are a
   harness fault until shown otherwise.

6. **Re-run the whole matrix after fixing a custody bug, and replace the earlier
   verdicts rather than patching them.** Corruption moves verdicts in both
   directions, so the prior run's KILLED entries are as suspect as its SURVIVED
   ones.

## Edge cases

| Case | Then |
|------|------|
| Two backed-up files legitimately have identical length | Length and line count agree by coincidence — byte comparison (step 2) is what separates them; a line-count check reports the cross-restore as healthy |
| The harness dies partway (crash, cancelled session, usage limit) | The tree still holds a mutation. Restore from the backups by path key, then run the full suite and require the pre-run pass count before treating the tree as clean |
| Another agent or session shares the worktree | Its reads land inside your window and its writes land inside your backup — give the harness its own worktree, or serialise access with a lock ([backend-common-concurrency-distributed-locks]) |
| The mutated file is untracked (new work not yet committed) | `git checkout -- <path>` cannot restore it and reports nothing; the byte-compared copy from step 2 is the only restore path ([testing-quality-tests-that-cannot-fail]) |
| The suite writes into the same tree (snapshots, generated fixtures) | Exclude those paths from the custody check, or the restore comparison fails on files the suite legitimately changed ([testing-data-artifact-leakage-from-a-suite]) |
| A mutation makes the module fail to import | The suite total drops and the run still looks mostly green — compare test totals to the pre-mutation run, not just pass/fail |
| The mutant survived and the code looks correct | Triage it before writing a test ([testing-quality-surviving-mutant-equivalence-triage]); a custody bug and an equivalent mutant both present as SURVIVED |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Store backups in a flat directory keyed by `os.path.basename(path)` | Key by the flattened relative path | Same-named files in different directories collide, and restore writes one file's contents into the other |
| Confirm the restore with `git status`/`git diff` being clean | Compare bytes against the backup, and assert an original token's presence and count | An untracked file shows a clean diff in both the restored and the destroyed case |
| Compare line counts to check the restore | Compare bytes | Measured: the two crossed files were both 154 lines, so the count matched while the contents were swapped |
| Read `git diff` while the harness runs to see the current code | Wait for process exit **and** an empty backup directory, then read | Files inside the window are the mutation; a normal-looking predicate read there is the injected one |
| Report the run's SURVIVED/KILLED table after fixing a restore bug | Re-run the whole matrix and publish the new table | Corruption flips verdicts both ways — measured, two mutants moved SURVIVED → KILLED after the key was fixed |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states/ — the mutant states (Killed, Survived, No coverage, Timeout) a hand-rolled harness is reproducing; the verdict vocabulary this page's custody rules exist to keep meaningful
- https://pitest.org/quickstart/basic_concepts/ — "'Survived' means the mutation was not detected by the covering test"; a survival caused by a corrupted restore carries the same label as a real one, which is why step 2 gates the next mutation
- https://git-scm.com/docs/git-status — untracked files are reported separately from tracked modifications, and a path the repo does not track contributes no diff — the basis for step 3
- https://docs.python.org/3/library/pathlib.html — `Path.read_bytes()` for the byte-exact restore comparison in step 2
- Field measurement 2026-08-21 (`rtb-unified`, NEWRTB-2936): a harness keyed backups by basename, so `routers/deal.ts` and `schemas/deal.ts` shared one entry. Restoring mutant M8 wrote the schema file's contents into the router, producing `Cannot find module './common.js' imported from src/routers/deal.ts`; `grep -c dealRouter` returned 0, confirming the destruction. Both files were 154 lines, so a line-count check reported them as matching. After re-keying by flattened relative path and re-running, mutants M9 and M10 moved from SURVIVED to KILLED — the earlier verdicts had been produced by the corruption
- Field measurement 2026-08-21 (same session): a `git diff` read while `mutate.py` was mid-cycle showed an adapter predicate as `state = 'created'`; the committed code reads `state < 'active'`, and that substitution was precisely mutation D8. Re-reading after the harness exited, plus an anchor count, established the real text
