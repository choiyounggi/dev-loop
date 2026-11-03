---
id: infrastructure-ci-cd-rerunnable-multi-artifact-release
domain: infrastructure
category: ci-cd
applies_to: [github-actions, npm]
confidence: verified
sources:
  - https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs
  - https://docs.npmjs.com/cli/v6/commands/npm-publish/
  - https://github.com/open-stl/openstellar-tool-search/pull/20
  - https://github.com/tangentyh/pi-collections/pull/30
  - https://github.com/rnw-community/mobile-ci/issues/140
last_verified: 2026-11-03
related: [infrastructure-ci-cd-chaining-workflows-past-a-github-token-event, infrastructure-ci-cd-workflow-authored-pull-requests, backend-common-jobs-idempotent-handlers]
---

# A Release Job That Makes Several Artifacts and Must Survive a Re-run

## When this applies

One CI release job makes several external artifacts in sequence — push a tag,
create a GitHub Release, publish to npm (or another registry), commit a version
bump — and a single check ("the tag already exists → skip") decides whether the
job runs. Also when a release run failed partway and you are about to re-run it.

## Do this

1. **Give every artifact its own "already exists?" check**, and run each step
   only when its own artifact is missing. A tag that exists says nothing about
   the steps that come after it.

| Artifact | Exists check | Run the step when |
|----------|--------------|-------------------|
| Tag | `git ls-remote --exit-code --tags origin "refs/tags/$TAG"` | exit code 2 (no match) |
| GitHub Release | `gh release view "$TAG"` | non-zero exit |
| npm version | `npm view "$PKG@$VER" version` | the error is `E404`; any other failure (network, auth) fails the job |
| Version-bump commit | read the file on the remote default branch (`git show origin/main:package.json`) | the remote file does not carry `$VER` |

2. **Start any commit step from the current remote default branch.** A re-run
   uses the same `GITHUB_SHA` and `GITHUB_REF` as the original event, so its
   checkout is older than any bot commit the first attempt already pushed.
   Fetch and check out `origin/main` before setting the version and committing.

3. **Prove the checks both ways before relying on them.** Run the check block
   under `bash -e` (the Actions default shell) once against a version that is
   fully released (every check reports "exists") and once against a version
   that does not exist (every check reports "missing").

## Edge cases

| Case | Then |
|------|------|
| `npm view` for a missing version exits non-zero | Capture its output and exit code without letting `bash -e -o pipefail` abort the step (`out=$(npm view … 2>&1) || rc=$?`), then match `E404` in `out` |
| The run was cancelled while uploading Release assets | `gh release view` succeeds although assets are missing. Create the Release as a draft, upload every asset, then publish it with `gh release edit "$TAG" --draft=false`; or compare the asset list against the expected list |
| The npm version exists but was built from a different commit | Fail the job and ask for a version bump; npm never accepts the same name and version twice, even after `npm unpublish` |
| Publish runs in a second workflow triggered by the Release | That workflow may never start → `[infrastructure-ci-cd-chaining-workflows-past-a-github-token-event]` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Skip the whole release when the tag exists | Check each artifact and run only the missing steps | A run that failed after tagging re-runs as "already released", ends green, and the missing package stays missing |
| Commit the version bump from the re-run's checkout | Check out `origin/main` first | The re-run checkout predates the bot commit and the push is rejected or rewrites history |

## Sources

- https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs — "The workflow will also use the same `GITHUB_SHA` (commit SHA) and `GITHUB_REF` (git ref) of the original event that triggered the workflow run"
- https://docs.npmjs.com/cli/v6/commands/npm-publish/ — publishing fails when the name and version already exist in the registry; a name and version can never be reused, even after `npm unpublish`
- https://github.com/open-stl/openstellar-tool-search/pull/20 — `gh release view "$TAG"` guard before `gh release create`, which otherwise fails with HTTP 422 on an existing release
- https://github.com/tangentyh/pi-collections/pull/30 — `npm view <name>@<version> version`: exit 0 → exists, `E404` → missing, any other error fails the job
- https://github.com/rnw-community/mobile-ci/issues/140 — a cancelled run leaves a published Release with only some assets; create as draft and publish after all assets are present
- Field case 2026-11-03: a CLI package's release job guarded tag → Release → npm with one tag check; a counterexample review found that a re-run after an npm failure ended green with no package. After per-artifact checks, the check block run under `bash -e` returned all "exists" for the released `v0.4.1` and all "missing" for `v9.9.9`; actionlint and CI passed
