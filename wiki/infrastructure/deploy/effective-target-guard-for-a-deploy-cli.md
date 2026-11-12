---
id: infrastructure-deploy-effective-target-guard-for-a-deploy-cli
domain: infrastructure
category: deploy
applies_to: [convex, dotenv]
confidence: verified
sources:
  - https://docs.convex.dev/cli/reference/deploy
  - https://docs.convex.dev/production/project-configuration
  - convex 1.46.0 npm package, dist/esm/cli/lib/deploymentSelection.js lines 84-85
last_verified: 2026-11-04
related: [infrastructure-config-environment-config, backend-node-runtime-env-files-with-process-loadenvfile]
---

# A Guard That Confirms Which Deployment a CLI Will Hit

## When this applies

A script must guarantee that a deployment CLI touches only a local or test
target before it pushes, seeds or wipes data. The worked case is the Convex CLI,
which reads `CONVEX_DEPLOYMENT` through dotenv.

## Do this

1. Compute the effective target in the CLI's own order, first value wins:

| Order | Source |
|-------|--------|
| 1 | The process environment, including anything exported in the shell |
| 2 | `.env.local` |
| 3 | `.env` |

2. Refuse to run when any of these is set after that resolution:
   `CONVEX_DEPLOY_KEY`, `CONVEX_DEPLOYMENT_TOKEN`, or a `CONVEX_SELF_HOSTED_URL`
   that points to a remote host.
3. Refuse the flags that override all of the above when the script forwards
   arguments to the CLI: `--prod`, `--deployment`, `--deployment-name`,
   `--preview-name`, `--url`, `--admin-key`.
4. Confirm the target with a read-only command against it, such as listing
   environment variables, and compare the deployment name.
5. Run `npx convex dev --once` or the equivalent push for a development target.

## Edge cases

| Case | Then |
|------|------|
| The script passes `--env-file` | That file replaces `.env.local` and `.env` for choosing the deployment, so the guard reads the same file |
| `CONVEX_DEPLOYMENT` is a development deployment and the command is `convex deploy` | The target is that project's production deployment, as the deploy help states |
| Both `CONVEX_DEPLOY_KEY` and `CONVEX_DEPLOYMENT_TOKEN` are set | The deploy key is read first; the guard refuses either one, so the order does not change its answer |
| Another CLI uses dotenv | The order holds when it calls `dotenv.config()` without `override: true`; read its source to confirm |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read only `.env.local` in the guard | Resolve the process environment first | dotenv leaves an exported variable in place, so the file's value is not the value the CLI uses |
| Use `convex deploy --dry-run` as proof of the target | Run a read-only command against the resolved deployment | `--dry-run` prints the generated configuration; it does not exercise the target |
| Use `convex deploy` to test a local target | Use the development push | `convex deploy` defaults to the production deployment |

## Sources

- https://docs.convex.dev/cli/reference/deploy — default production target, `CONVEX_DEPLOY_KEY`, and `--env-file`
- https://docs.convex.dev/production/project-configuration — `CONVEX_DEPLOYMENT` written to `.env.local` by `npx convex dev`
- convex 1.46.0, dist/esm/cli/lib/deploymentSelection.js lines 84-85 — `dotenv.config({ path: ".env.local" })`, then `dotenv.config()`
- convex 1.46.0, dist/esm/cli/lib/command.js — the target-selecting flags; dist/esm/cli/lib/deploymentSelection.js — `--env-file` selects with `dotenv.parse` of that file alone
- `npx convex deploy --help` (1.46.0) — target rules and the `--dry-run` description
- Local reproduction 2026-11-04 with dotenv 17.3.1: the same two calls gave the `.env.local` value when unset, and kept `dev:exported` when exported
