---
id: security-secrets-secrets-in-code
domain: security
category: secrets
applies_to: [general]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html
  - https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
  - https://nextjs.org/docs/pages/building-your-application/configuring/environment-variables
  - https://vite.dev/guide/env-and-mode
last_verified: 2026-07-12
related: [infrastructure-ci-cd-secrets-handling]
---

# Keeping Secrets Out of Code and Responding to a Leak

## When this applies

Code needs an API key, password, or private key; a secret was just committed,
pasted, or logged; or you are setting up secret hygiene for a repository.

## Do this

1. **Load secrets at runtime from environment variables or a secret manager.**
   Source files, config files committed to the repo, and client-delivered code
   are all outside the trust boundary — anything shipped to a browser or app
   bundle is public. Env prefixes like `NEXT_PUBLIC_` / `VITE_` mean
   **bundled-public by design**: a secret behind that prefix is already published
   to every visitor.
2. Local development: an untracked env file (`.env` in `.gitignore`) plus a
   committed `.env.example` with placeholder values documenting the required keys.
3. CI/build-time injection and pipeline masking →
   [infrastructure-ci-cd-secrets-handling].
4. **Leak response — rotate first, clean up second.** The credential is
   compromised the moment it leaves the trusted store:

| Leaked where | Do |
|--------------|----|
| Committed to git — even if removed in the next commit | Rotate immediately, then scrub history (`git filter-repo`, host support). History retains every version; a force-push does not un-leak existing clones, forks, mirrors, or scraper caches |
| Printed to logs / CI output | Rotate, fix the log site (redact the field), and purge stored copies where the platform allows |
| Pasted into chat / LLM / issue tracker | Rotate; delete or edit the paste, treating it as already read |

5. **Prevention**: a pre-commit secret scanner (gitleaks-style) locally and in CI;
   `.gitignore` entries for local env files before the first commit; key-pattern
   greps (`AKIA`, `-----BEGIN`, `api_key=`) in code review.

## Edge cases

| Case | Then |
|------|------|
| A "secret" the frontend needs (maps key, analytics id) | That is a public client identifier, not a secret: restrict it provider-side (referrer/quota/scope). Values that must stay confidential go behind your backend, which proxies the call |
| Secret found in a committed fixture, lockfile, or test | Same as committed to git: rotate and scrub; replace fixtures with obviously fake values (`sk_test_FAKE...`) |
| Rotation needs coordination (shared prod credential, third party) | Treat the interval as a live incident: cut the credential's permissions/IP scope now, and schedule the rotation with an owner and a date |
| Secret must reach a config file at runtime (library only reads files) | Render the file at deploy/start from the secret store into a non-repo path; the template in the repo holds placeholders |
| A third-party API takes its key in a URL query param and your HTTP client logs requests | The client (httpx/requests/axios) logs the full URL — key included — at its INFO level, so enabling root/DEBUG logging leaks it into log files. Keep the client's logger above INFO (or redact the URL), and confine any redaction/proxy to your own log calls — app-level redaction never sees the client library's own log lines |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| "We'll rotate it later — the repo is private" | Rotate now | Private repos leak via clones, forks, departed laptops, CI logs, and future open-sourcing |
| Scrub git history as the fix | Rotate first, scrub second | Scrubbing never reaches clones and mirrors that already pulled; the value itself must die |
| Commit an encrypted secret with its decryption key reachable from the repo | Secret manager or injected env | A key stored beside the ciphertext is the secret in code again |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html — centralized secret storage, rotation, least exposure
- https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository — "rotate first"; history scrubbing does not un-leak distributed copies
- https://nextjs.org/docs/pages/building-your-application/configuring/environment-variables — `NEXT_PUBLIC_` inlines values into the browser bundle
- https://vite.dev/guide/env-and-mode — `VITE_`-prefixed vars are exposed to client source
