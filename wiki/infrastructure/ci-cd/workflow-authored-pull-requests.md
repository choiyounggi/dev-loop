---
id: infrastructure-ci-cd-workflow-authored-pull-requests
domain: infrastructure
category: ci-cd
applies_to: [github-actions]
confidence: verified
sources:
  - https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository
  - https://docs.github.com/en/rest/actions/permissions?apiVersion=2022-11-28
  - https://docs.github.com/en/actions/concepts/security/github_token
  - https://docs.github.com/en/rest/repos/rules?apiVersion=2022-11-28
  - https://cli.github.com/manual/gh_pr_merge
  - https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-the-automatic-deletion-of-branches
  - https://github.com/cli/cli/issues/9073
last_verified: 2026-09-06
related: [infrastructure-ci-cd-unparseable-workflow-file, infrastructure-ci-cd-secrets-handling, infrastructure-ci-cd-pipeline-structure]
---

# A Workflow That Opens and Merges Its Own Pull Request

## When this applies

A GitHub Actions workflow (pin bump, dependency sync, generated-file refresh)
must land a change on a branch that a ruleset or branch protection closes to
direct pushes, so it pushes a branch, opens a PR with `gh pr create`, and
merges it. Also when such a pipeline "almost works": the push succeeds and the
PR step fails, or the PR opens and then sits unmerged with no checks.

## Do this

Four independent settings decide whether this pipeline runs end to end; check
each before the first run rather than discovering them one failure at a time.

| Step | Check first | Then |
|------|-------------|------|
| 1. The workflow may create PRs | `gh api repos/{owner}/{repo}/actions/permissions/workflow` shows `"can_approve_pull_request_reviews": true` | Off by default, and `permissions: pull-requests: write` in the workflow does not replace it: the push succeeds and only `gh pr create` fails with "GitHub Actions is not permitted to create or approve pull requests". Turn it on: `gh api -X PUT repos/{owner}/{repo}/actions/permissions/workflow -F can_approve_pull_request_reviews=true` (Settings → Actions → General → "Allow GitHub Actions to create and approve pull requests") |
| 2. The protected branch accepts the bot's merge | The repository's owner type | On an organization repo a ruleset can list the GitHub Actions app as a bypass actor. On a personal repo the API rejects an `Integration` bypass actor (`422 Actor GitHub Actions integration must be part of the ruleset source or owner organization`), and a ruleset binds administrators too — so leave `bypass_actors` empty, require a PR with `required_approving_review_count: 0`, and let the workflow merge its own PR (`contents: write` + `pull-requests: write` + step 1) |
| 3. The PR gets check runs | Which token pushed the branch | A branch pushed with `GITHUB_TOKEN` triggers no `push`/`pull_request` workflow (recursion guard), so the PR has zero check runs; with required status checks on, the PR waits indefinitely and the pipeline stops with no error. Push and open the PR with a fine-grained PAT or a GitHub App installation token (`token: ${{ secrets.PIN_SYNC_TOKEN }}` on `actions/checkout`, `GH_TOKEN` for `gh`) |
| 4. The merge happens and the branch goes away | Required checks exist → `gh pr merge --auto --squash`; none → `gh pr merge --squash` merges immediately | `--auto` schedules the merge server-side and `--delete-branch` is not applied to that later merge (cli/cli#9073) — enable the repository setting "Automatically delete head branches" (`delete_branch_on_merge`) so every path cleans up |

While step 3 is not yet done, run the same test commands inside the workflow
before `gh pr create` and say so in the PR body, so a reader knows why the PR
carries no external checks.

## Edge cases

| Case | Then |
|------|------|
| Step 1 is on and `gh pr create` still fails | The token is a PAT without `pull_requests: write` on this repo, or an organization-level Actions setting overrides the repository — read the error's noun (setting vs permission) before changing either |
| The same required checks are wanted on the bot PR and on human PRs | Step 3 is the prerequisite: required checks only ever see runs, and a `GITHUB_TOKEN` branch produces none — add the PAT before enabling the requirement, or the bot PRs stall from that moment |
| The workflow is fired by `workflow_dispatch` or `repository_dispatch` | Those two events create runs even when triggered with `GITHUB_TOKEN`; every other event does not |
| The bot's PR needs no review but the ruleset requires one | `required_approving_review_count: 0` keeps the PR rule (no direct pushes) while letting the author merge; a count of 1 blocks the bot because a PR author cannot approve their own PR |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `pull-requests: write` to the workflow and rerun after "not permitted to create or approve" | Turn on the repository setting (step 1) — the permissions block is necessary and not sufficient | The setting is a separate switch, off by default, and no permission scope replaces it |
| Add the GitHub Actions app as a ruleset bypass actor on a personal repo | Leave bypass empty and route the bot through a PR it merges itself (step 2) | The API refuses an `Integration` actor outside an organization, and admin status does not exempt anyone from a ruleset |
| Enable required status checks on a repo whose bot pushes with `GITHUB_TOKEN` | Switch the push and PR to a PAT/App token first (step 3) | The bot's PRs would wait for checks that cannot start — a stall, not a failure |
| Rely on `gh pr merge --auto --delete-branch` to remove the branch | Enable `delete_branch_on_merge` on the repository | The deferred merge does not carry the flag |

## Sources

- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository — the "Allow GitHub Actions to create and approve pull requests" setting
- https://docs.github.com/en/rest/actions/permissions?apiVersion=2022-11-28 — `GET`/`PUT /repos/{owner}/{repo}/actions/permissions/workflow`, field `can_approve_pull_request_reviews`: "if GitHub Actions can submit approving pull request reviews"
- https://docs.github.com/en/actions/concepts/security/github_token — "events triggered by the `GITHUB_TOKEN` will not create a new workflow run, with the following exceptions: `workflow_dispatch` and `repository_dispatch`"; "use a GitHub App installation access token or a personal access token instead of `GITHUB_TOKEN`"
- https://docs.github.com/en/rest/repos/rules?apiVersion=2022-11-28 — ruleset `bypass_actors[].actor_type` includes `Integration`; the personal-repo 422 for an Integration actor is field-observed (below), not stated in the reference
- https://cli.github.com/manual/gh_pr_merge — `--auto`: "Automatically merge only after necessary requirements are met"; `--delete-branch`: "Delete the local and remote branch after merge"
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-the-automatic-deletion-of-branches — "You can have head branches automatically deleted after pull requests are merged in your repository"
- https://github.com/cli/cli/issues/9073 — "`gh pr merge --auto -d` does not delete the branch after merge" (open)
- Field reproduction 2026-08-25 (choiyounggi/groundwork, `.github/workflows/sync-dev-loop-pin.yml`, PRs #15–#27): the push succeeded and `gh pr create` alone failed until `can_approve_pull_request_reviews` was set; creating ruleset 21371046 with the Actions app (`actor_id` 15368, `Integration`) as bypass actor returned the 422 above on the personal repo and succeeded with `bypass_actors: []` plus a `pull_request` rule at 0 approvals; PR #22 (pushed with `GITHUB_TOKEN`) had `check-runs total_count=0`, PR #25 (pushed with a PAT) had 6; PR #27 merged via `--auto` after `bats`, `shellcheck`, `version-sync` went green; `delete_branch_on_merge` is on
