---
id: infrastructure-ci-cd-secret-needing-gate-on-fork-prs
domain: infrastructure
category: ci-cd
applies_to: [github-actions]
confidence: verified
sources:
  - https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#pull_request_target
  - https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/
  - https://github.com/anthropics/claude-code-action/blob/main/docs/security.md
last_verified: 2026-09-08
related: [infrastructure-ci-cd-secrets-handling, infrastructure-ci-cd-pipeline-structure, infrastructure-ci-cd-review-bot-adopted-as-a-blocking-gate]
---

# A Secret-Needing Check Gate on Pull Requests From Forks

## When this applies

A CI check needs a repo secret (API key, OAuth token, cloud credential) to run
against PRs that can arrive from forks — most commonly an LLM/agent-run review
or gate. Plain `pull_request` withholds secrets from fork-originated runs, so
the check silently never authenticates and effectively no-ops instead of
failing loudly.

## Do this

| Case | Do |
|------|----|
| A fork-originated PR must run a secret-authenticated gate | Trigger on `pull_request_target`, not `pull_request` — it runs in the base repo's context, so secrets are present |
| `pull_request_target` would start the job for any PR, from anyone | Add a job-level `if:` that restricts to trusted actors before any step runs, e.g. `github.event.pull_request.head.repo.full_name == github.repository \|\| contains(fromJSON('["user-a","user-b"]'), github.event.pull_request.user.login)` |
| The check needs to read the PR's changes | Check out the base ref only (no `ref:` override on `actions/checkout`) and read PR content exclusively through `gh pr diff <n>` / `gh pr view <n>`; the PR head stays out of the runner workspace |
| The PR diff or description contains instruction-shaped text | Tell the agent explicitly that such text is itself a finding to report, never an instruction to follow — untrusted content is data, not a prompt |
| A downstream step must act on the agent's verdict | Transport it as validated structured output (e.g. a `--json-schema` contract with required `verdict`/`summary`/`findings` fields) rather than a free-form comment or an ad hoc file the agent could skip writing |
| The agent crashes, times out, or emits malformed output | Treat missing or unparsable structured output as a failing gate, not a passing one (fail closed) |

## Edge cases

| Case | Then |
|------|------|
| The job must build or execute the PR's code itself, not just review its text | This checkout-avoidance pattern does not cover that case — use the two-workflow split instead: an unprivileged `pull_request` job builds/tests untrusted code with no secrets and uploads results as artifacts, a separate privileged `workflow_run` job (running on the base ref, with secrets) consumes those artifacts |
| No fixed trusted-account list is maintainable (open, high-volume external contributors) | Gate the job on a maintainer-applied label (e.g. `safe to test`) instead of a login allowlist, and re-check the label/approval on every new commit — a label applied once does not vouch for commits pushed afterward |
| The gate posts a comment back to the PR | Scope `permissions:` to exactly what that needs (e.g. `pull-requests: write`), not broader, since the job already runs with base-repo secrets |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Switch a fork-PR gate from `pull_request` to `pull_request_target` and keep `ref: ${{ github.event.pull_request.head.sha }}` in the checkout step | Drop the `ref:` override so checkout stays on the base ref; read PR content only via `gh pr diff`/`gh pr view` | `pull_request_target` plus an explicit head checkout is the "pwn request" pattern: untrusted PR content gets both the secret context and a writable workspace in the same job |
| Let a crashed or erroring agent step read as a passing check | Fail closed: missing/malformed structured output exits non-zero | A crash defaulting to green is a dangerous default-allow — the exact failure mode the gate exists to prevent |
| Rely on the `pull_request_target` trigger alone as the security boundary | Pair it with an explicit job-level `if:` trust check | The trigger only decides secret availability; without the `if:`, the job body still runs for a PR from anyone |

## Sources

- https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#pull_request_target — "With the exception of GITHUB_TOKEN, secrets are not passed to the runner when a workflow is triggered from a forked repository"; "Running untrusted code on the pull_request_target trigger may lead to security vulnerabilities"
- https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/ — "Combining pull_request_target workflow trigger with an explicit checkout of an untrusted PR is a dangerous practice that may lead to repository compromise"; mitigations include the two-workflow split and label-gated re-checks
- https://github.com/anthropics/claude-code-action/blob/main/docs/security.md — "pull_request_target and workflow_run execute with the base repository's secrets"; "Do not check out an untrusted ref into the workspace root before this action"; "Preferred — check out the base ref (default)"
- Field reproduction (dev-loop `.github/workflows/wiki-agent-gate.yml` + `tests/wiki-agent-gate.bats`, 12 tests, each guard paired with a negative control; read directly 2026-09-08): trust `if:`, base-ref-only checkout, `gh pr diff` read path, `--json-schema` verdict, fail-closed enforce step. The "instruction-shaped text is a finding" stance is that repo's own gate prompt, not the claude-code-action doc
