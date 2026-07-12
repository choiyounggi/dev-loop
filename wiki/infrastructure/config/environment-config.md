---
id: infrastructure-config-environment-config
domain: infrastructure
category: config
applies_to: [general]
confidence: verified
sources:
  - https://12factor.net/config
  - https://12factor.net/build-release-run
  - https://12factor.net/dev-prod-parity
last_verified: 2026-07-10
related: [infrastructure-deploy-rollout-and-rollback, infrastructure-ci-cd-secrets-handling, backend-node-boundaries-runtime-validation, backend-python-boundaries-runtime-validation]
---

# Configuration That Differs Per Environment

## When this applies

Adding configuration that differs per environment (dev/stg/prd); a bug traced
to an environment config difference; config sprawled across hardcoded values,
files, and env vars; reviewing how a service gets its settings.

## Do this

1. Ship ONE artifact to every environment; only configuration differs. A
   release = the built artifact + that environment's config
   (build/release separation). Per-environment builds mean what you tested is
   not what you ship — build-once mechanics:
   [infrastructure-deploy-rollout-and-rollback],
   [infrastructure-containers-image-builds].
2. Config lives outside the artifact — env vars, mounted config files, or a
   config service. Code reads named values; it never inspects which
   environment it is in:

| Case | Do |
|------|----|
| Behavior must differ per environment | Define a named config value, set it per environment; code reads the value through one code path |
| dev/stg/prd values diverging silently | Keep per-env values version-controlled side by side (same file/directory structure per environment) so a plain diff shows drift |
| Config changed in a cloud console or dashboard | Land the change in version control first, then apply it through deploy tooling — a console-only edit is reverted by the next deploy |
| Config value is a secret | [infrastructure-ci-cd-secrets-handling] owns storage and rotation; this page owns its shape — declare it in the schema and validate its presence at startup like any other key |

3. Validate the FULL config schema at process startup and crash on any
   missing or invalid key. A value first read inside a request handler turns
   a missing key into a failure hours later in a request path. Boot-validation
   mechanics: [backend-node-boundaries-runtime-validation],
   [backend-python-boundaries-runtime-validation].
4. Keep one inventory of every config key per service: the startup validation
   schema (settings model) IS the inventory. A key read anywhere in the code
   but absent from the schema is a defect — undocumented keys rot.
5. Required keys get NO default. A default that only suits dev (a localhost
   URL, a dummy endpoint) turns a missing prd value into a prd incident; a
   loud startup crash turns it into a failed deploy.
6. Keep environments as similar as configuration allows. Every intentional
   difference between dev/stg/prd is a place where bugs hide from testing —
   minimize the list and record why each entry exists. Test-environment
   consequences of parity live in wiki/qa/.

## Edge cases

| Case | Then |
|------|------|
| A key is only meaningful in prd (e.g. a payments endpoint) | Declare it required in every environment and give dev/stg a working sandbox value — an optional-in-dev key hides a missing-prd-value crash until the prd deploy |
| A value must change without a redeploy (kill switch, tuning knob) | Use a runtime flag ([infrastructure-deploy-rollout-and-rollback] config/flag row); flag names and allowed values still belong in the schema inventory |
| Config service or mounted config unreachable at boot | Crash and let the orchestrator restart/retry; starting with fallback values means each instance runs config you cannot account for |
| Legacy code full of `if (env === 'prod')` branches | On each touch, replace the branch you are editing with a named config value; record the remaining branches as inventory gaps |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Scatter `if (env === 'prod')` branches through code | A named config value with per-env values; code reads the value | Env branches are config encoded as logic — untestable outside that environment and invisible to any inventory |
| Give a required key a dev-friendly default (localhost URL) | No default; validate at startup and fail loud | The default that suits dev becomes the silent prd value when the real one is missing |
| Build a separate artifact per environment | Build once; inject config at release/deploy time | An artifact built for prd is not the artifact you tested |
| Hot-fix a value directly in the cloud console | Change it in version control, then apply through deploy tooling | The console edit is silently lost on the next deploy, and the incident repeats |

## Sources

- https://12factor.net/config — strict separation of config from code; config is everything that varies between deploys
- https://12factor.net/build-release-run — release = build + config; releases are immutable
- https://12factor.net/dev-prod-parity — keeping environments similar; gaps make code that passed tests fail in production
