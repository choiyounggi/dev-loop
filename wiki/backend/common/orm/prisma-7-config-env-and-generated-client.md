---
id: backend-common-orm-prisma-7-config-env-and-generated-client
domain: backend
category: orm
applies_to: [prisma, nodejs, typescript]
confidence: verified
sources:
  - https://github.com/prisma/orm/releases/tag/7.0.0
  - https://www.prisma.io/docs/guides/upgrade-prisma-orm/v7
  - https://www.prisma.io/docs/orm/v7/reference/prisma-config-reference
  - https://www.prisma.io/docs/orm/v7/prisma-schema/overview/generators
  - https://www.prisma.io/docs/orm/v7/reference/prisma-cli-reference
  - https://www.prisma.io/docs/orm/v7/prisma-client/setup-and-configuration/generating-prisma-client
  - https://www.prisma.io/docs/orm/v7/more/dev-environment/environment-variables
  - https://github.com/prisma/orm/blob/7.10.0/packages/config/src/loadConfigFromFile.ts
  - https://github.com/prisma/orm/blob/7.10.0/packages/config/src/env.ts
  - https://github.com/pnpm/pnpm/releases/tag/v10.0.0
  - https://www.prisma.io/blog/announcing-prisma-orm-7-2-0
  - https://github.com/prisma/orm/blob/7.10.0/packages/internals/src/utils/validatePrismaConfigWithDatasource.ts
  - https://github.com/prisma/orm/blob/7.10.0/packages/config/src/PrismaConfig.ts
  - https://www.prisma.io/docs/guides/postgres/flyio
  - https://docs.npmjs.com/cli/v11/using-npm/config
  - https://github.com/pnpm/pnpm/releases/tag/v11.0.0
  - https://github.com/prisma/orm/blob/6.19.2/packages/internals/src/utils/loadEnvFile.ts
  - "Local reproduction 2026-10-08 (pnpm 10.30.2): `pnpm install --frozen-lockfile` ran the root package's own `postinstall`; `--lockfile-only` did not"
last_verified: 2026-10-08
related: [backend-node-runtime-env-files-with-process-loadenvfile, infrastructure-config-environment-config, infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge, security-secrets-secrets-in-code]
---

# Prisma 7 Config, Environment Loading and the Generated Client

## When this applies

Setting up Prisma ORM 7 in a Node/TypeScript project, or upgrading from 6: the CLI
does not see `DATABASE_URL` from a `.env` file; `prisma generate` fails in
`postinstall`, CI or a Docker build stage with `PrismaConfigEnvError`; the generated
client is missing after a fresh clone; deciding whether to commit the generated client.

## Do this

| Case | Do |
|------|----|
| The CLI must see variables from a `.env`-style file | Load them at the top of `prisma.config.ts`, before `defineConfig`: `import 'dotenv/config'`, or `if (fs.existsSync(p)) process.loadEnvFile(p)` with `p` built from the config file's own directory ([backend-node-runtime-env-files-with-process-loadenvfile]). A relative path resolves from the working directory, and `pnpm prisma` also runs from subdirectories, so a relative `.env` is then skipped without an error; the unguarded call throws `ENOENT` where CI checkouts and Docker build contexts have no `.env`. Prisma 7 does not read `.env` files itself |
| `prisma generate` runs where `DATABASE_URL` is unset (postinstall, CI, a Docker build stage) | On 7.2.0 and later, write `url: process.env.DATABASE_URL` with no fallback (`url` is optional in the config type): `prisma generate` runs without it, and a command that needs the URL stops with "The datasource.url property is required in your Prisma config file when using <command>". Before 7.2.0, use `process.env.DATABASE_URL ?? ''`, and set the URL before `migrate` or `db` commands: the empty string also passes that check. Either way the application's own config keeps `DATABASE_URL` without a default ([infrastructure-config-environment-config], rule 5) |
| Every CLI command must stop when the URL is missing | Use `env('DATABASE_URL')`; it throws `PrismaConfigEnvError` for an unset or empty variable, and every CLI command loads the config |
| The generator block | `provider = "prisma-client"` with an explicit `output`, and import the client from that path; the `prisma-client` generator no longer generates into `node_modules`, and `prisma-client-js` is deprecated |
| The generated directory | Git-ignore it (`prisma init` writes `/generated/prisma` into `.gitignore`) and rebuild it with `prisma generate` |
| A fresh clone or a `--frozen-lockfile` install must end with a usable client | Add `"postinstall": "prisma generate"` to the root `package.json`; 7.0.0 removed the implicit generate on install and after `prisma migrate`. pnpm 10 (measured on 10.30.2) skips dependencies' lifecycle scripts by default and still runs the root package's own `postinstall`; pnpm 11 makes `strictDepBuilds` true by default, so repeat that check before relying on it there |
| Schema path, migrations path, seed command | Set `schema`, `migrations.path` and `migrations.seed` in `prisma.config.ts`; 7.0.0 removed the `prisma` block in `package.json` |
| Config file location | Put `prisma.config.ts` at the project root, next to `package.json` (`prisma.config.*` and `.config/prisma.*` are both detected). A local CLI run through `pnpm prisma` finds it from a subdirectory too; `npx prisma` and `bunx prisma` find it only from the project root, so pass `--config <path>` when they run elsewhere |

