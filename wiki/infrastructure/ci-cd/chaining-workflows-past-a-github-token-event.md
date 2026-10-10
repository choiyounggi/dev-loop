---
id: infrastructure-ci-cd-chaining-workflows-past-a-github-token-event
domain: infrastructure
category: ci-cd
applies_to: [github-actions]
confidence: verified
sources:
  - https://docs.github.com/en/actions/concepts/security/github_token
  - https://docs.github.com/en/actions/concepts/workflows-and-actions/reusable-workflows
  - https://docs.github.com/en/rest/actions/workflows?apiVersion=2022-11-28#create-a-workflow-dispatch-event
  - https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run
  - https://github.com/googleapis/release-please-action/blob/main/README.md
last_verified: 2026-10-09
related: [infrastructure-ci-cd-workflow-authored-pull-requests]
---

# A Workflow That Must Start Another Workflow

## When this applies

One GitHub Actions workflow creates a tag, a Release, a branch or a PR, and a
second workflow is meant to react to that event — `on: release: published` →
`npm publish`, `on: push: tags` → build artifacts, a release bot's PR → CI.
Also when the first workflow succeeds, the Release exists, and the second
workflow never starts and shows no failed run.

## Do this

Events made with the repository's `GITHUB_TOKEN` do not start new workflow runs
(GitHub's guard against recursive runs). The two exceptions:
`workflow_dispatch` and `repository_dispatch` always start runs, and a PR opened
or updated with the token starts `pull_request` runs that wait for a user with
write access to approve them. Pick one way to chain:

| Situation | Do |
|-----------|----|
| The follow-up work can run in the releasing workflow | Run it there: add the publish job after the release job with `needs:`, or call it as a reusable workflow (`uses: ./.github/workflows/publish.yml`, `on: workflow_call`) — the called workflow runs as part of the caller |
| The follow-up must stay a separate workflow (own triggers, own history) | Start it explicitly. Either give it `on: workflow_dispatch` with the inputs it needs and run `gh workflow run publish.yml -f tag=$TAG` from a job with `permissions: actions: write`, or give it `on: repository_dispatch` and send that event through the REST API |
| The follow-up must react to the real event (`release`, `push`, `pull_request` checks with no approval click) | Create the event with a GitHub App installation token or a fine-grained PAT instead of `GITHUB_TOKEN` (`token:` on `actions/checkout`, `GH_TOKEN` for `gh`) |

Then **check that the chain fires**: after the first real release, read the
second workflow's run list (`gh run list --workflow publish.yml`) — no new run is
the failure signal, because nothing reports an error.

## Edge cases

| Case | Then |
|------|------|
| A release tool (release-please, changesets) creates the Release or PR | It uses `GITHUB_TOKEN` by default. Its tag and Release start nothing; its PR gets only approval-required `pull_request` runs (release-please's README, older than that exception, says they "will not trigger future GitHub actions workflows"). Pass it an App token or PAT, or publish in the same workflow |
| The dispatched workflow is new and exists only on a feature branch | Merge it to the default branch first: `workflow_dispatch` and `repository_dispatch` start a run only when the workflow file exists on the default branch |
| You chain with `workflow_run` (B starts when A completes) | The token page does not list `workflow_run` among its exceptions. The event docs limit it to three levels of chaining and to workflow files on the default branch. Prove it with one real run before relying on it |
| The dispatched workflow needs the tag or version | Declare it as a `workflow_dispatch` input and pass it with `-f tag=$TAG` |
| The job calls `gh workflow run` with `GITHUB_TOKEN` | Grant `permissions: actions: write` in that job; the dispatch endpoint needs Actions write permission |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Split release and publish into two workflows linked by `on: release` while the Release is created with `GITHUB_TOKEN` | Publish in the same workflow, dispatch explicitly, or create the Release with an App token | The `release` event from `GITHUB_TOKEN` starts no run, and nothing reports it |
| Debug the second workflow's `on:` filter when it never ran | Check which token created the event first | The filter is never evaluated when the event starts no run |

## Sources

- https://docs.github.com/en/actions/concepts/security/github_token — "events triggered by the `GITHUB_TOKEN` will not create a new workflow run, with the following exceptions: `workflow_dispatch` and `repository_dispatch` events always create workflow runs"; for `pull_request` `opened`/`synchronize`/`reopened` the run is created "in an approval-required state" and "a user with write access to the repository can start the runs by selecting Approve workflows to run"; "If you need workflow runs from workflow-created pull requests to execute without requiring approval, use a GitHub App installation access token or a personal access token instead of `GITHUB_TOKEN`" (raw page fetched 2026-10-09)
- https://docs.github.com/en/actions/concepts/workflows-and-actions/reusable-workflows — "When you reuse a workflow, the entire called workflow is used, just as if it was part of the caller workflow"
- https://docs.github.com/en/rest/actions/workflows?apiVersion=2022-11-28#create-a-workflow-dispatch-event — fine-grained tokens need "'Actions' repository permissions (write)"
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run — "You can't use `workflow_run` to chain together more than three levels of workflows"; the `workflow_run`, `workflow_dispatch` and `repository_dispatch` sections each carry the note "This event will only trigger a workflow run if the workflow file exists on the default branch"
- https://github.com/googleapis/release-please-action/blob/main/README.md — "all resources created by `release-please` (release tag or release pull request) will not trigger future GitHub actions workflows, and workflows normally triggered by `release.created` events will also not run"
- Field case 2026-10-09: a CLI package's release design split `release.yml` (creates the Release) from `publish.yml` (`on: release: published`); caught at design review from the token page above, before the first release
