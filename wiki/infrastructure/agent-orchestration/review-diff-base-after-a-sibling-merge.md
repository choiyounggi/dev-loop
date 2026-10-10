---
id: infrastructure-agent-orchestration-review-diff-base-after-a-sibling-merge
domain: infrastructure
category: agent-orchestration
applies_to: [general, git]
confidence: verified
sources:
  - https://git-scm.com/docs/git-diff
  - https://git-scm.com/docs/git-merge-tree
  - https://git-scm.com/docs/git-merge
  - https://git-scm.com/docs/git-worktree
  - "Local reproduction 2026-10-08 (git 2.50.1): sibling merged into the integration branch, task worktree diffed by tip vs merge base"
last_verified: 2026-10-08
verified_model: claude-opus-5-5
related: [infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-ours-resolution-on-a-mixed-content-conflict]
---

# Diffing a Parallel Task After a Sibling Merged Into Its Integration Branch

## When this applies

A reviewer (subagent, coordinator, or human) is about to read one parallel
task's changes — committed on its branch or still uncommitted in its worktree —
after a sibling task was already merged into the integration branch this task
branched from. Also when a review reports that a task deletes code or files its
brief never mentioned, and when choosing how to merge that task's branch.

## Do this

1. **Diff against the merge base, not the integration tip.** `git diff <commit>`
   with one commit compares the working tree with that commit. Once a sibling
   has merged, the integration tip holds the sibling's changes and the task's
   worktree does not, so every sibling change shows up reversed — added lines
   as removals, added files as deletions — and the reviewer reads them as this
   task's work.

| What you review | Command |
|---|---|
| Tracked changes in the task's worktree, committed or not | `git -C <worktree> diff --merge-base <integ>` (Git 2.30+) — the same as `git diff $(git merge-base <integ> HEAD)` |
| New files the worker has not committed | `git -C <worktree> ls-files --others --exclude-standard`, then read each listed file — `git diff` lists tracked paths only |
| The task's committed branch, from any checkout | `git diff <integ>...<task-branch>` — three dots start the diff at the merge base |

2. **Give the reviewer the diff command, not the integration branch name.** A
   brief that says "review against `integ`" invites the single-ref form; name
   the `--merge-base` command (or paste its output) in the review brief.

3. **Check mergeability without touching any worktree.** Run
   `git merge-tree --write-tree <integ> <task-branch>` (Git 2.38+): exit 0
   prints the merged tree id (clean); exit 1 lists the conflicted paths.

4. **Merge with `--no-ff`, in a worktree that holds nothing else.** `--no-ff`
   records one merge commit per task, so the task stays revertable as a unit
   (`git revert -m 1 <merge>`). Then run the merged-tree gate
   ([infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge]).

| Where the integration branch is | Do |
|---|---|
| Not checked out anywhere | `git worktree add <tmp> <integ>`, merge there, `git worktree remove <tmp>` |
| Checked out in another worktree (git refuses a second checkout: `already used by worktree`) | Merge in that worktree; or merge in `git worktree add --detach <tmp> <integ>` and fast-forward the branch where it is checked out (`git merge --ff-only <merge-sha>`) — the detached merge leaves the branch where it was |

## Edge cases

| Case | Then |
|------|------|
| The worker merged or rebased the integration branch into its own branch | `--merge-base` follows it — the merge base becomes the synced tip, so the diff still shows only the task. A base sha recorded at dispatch is now stale and shows the sibling's changes as additions; use it only when the worker never synced |
| A review already reported that the task deletes a sibling's file or lines | Re-run the review on the merge-base diff before sending the finding to the worker. When the deletion is gone from that diff, the single-ref diff produced it; when it is still there, the task does delete it — send that finding back |
| `git merge-base` reports no merge base in a shallow clone | Deepen the history (`git fetch --deepen=<n>` or `--unshallow`) before diffing ([testing-quality-history-dependent-checks-on-shallow-clones]) |
| `merge-tree` exits 1 | Resolve before merging: the conflict is real on the current tip, independent of the review diff |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run `git diff <integ>` from the task's worktree to review it | Run `git diff --merge-base <integ>` there | The single-ref form compares the working tree with the current tip, so each merged sibling change appears as this task removing it |
| Diff against the base sha you recorded at dispatch after the worker synced the integration branch | Use `--merge-base <integ>` | The recorded sha predates the sync, so the sibling's changes appear as this task's additions |
| Send "the task deletes X" from a tip-diff review back to the worker | Re-run the review on the merge-base diff first, and send only the deletions that remain there | Against the tip, every merged sibling change also shows as a deletion; only the merge-base diff separates those from deletions the task made |

## Sources

- https://git-scm.com/docs/git-diff — `git diff <commit>`: "This form is to view the changes you have in your working tree relative to the named <commit>"; "If --merge-base is given, instead of using <commit>, use the merge base of <commit> and HEAD. git diff --merge-base A is equivalent to git diff $(git merge-base A HEAD)"; `A...B`: "starting at a common ancestor of both <commit>. git diff A...B is equivalent to git diff $(git merge-base A B) B". The single-commit `--merge-base` sentence is present in https://git-scm.com/docs/git-diff/2.30.0 and absent from the 2.29.0 page
- https://git-scm.com/docs/git-merge-tree — `--write-tree` "does not make any new commits and does not read from or write to either the working tree or index"; "For a successful, non-conflicted merge, the exit status is 0. When the merge has conflicts, the exit status is 1"; the mode arrived in Git 2.38.0 (https://github.com/git/git/blob/master/Documentation/RelNotes/2.38.0.adoc: "git merge-tree" learned a new mode where it takes two commits and computes a tree that would result in the merge commit)
- https://git-scm.com/docs/git-merge — "With --no-ff, create a merge commit in all cases, even when the merge could instead be resolved as a fast-forward"
- https://git-scm.com/docs/git-worktree — "By default, add refuses to create a new worktree when <commit-ish> is a branch name and is already checked out by another worktree" (`--force` overrides); `--detach`: "With add, detach HEAD in the new worktree"
- Local reproduction 2026-10-08 (git 2.50.1, Apple Git-155): worktrees t1 and t2 branched from one base; t1 merged into `integ` with `--no-ff`. In t2's worktree, `git diff integ --stat` listed t1's `sib.txt` as deleted and t1's added line as removed; `git diff <base-sha>` and `git diff --merge-base integ` listed only t2's two changes. An uncommitted new file appeared in neither diff and only in `git ls-files --others --exclude-standard`. After a worker merged `integ` into its own branch, `--merge-base integ` still showed only its own file, while the dispatch base sha showed the sibling's two files as additions. `git merge-tree --write-tree` exited 1 with a `CONFLICT (content)` list on a conflicting pair and 0 with a tree id on a clean pair; `git worktree add <tmp> integ` while `integ` was checked out failed with `fatal: 'integ' is already used by worktree at …`; a `--no-ff` merge in a `--detach` worktree created the merge commit and left `integ` unmoved
- Field case 2026-10-08 (orchestration run oi1008): task t214 branched at 63c21c8 while `integ` advanced to 35f17ec with sibling t213; the review pointed at 63c21c8 approved cleanly, `merge-tree` showed no conflict, and t214 merged as 9805ce9
