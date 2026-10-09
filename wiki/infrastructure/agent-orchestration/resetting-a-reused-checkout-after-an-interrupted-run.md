---
id: infrastructure-agent-orchestration-resetting-a-reused-checkout-after-an-interrupted-run
domain: infrastructure
category: agent-orchestration
applies_to: [general, git]
confidence: verified
sources:
  - https://git-scm.com/docs/git-reset
  - https://git-scm.com/docs/git-apply
  - https://git-scm.com/docs/git-status
  - "Local reproduction 2026-10-08 (git, macOS): a tracked edit and an untracked file before reset --hard; git diff carried only the tracked edit"
  - "Field case 2026-10-08 (dev-loop knowledge-flush, ~/.dev-loop/repo reused across runs)"
last_verified: 2026-10-08
related: [infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-usage-limit-paused-workers, infrastructure-agent-orchestration-worktree-isolated-workers]
---

# Resetting a Reused Checkout After an Interrupted Run

## When this applies

An automated job (a scheduled or hook-spawned agent session, a pipeline on a
persistent runner) starts by resetting a working directory it reuses across
runs — `git checkout main && git reset --hard origin/main`, `git clean`, wiping
a build directory — and an earlier run of the same job may have stopped part
way (crash, usage limit, timeout) before it committed.

## Do this

1. **Look before the reset.** Run these on the reused directory:

| Command | Shows |
|---------|-------|
| `git status --porcelain` | Uncommitted tracked edits (` M`) and untracked files (`??`) |
| `git branch --show-current` | Which branch the last run left checked out |
| `git log --branches --not --remotes --oneline` | Local commits on any branch that were never pushed |
| `git log HEAD --not --remotes --oneline` | Unpushed commits on a detached HEAD, which `--branches` leaves out |

2. **Act on what you found:**

| Found | Do |
|-------|----|
| Clean tree, no unpushed commits | Reset as planned |
| Uncommitted edits or untracked files | Preserve them first: `git switch -c wip/<run-id>`, `git add -A`, `git commit -m "WIP: interrupted run <run-id>"`, then switch back and reset |
| You need a file instead of a branch | `git add -A`, `git diff --cached > saved.patch`, then `git apply --check -R saved.patch` must pass before the reset — it proves the patch matches what is on disk |
| Unpushed commits on the branch you are about to reset (e.g. `main`), or on a detached HEAD | `git branch wip/<run-id>` at that commit first, then reset — `reset --hard origin/main` moves the branch off them and only the reflog keeps them |
| Unpushed commits on another branch | The reset does not touch them; record the branch name so this run can decide on it |

3. **Decide resume or discard only after preserving.** The preserved work was
   never reviewed: re-check every claim, link and test in it before adopting
   it, the same as a stranger's draft.

## Edge cases

| Case | Then |
|------|------|
| `git checkout main` refuses because local edits would be overwritten | That refusal is the leftover signal — run step 2 instead of forcing the checkout |
| Leftovers are untracked only | `reset --hard` keeps untracked files that are not in the way, so they survive into this run and a later `git add <dir>` sweeps them into your commit unread — preserve or remove them in step 2 |
| The job also runs `git clean -fdx` | `-x` also deletes ignored files, which `git status --porcelain` does not list and neither the WIP commit nor the patch carries: list them with `git status --porcelain --ignored` (`!!` lines) and copy out any you need before the clean |
| Several worktrees share the repository | Use a WIP commit, not `git stash`: `refs/stash` is shared by every worktree, so another run can pop your entry |
| The job holds a lock across runs | Preserve under the lock you hold, before any step that can be interrupted again |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Start every run with an unconditional `reset --hard origin/main` | Run step 1, preserve, then reset | The interrupted run's only copy of its work is in that directory; the reset discards tracked edits without a trace |
| Save leftovers with `git diff > saved.patch` | `git add -A` first, then `git diff --cached` (or a WIP commit) | `git diff` leaves untracked files out of the patch |

## Sources

- https://git-scm.com/docs/git-reset — `--hard`: "Overwrite all files and directories with the version from <commit>, and may overwrite untracked files. Tracked files not in <commit> are removed so that the working tree matches <commit>."
- https://git-scm.com/docs/git-apply — `--check`: "see if the patch is applicable to the current working tree and/or the index file and detects errors"; `-R, --reverse`: "Apply the patch in reverse"
- https://git-scm.com/docs/git-status — `--porcelain` output format (`XY PATH`, `??` for untracked)
- Local reproduction 2026-10-08 (git on macOS): with one tracked edit and one untracked file, `git diff > patch` held 1 file (the tracked edit only); after `git reset --hard HEAD` the tracked edit was gone and the untracked file remained (`?? untracked.md`); re-applying the patch and then `git apply --check -R` passed
- Field case 2026-10-08 (dev-loop knowledge-flush, which starts with `checkout main` + `reset --hard origin/main` in a checkout reused across runs): a run found 19 uncommitted files from the previous run, which had stopped at the account usage limit before committing; a patch verified with a reverse-apply check plus a WIP commit preserved them, and they shipped in the next PR
