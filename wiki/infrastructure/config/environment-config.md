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
  - https://github.com/motdotla/dotenv
last_verified: 2026-10-24
related: [databases-data-survey-surveying-live-data-for-a-rule, infrastructure-deploy-rollout-and-rollback, infrastructure-ci-cd-secrets-handling, backend-node-boundaries-runtime-validation, backend-python-boundaries-runtime-validation, backend-common-integrations-externally-owned-defaults, infrastructure-config-path-valued-config, platforms-shells-env-var-off-switches, backend-common-llm-project-local-layer-over-shared-guidance, backend-common-orm-prisma-7-config-env-and-generated-client, backend-node-runtime-env-files-with-process-loadenvfile]
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
| A required value names a resource the repo does not own (model alias, endpoint, bucket, queue) | Startup validation must resolve the name against the owner's catalog, not just check that the string is present — [backend-common-integrations-externally-owned-defaults] owns the review-time and startup checks |
| Config service or mounted config unreachable at boot | Crash and let the orchestrator restart/retry; starting with fallback values means each instance runs config you cannot account for |
| Legacy code full of `if (env === 'prod')` branches | On each touch, replace the branch you are editing with a named config value; record the remaining branches as inventory gaps |
| A CLI tool loads its own config in a step where the key is not needed (Prisma 7 `prisma generate` in `postinstall` or CI reading `DATABASE_URL`) | Use a tool version that tolerates the missing key (Prisma 7.2.0+: `url: process.env.DATABASE_URL`, no fallback); before that, an empty placeholder in the tool config only (`?? ''`). Rule 5 stays for the application: no default, and startup validation rejects an unset or empty value ([backend-common-orm-prisma-7-config-env-and-generated-client]) |
| The value is a filesystem path | Presence is not enough — a relative path passes every presence check and then resolves against a working directory the launcher owns ([infrastructure-config-path-valued-config]) |
| You are about to decide which host a writing or destructive command (`db:push`, a migration, a seed) will hit by reading `DATABASE_URL` from a `.env` file | Find the file the tool loads first: the dotenv `config({ path })` call, whose relative path resolves against the process's working directory, not the source file. In that file, list every active assignment — `grep -nE '^[[:space:]]*(export[[:space:]]+)?DATABASE_URL[[:space:]]*(=|:[[:space:]])'` (dotenv also accepts `KEY: value`) — and read all of them, not the first textual match, which can be a commented `#DATABASE_URL=` line. With several active lines dotenv keeps the last; a variable already set in the shell wins over the file (`override` defaults to `false`), so check `env` too. Then confirm against the live connection (host, port, database name) before the write ([databases-data-survey-surveying-live-data-for-a-rule]) |

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
- https://github.com/motdotla/dotenv — "lines beginning with `#` are treated as comments"; default path `path.resolve(process.cwd(), '.env')`; `override` default `false`: "we will never modify any environment variables that have already been set"
- https://raw.githubusercontent.com/motdotla/dotenv/master/lib/main.js — the parser assigns `obj[key] = value` per matched line, so a later line in the same file replaces an earlier one (read at v18.0.9, 2026-10-24)
- Field observation (monorepo with an app `.env` and a root `.env`): a first-match `sed … | head -1` over the app file returned a commented line's `localhost:15432`; the active line further down pointed at `localhost:15433`, an SSH tunnel to a shared dev database; the tool's own dotenv call loaded only the root `.env`
