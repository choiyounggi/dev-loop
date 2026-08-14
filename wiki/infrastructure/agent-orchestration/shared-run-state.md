---
id: infrastructure-agent-orchestration-shared-run-state
domain: infrastructure
category: agent-orchestration
applies_to: [general, git-worktree]
confidence: field-tested
sources:
  - https://git-scm.com/docs/git-worktree
  - https://man.openbsd.org/tmux
last_verified: 2026-08-05
related: [infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-worktree-isolated-workers, backend-common-concurrency-distributed-locks, backend-common-jobs-scheduled-job-overlap, testing-data-test-data-and-isolation]
---

# Orchestration State Kept in a Shared Directory Inside the Repository

## When this applies

Several agent or worker sessions work in one repository at the same time and
coordinate through files in it — a status directory, task briefs, escalation
records, a lock or claim file — and the directory path is fixed rather than
per-run. Also when starting an orchestration in a repo that may already have one
running.

## Do this

1. **Namespace the state directory per run.** Give each orchestration a run id
   generated at start and write everything under it:
   `.orchestration/<run-id>/{status,briefs,escalations}/`. Watchers glob inside
   their own run id only, so another run's writes cannot wake them.

2. **Survey the state directory before writing anything into it.** List it and
   compare against the task ids this run created.

| What the survey finds | Do |
|-----------------------|----|
| Empty, or only this run's ids | Proceed |
| Ids this run did not create | Establish whether the other run is live (step 3) before creating any task |
| A run id whose tasks are all terminal and older than the session | Archive the directory, then proceed |

3. **Confirm a foreign run is live from the repository itself, not from the state
   files.** Check `git worktree list` for worktrees this run did not create,
   `git branch --sort=-committerdate` for recent task branches, and the default
   branch's HEAD against the commit this run started from. A stale directory and a
   concurrently running orchestration look the same in the status files.

4. **When a live foreign run is confirmed, stop and surface it.** Report the
   overlapping task ids, the foreign worktrees, and whether the default branch has
   moved. Two orchestrations decomposing the same goal produce two implementations
   of the same work in different files, and the conflict appears at merge, after
   both have paid for the work.

5. **Record the run id in every artifact the run emits** — branch names
   (`<run-id>/<task>`), worktree directory names, status files, and commit trailers
   — so ownership is readable without opening the state directory.

6. **Re-check the default branch's HEAD at the approval gate.** Compare it to the
   value captured at start; when it moved, identify what merged before treating
   your integration branch as current.

## Edge cases

| Case | Then |
|------|------|
| The state directory is committed to the repo | Add the run-id subtree to `.gitignore` and keep only the schema/README tracked; committed status files collide as merge conflicts on every worker branch |
| Two runs must share one repo deliberately | Give each its own run id and its own branch prefix, and require both to write only inside their own subtree; the repo is shared, the state is not |
| Your watcher woke on a signal for an unknown task id | Do not act on it. A wake is not ownership — filter to this run's task ids, then re-check whether a foreign run is live |
| A foreign run merged your task branches without your gate | Stop and reconstruct from `git reflog` and the default branch's history before continuing; the integration branch no longer reflects only your approvals |
| Worktrees were removed but their branches remain | `git worktree prune` clears the administrative files; the branches persist and still signal a prior run — read branch names for the run id |
| Run ids are generated from a timestamp at one-second resolution | Two runs starting in the same second collide; add a random suffix or the process id |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write status into a fixed `.orchestration/status/` path | Write into `.orchestration/<run-id>/status/` | A fixed path is shared mutable state between runs that never agreed to share it |
| Treat an unfamiliar task id in the state directory as leftover junk | Check worktrees, recent branches, and the default branch HEAD first | Stale state and a live concurrent run are indistinguishable from the files alone |
| Have your watcher act on every status file it sees | Filter to the task ids this run created | Otherwise another run's completion signal reads as your own task finishing |
| Continue after noticing the default branch moved | Identify what merged, then decide | Your integration branch may already be missing or duplicating merged work |

## Sources

- https://git-scm.com/docs/git-worktree — linked worktrees share one repository with separate working directories
- https://man.openbsd.org/tmux — session and pane management for substrate-level coordination
