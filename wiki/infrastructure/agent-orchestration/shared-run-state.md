---
id: infrastructure-agent-orchestration-shared-run-state
domain: infrastructure
category: agent-orchestration
applies_to: [general, git-worktree]
confidence: field-tested
sources:
  - https://git-scm.com/docs/git-worktree
  - https://man.openbsd.org/tmux
last_verified: 2026-09-03
related: [infrastructure-agent-orchestration-unattended-worker-questions, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-worktree-isolated-workers, backend-common-concurrency-distributed-locks, backend-common-jobs-scheduled-job-overlap, testing-data-test-data-and-isolation, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge]
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
| The coordinator re-delivers a prompt to a stalled worker and also re-seeds that task's status file | Reset the status **before** sending the prompt, never after — the file is last-write-wins, and the worker's first progress signal can land between your send and your reset. The overwrite leaves the watcher waiting on a phase the worker already left while the worker waits for the next instruction: a deadlock with both sides idle |
| You are asked to resume because "the coordinator session died", and `tmux ls` shows only workers | `tmux ls` lists the sessions of one tmux server; a coordinator in an ssh pty, another terminal app, or on another socket (`-L`/`-S`) is invisible to it. Before taking the role require both absences: no coordinator or `watch-status.sh` process in `ps -Ao lstart,command`, and no status file or review under `.orchestration/` with an mtime later than your own session start. A present process or a fresh artifact proves a live coordinator; a missing watcher alone proves nothing (a coordinator between polls runs no watcher). Two coordinators send conflicting prompts to the same worker |
| Escalation records arrive in bulk with paths under a test runner's temp root (`bats-run-*`) | A worker ran a guard-invoking test suite with the run's escalation directory still exported; the records are fixtures, not asks. Remove them, clear the watcher's pending state, and have the worker override the exported directory before that suite ([testing-data-test-data-and-isolation]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write status into a fixed `.orchestration/status/` path | Write into `.orchestration/<run-id>/status/` | A fixed path is shared mutable state between runs that never agreed to share it |
| Treat an unfamiliar task id in the state directory as leftover junk | Check worktrees, recent branches, and the default branch HEAD first | Stale state and a live concurrent run are indistinguishable from the files alone |
| Have your watcher act on every status file it sees | Filter to the task ids this run created | Otherwise another run's completion signal reads as your own task finishing |
| Continue after noticing the default branch moved | Identify what merged, then decide | Your integration branch may already be missing or duplicating merged work |
| Re-seed a task's status to `pending` after delivering a re-prompt | Reset first, then send, and let the worker's next write own the file | Two uncoordinated writers on one status file resolve by last write; the coordinator's late reset erases the worker's progress signal and the pane log and the file then disagree |
| Take over as coordinator because `tmux ls` shows no coordinator session | Check `ps` for the coordinator/watcher process and the run's artifact mtimes against your session start | The coordinator usually runs outside tmux; "not in tmux" is not "dead" |

## Sources

- https://git-scm.com/docs/git-worktree — linked worktrees share one repository with separate working directories
- https://man.openbsd.org/tmux — session and pane management for substrate-level coordination; `list-sessions` lists the sessions managed by one server, and `-L`/`-S` select a different server
- `man ps` (macOS/BSD) — `-A` selects every process, `-o lstart,command` prints the exact start time and the command line
- Field reproduction 2026-09-01 (agent-crew orchestration): `tmux ls` showed four workers only, while `ps -Ao lstart,command` showed the coordinator (PID 54780, started 13:04, on an ssh pty) alive, and `reviews/t3-messaging-r1.md` and `reviews/t4-worksurfaces-r1.md` were created after the resuming session started; a commit-approval prompt sent by the second coordinator collided with the first's rework instruction and left two commits (9177841 → d3a378b) on the t3 branch
- Field reproduction 2026-09-02 (sanddab orchestration): 175 records under `.orchestration/escalations/`, every one carrying a `bats-run-*` fixture path, produced by one worker running the guardrails bats suite with `GROUNDWORK_ESCALATION_DIR` exported; `watch-status.sh` exited 5 on them until they were removed
- https://en.wikipedia.org/wiki/Race_condition — programs colliding on a shared file produce order-dependent results; coordination (locking or a single writer) is required for a deterministic outcome
- Field evidence 2026-08-17 (linkly run iss0817, task t60): the worker's `plan_ready` write (12:53:0x) was overwritten by the coordinator's `pending` re-seed (12:53:07) issued after the re-prompt was sent — the tmux pane recorded "status set to plan_ready" while the file read `pending`, and the watch waited on a phase the worker had already passed. Moving the reset before the send removes the window
