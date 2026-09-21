---
id: infrastructure-agent-orchestration-sequential-identifiers-across-parallel-workers
domain: infrastructure
category: agent-orchestration
applies_to: [general, git]
confidence: verified
sources:
  - https://docs.djangoproject.com/en/5.1/topics/migrations/
  - https://docs.djangoproject.com/en/5.1/ref/django-admin/#makemigrations
  - https://guides.rubyonrails.org/v3.2/migrations.html
  - https://git-scm.com/docs/git-merge
  - https://github.com/npryce/adr-tools/issues/102
last_verified: 2026-09-03
related: [infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-shared-run-state, qa-document-verification-spec-document-gates]
---

# Assigning Sequential Identifiers to Artifacts Made by Parallel Workers

## When this applies

Several parallel agent workers, each confined to its own worktree/branch, each
independently create a new sequentially-numbered artifact — an RFC, ADR,
migration, or ticket number — as part of their task. Also when reviewing a
brief that tells a worker to "check the next free number" before creating one.

## Do this

1. **Assign the number at dispatch time, from the coordinator, not from the
   worker.** The coordinator holds the one place that has seen every sibling
   task; bake the assigned number into the worker's brief
   (`Create RFC-0035-<slug>.md`) rather than asking the worker to compute it.
2. **Replace any "check existing numbers first" instruction with the assigned
   number.** A worker confined to its own worktree/branch point can only see
   artifacts that existed at that branch point — a sibling worker's
   not-yet-merged number is invisible to it, so the instruction is
   unexecutable, not merely risky.
3. **When numbers cannot be pre-assigned (a worker discovers the need for one
   mid-task, not named in its brief), use a collision-proof identifier
   instead of a sequential one** — a timestamp (Rails switched migration
   filenames to creation-time timestamps for exactly this reason) or a UUID —
   and leave renumbering to a single later pass on the merged tree, not to
   the worker.
4. **Put the numbering check in the merge-time lint, and make it a hard
   failure**, not a warning: `git merge` combines two branches' distinct new
   files without any conflict — non-overlapping additions "are incorporated
   in the final result verbatim" — so two same-numbered artifacts merge
   silently and only a post-merge lint over the combined tree catches the
   duplicate.

| Case | Do |
|------|----|
| Coordinator dispatches N parallel tasks that each produce one numbered artifact | Assign each task's number in the dispatch brief before the worker starts |
| A worker's brief did not anticipate the need for a number (discovered mid-task) | Generate a timestamp or UUID identifier instead of guessing a sequential number |
| The artifact scheme is inherently timestamp/UUID-based (Rails-style migrations) | No coordinator assignment needed — collision is already structurally prevented |
| The numbering/uniqueness lint runs per-worker inside each worktree | Move it to run once, after merge, over the integrated tree — a per-worktree run cannot see sibling numbers either |

## Edge cases

| Case | Then |
|------|------|
| Two workers are dispatched from the same branch point and neither's task depends on the other's artifact | Still assign both numbers at dispatch — same-branch-point siblings collide exactly like sequential ones, per the adr-tools numbering-conflict report |
| A worker's task is later dropped or fails and its assigned number is never used | Leave the gap and give any later task the next fresh number; recycling the unused number into another worker's task reintroduces the same race |
| The coordinator itself cannot see a number some other, unrelated run already claimed | Track assigned numbers in the shared run-state directory ([infrastructure-agent-orchestration-shared-run-state]), not by scanning worker worktrees |
| The project's existing convention is "developer picks the next number by hand" (pre-dating agent workers) | Migrate to coordinator-assigned numbers; a note saying "resolve manually on conflict" covers nothing, because distinct files raise no merge conflict to resolve |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Tell each worker "look at the current highest number in the repo and use the next one" | Assign the number in the dispatch brief | The worker's worktree/branch point cannot see a sibling's number until after merge — the check is unexecutable, not merely racy |
| Rely on the artifact's per-worktree review/lint to catch duplicate numbers | Add the same check as a merge-time gate over the integrated tree | A per-worktree lint sees only that worker's own artifact; the duplicate exists only once both are present, i.e. after merge |
| Expect `git merge` to flag two artifacts that claim the same number | Run the numbering lint on the merged tree as a gate | `git merge` conflicts on overlapping changes to the same path, not on two different files whose content happens to claim the same logical number |

## Sources

- https://docs.djangoproject.com/en/5.1/topics/migrations/ — "you and another developer have both committed a migration to the same app at the same time, resulting in two migrations with the same number"; Django prompts to linearize them
- https://docs.djangoproject.com/en/5.1/ref/django-admin/#makemigrations — `--merge`: "Enables fixing of migration conflicts"
- https://guides.rubyonrails.org/v3.2/migrations.html — "With multiple developers it was easy for these to clash requiring you to rollback migrations and renumber them. With Rails 2.1+ this is largely avoided by using the creation time of the migration to identify them"
- https://git-scm.com/docs/git-merge — non-overlapping changes "are incorporated in the final result verbatim"; conflicts are raised only when both sides changed the same area
- https://github.com/npryce/adr-tools/issues/102 — "ADR numbering sequence may break when merging multiple PRs": "Dev A creates a PR with an ADR (he/she denotes that ADR with number 6). Dev B creates a PR with an ADR (he/she denotes that ADR with number 6)" — merged at different times, two ADRs share a number
- Field evidence 2026-08-25 (linkly repo, worker t119 branched from da1256e): sibling worker t112 had already created RFC-0034 on its own branch; t119, unable to see it, created a different RFC-0034 too. Both merged without a git conflict (distinct filenames); `rfc_lint.py`'s `check_numbering` (§3, no duplicate numbers) only caught the duplicate after the merge
