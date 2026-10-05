---
id: infrastructure-agent-orchestration-ours-resolution-on-a-mixed-content-conflict
domain: infrastructure
category: agent-orchestration
applies_to: [general, git]
confidence: field-tested
sources:
  - https://git-scm.com/docs/git-checkout
  - https://git-scm.com/docs/git-merge
  - https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue
last_verified: 2026-09-03
related: [infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-worktree-isolated-workers, backend-common-change-impact-widening-a-closed-value-table, qa-deliverables-quantitative-claims-in-a-published-document, infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge]
---

# Resolving a Parallel-Branch Document Conflict With `--ours` Plus a Count Fix

## When this applies

Merging parallel worker branches produces a textual conflict in a document whose
own count several branches edited — a README "N tests" line, a table's row count,
a "documents: N" figure — and `git checkout --ours <file>` followed by a manual
number correction is the tempting one-line resolution.
Also applies earlier, when writing the brief for parallel workers who will
each update such a count, before any branch is merged.

## Do this

1. Before choosing `--ours`, read the branch side's changes to the conflicted file
   on their own: `git show :3:<file>` (theirs) against `git show :2:<file>` (ours),
   or `git diff <merge-base>...<branch> -- <file>`, and grep that diff for anything
   besides the count — table rows, a new section, changed body text.
2. Choose the resolution by what the branch-side diff contains:

| Branch-side diff of the file | Do |
|------------------------------|----|
| Counts only | `git checkout --ours <file>`, then set the count from the merged content |
| Counts plus content (rows, sections, prose) | Resolve by hand: keep the branch's content additions, then set the count from the merged result — a whole-file `--ours` discards the content with the count, silently |
| Both sides added distinct content and both touched the count | Merge both content additions by hand, then compute the count from the merged file; neither `--ours` nor `--theirs` alone is right |

3. When a document-currency test fails after the merge, read it as the detector of
   exactly this discard: restore the lost lines from the branch's own diff
   (`git show <branch>:<file>`) rather than re-deriving them by hand.
4. When no such test exists, run step 1 regardless — without it the loss is silent
   until a human notices a missing row.

## Edge cases

| Case | Then |
|------|------|
| The conflicted region is large and slow to read | Scope the diff to the file (`git diff <merge-base>...<branch> -- <file>`), not the whole branch |
| The count is computed by a script or test from the file's own contents | Run that computation on the merged file and take its output; a hand-corrected count drifts on the next merge |
| The merge reported no textual conflict at all | This page does not apply; the hazard there is a semantic conflict between green branches, gated by building and testing the merged tree |
| You are writing the brief for workers who will each change a count a currency test checks | Tell each worker to write its own measured value into the file so that worker's branch stays green, and reconcile the count from the merged file per the Do-this table after all branches land; an instruction to leave the count alone leaves that worker's own suite red |
| The currency test accepts an approximate count within a tolerance band ("~N tests" checked at ±5%) and your branch adds tests to an integration branch other branches also merge into | Pick the claimed value inside the overlap of the bands around every count the file will be checked against — your branch's count, and the integration tip's count without your change — so the test stays green whichever merge lands first; write that one value into every copy of the claim (prose line, pasted run output, each language's README) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Resolve a count conflict with `git checkout --ours <file>` and correct the number | Diff the branch side's changes to that file first; use `--ours` only when they are counts-only | `--ours` takes the whole file from one side — content riding along with the count is discarded with no error |
| Re-type a lost table row from memory after the currency test fails | Restore it from `git show <branch>:<file>` | The branch still holds the exact row; a retyped one can differ from what the branch's tests were written against |
| Tell parallel workers "do not touch the README count" to avoid a merge conflict | Tell each worker to write its own measured value so the currency test in its branch stays green, then reconcile the count from the merged file | A test that checks the count leaves the worker no freedom not to fix it; a stale count fails that worker's own suite before any merge happens |
| Set a band-checked count to your own branch's exact measured value | Choose a value whose band also contains the integration tip's count | A value that fits only your branch turns the test red on the integration branch, or the reverse, depending on which merge lands first |

## Sources

- https://git-scm.com/docs/git-checkout — `--ours`/`--theirs`: "When checking out paths from the index, check out stage #2 (ours) or #3 (theirs) for unmerged paths"
- https://git-scm.com/docs/git-merge — on a conflict "the index file records up to three versions: stage 1 stores the version from the common ancestor, stage 2 from HEAD, and stage 3 from MERGE_HEAD"; to resolve, "look at the originals: git show :1:filename, :2:filename, or :3:filename" and "look at the diffs: git diff or git log --merge -p <path>"
- Field evidence 2026-08-24 (linkly, `orch/enterprise-audit-0824` integration): a README count conflict was resolved with `--ours` plus a manual count fix, which dropped task t93's RFC-0028 table row; `test_readme_currency` failed on 4 cases and the row was restored from the branch's own diff in a follow-up commit
- Field evidence 2026-08-25 (linkly, task briefs t112/t115/t117 vs t119): briefs t112/t115/t117 told each worker to leave its own measured value in place, and all three branches stayed green through merge with the count reconciled afterward; brief t119 instead said "do not touch the README count", and the suite failed 4 cases (2702 vs 2706 expected), all `test_readme_currency`, because the worker's branch could not go green without updating the count its own test checked
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue — a merge queue checks that a pull request's changes "pass all required status checks when applied to the latest version of the target branch and any pull requests already in the queue": a branch green on its own is not evidence the target stays green
- Field evidence 2026-10-05 (linkly, `orch/open-issues-1002` task t187a): `test_readme_currency` checks the README "~N tests" prose and the pasted `Ran N tests` line, in both the English and Korean READMEs, against the discovered count at ±5% (`SUITE_CLAIM_BAND = 0.05`). The task branch had 4108 tests, the integration tip 4075; the claim was set to 4090, inside both bands (|4108−4090| = 18 ≤ 205.4; |4075−4090| = 15 ≤ 203.75), in all four places. `test_readme_currency` gave "Ran 10 tests OK" and the full suite "Ran 4108 tests OK (skipped=1)"
