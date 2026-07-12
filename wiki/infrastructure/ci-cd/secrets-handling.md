---
id: infrastructure-ci-cd-secrets-handling
domain: infrastructure
category: ci-cd
applies_to: [general]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html
  - https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect
  - https://12factor.net/config
  - https://docs.docker.com/build/building/secrets/
last_verified: 2026-07-10
related: [infrastructure-containers-image-builds, infrastructure-ci-cd-pipeline-structure]
---

# Credentials Flowing Through Build and Deploy Pipelines

## When this applies

A build or deploy step needs credentials (registry push, cloud deploy, private
package fetch, signing key), or you are reviewing how secrets flow through CI.

## Do this

1. Store every secret in the CI provider's secret store or a dedicated vault;
   pipelines reference it by name. No secret value in the repo — including git
   history: a secret that was ever pushed is leaked, and deleting the file does
   not unleak it.
2. Keep secret values out of build outputs and logs:

| Exposure path | Do |
|---------------|----|
| Docker image build | BuildKit secret mounts (`RUN --mount=type=secret`); build args and ENV persist in image history ([infrastructure-containers-image-builds]) |
| Job logs | Enable the provider's log masking; keep `set -x` / debug tracing off in any script region that touches a secret value |
| Artifacts and caches | Fetch a secret only in the step that uses it; exclude env dumps and secret-bearing config files from uploaded artifacts and caches |
| Command lines | Pass secrets via env var or file, not argv — arguments appear in process listings and CI logs |

3. Scope minimally: separate secrets per environment (a stg job cannot read prd
   secrets), least-privilege tokens (push to one registry, deploy one service).
4. When the cloud provider supports OIDC federation from your CI, use it instead
   of stored long-lived keys: the job requests a short-lived token per run, so
   there is no static key to leak or rotate.
5. Rotate by event:

| Event | Do |
|-------|----|
| Secret printed to a log, pasted to chat, or committed — even only *possibly* | Rotate now, treat as compromised; scrub history afterwards if it was committed |
| Person with access to shared secrets changes team or leaves | Rotate every shared secret they could read |
| Long-lived static key in use (no OIDC option) | Rotate on a fixed schedule; record the next rotation date |

6. PRs from forks or untrusted contributors: their builds must run without
   access to secrets. Run secret-needing jobs only on trusted events (post-merge,
   protected branches), never on unreviewed fork PR code.

## Edge cases

| Case | Then |
|------|------|
| Secret already pushed to a shared branch | Rotate first — history rewriting does not unleak; then scrub history (git filter-repo or provider support) so scanners stop flagging it |
| Local development needs credentials too | Local `.env` in `.gitignore`, values distributed through the team's secret manager, using dev-scoped credentials distinct from CI's and prd's |
| Third-party CI plugin/action receives a secret | Pin the action/plugin to a full version or commit hash before giving it a secret; an unpinned dependency can start exfiltrating on its next release |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Commit a `.env` "temporarily" | Secret store + `.gitignore`; if already pushed, rotate + history scrub | Anything pushed is permanently leaked via history and clones |
| Bake a token into a Dockerfile `ARG`/`ENV` | BuildKit `--mount=type=secret` | Args and env values persist in image history |
| Echo a secret to debug a failing auth step | Log its length or a hash to confirm presence | Logs are retained and readable far more widely than the secret store |
| Reuse one god-token across environments | Per-environment, least-privilege tokens | One leak then compromises every environment at once |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html — centralized stores, rotation, least privilege, CI/CD pipeline handling
- https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect — OIDC short-lived tokens replacing stored cloud credentials
- https://12factor.net/config — credentials live in the environment, never in code
- https://docs.docker.com/build/building/secrets/ — build args/env unsuitable for secrets; secret mounts