## Edge cases

| Case | Then |
|------|------|
| A Dockerfile installs from the manifest and lockfile before copying the source ([infrastructure-containers-image-builds]) | Copy `prisma/` and `prisma.config.ts` before the install step, or run `prisma generate` after `COPY . .`: otherwise `postinstall` runs before the schema exists |
| Install runs with scripts disabled (`npm install --ignore-scripts`, a supply-chain policy) | Run `prisma generate` as an explicit build step; the root `postinstall` is skipped as well |
| Prisma 6.x | Without a `prisma.config.ts`, 6.x loads `.env` itself and generates into `node_modules` by default; with one, 6.19 also skips `.env` ("Prisma config detected, skipping environment variable loading.") |
| Prisma 8 (npm `latest` is 8.0.0-rc.21 on 2026-10-08) | These rows were verified on 7.0–7.10 (`prev` tag 7.10.0); pin `prisma@7` and `@prisma/client@7`, or re-verify each row on 8 |
| A v7 docs page says the CLI loads `.env` automatically (the "Environment variables" guide, the `prisma init` template comment) | Follow the 7.0.0 release notes, the config reference and the 7.x source (`dotenv: false`); those two pages still describe the pre-7 behaviour |
| `prisma db *`, `prisma migrate *` or `prisma generate --sql` | These commands use the URL: set `DATABASE_URL` before running them |
| `prisma migrate` used to run `generate` and `seed` for you | Run `prisma generate` and the seed command explicitly after migrating |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Commit the generated client | Git-ignore the `output` directory and generate on install | The client must be regenerated "whenever you add models, change fields, or update generator settings"; a committed copy goes stale with each schema edit |
| Rely on the CLI to pick up `.env` during `migrate` or `generate` | Load the env file at the top of `prisma.config.ts` | 7.0.0 stopped loading environment variables when the CLI is invoked |

## Sources

- https://github.com/prisma/orm/releases/tag/7.0.0 — "we're no longer automatically loading environment variables when invoking the Prisma CLI"; "post-install hook would run `prisma generate`", "`prisma migrate` would run `prisma generate` and `prisma seed`" — "This behaviour has been removed in favor of explicitly requiring commands to be run by users."; the `prisma` block in `package.json`: "With the move to `prisma.config.ts`, this no longer makes sense and has been removed."
- https://www.prisma.io/docs/guides/upgrade-prisma-orm/v7 — "In Prisma ORM 7.0.0, environment variables are not loaded by default."; "The output field is now required in the generator block."; "Prisma Client will no longer be generated in node_modules by default."; `prisma.config.ts` "should be placed at the root of your project (where your package.json is located)"
- https://www.prisma.io/docs/orm/v7/reference/prisma-config-reference — "Environment variables from .env files need to be loaded explicitly."; "The env() helper function from prisma/config throws an error if the specified environment variable is not defined."; "Every Prisma CLI command loads the prisma.config.ts file"; "Commands like prisma generate don't need a database URL, but will still fail if env() throws an error when loading the config file"; `process.env.DATABASE_URL ?? ''` "to provide a fallback value"; "Use the env() helper when you want to enforce that an environment variable exists."; "Prisma Config files can be named as prisma.config.* or .config/prisma.* with the extensions js, ts, mjs, cjs, mts, or cts."; "When Prisma is installed locally and run via pnpm prisma, the config file is detected automatically whether you run the command from the project root or a subdirectory."; "When running via npx prisma or bunx prisma, the CLI only detects the config file if the command is run from the project root"; `prisma validate --config ./path/to/myconfig.ts`
- https://www.prisma.io/docs/orm/v7/prisma-schema/overview/generators — "The output option is required and tells Prisma ORM where to put the generated Prisma Client code."; "The prisma-client-js generator is deprecated."
- https://www.prisma.io/docs/orm/v7/reference/prisma-cli-reference — `prisma init` writes a `.gitignore` containing `/generated/prisma`; the same page's template comment ("Environment variables declared in this file are automatically made available to Prisma.") is the stale one
- https://www.prisma.io/docs/orm/v7/prisma-client/setup-and-configuration/generating-prisma-client — run `prisma generate` "whenever you add models, change fields, or update generator settings"; "In many projects it also makes sense to run prisma generate in postinstall or before your production build so deployments always use a current client."
- https://www.prisma.io/docs/orm/v7/more/dev-environment/environment-variables — the stale v7 page: "Any environment variables defined in that .env file will automatically be loaded when running a Prisma CLI command."
- https://github.com/prisma/orm/blob/7.10.0/packages/config/src/loadConfigFromFile.ts — lines 229-230 `// do not load .env files`, `dotenv: false,`
- https://github.com/prisma/orm/blob/7.10.0/packages/config/src/env.ts — `const value = process.env[name]`, `if (!value) { throw new PrismaConfigEnvError(name) }` (an empty string throws too)
- https://github.com/pnpm/pnpm/releases/tag/v10.0.0 — "Lifecycle scripts of dependencies are not executed during installation by default!"
- https://www.prisma.io/blog/announcing-prisma-orm-7-2-0 — `prisma generate` "can now be run even if you don't set an environment variable for your database URL"
- https://github.com/prisma/orm/blob/7.10.0/packages/internals/src/utils/validatePrismaConfigWithDatasource.ts — line 23 accepts `typeof prismaConfig.datasource.url === 'string'` (so `''` passes); line 37 otherwise reports "The datasource.url property is required in your Prisma config file when using <command>."
- https://github.com/prisma/orm/blob/7.10.0/packages/config/src/PrismaConfig.ts — `url?: string`; the datasource is "Optional for most cases, but required for migration / introspection commands."
- https://www.prisma.io/docs/guides/postgres/flyio — "npm install (which runs postinstall) runs before the schema is copied"; the fix copies the schema before the install
- https://docs.npmjs.com/cli/v11/using-npm/config — `ignore-scripts`: "If true, npm does not run scripts specified in package.json files."
- https://github.com/pnpm/pnpm/releases/tag/v11.0.0 — "`strictDepBuilds` is `true` by default."
- https://github.com/prisma/orm/blob/6.19.2/packages/internals/src/utils/loadEnvFile.ts — `if (config.loadedFromFile)` writes "Prisma config detected, skipping environment variable loading." and returns
- https://registry.npmjs.org/-/package/prisma/dist-tags (2026-10-08) — `"latest":"8.0.0-rc.21"`, `"prev":"7.10.0"`
- Local reproduction 2026-10-08 (pnpm 10.30.2, a package whose `postinstall` writes a marker file): `pnpm install --lockfile-only` left no marker; `pnpm install --frozen-lockfile` wrote it
