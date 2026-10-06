---
id: databases-schema-design-migration-sql-without-a-database
domain: databases
category: schema-design
applies_to: [prisma, postgresql, mysql, sqlite]
confidence: verified
sources:
  - https://github.com/prisma/prisma/blob/6.19.0/packages/migrate/src/commands/MigrateDiff.ts
  - https://www.prisma.io/docs/orm/reference/prisma-cli-reference#migrate-diff
last_verified: 2026-10-06
related: [databases-schema-design-online-schema-changes, platforms-toolchains-flag-availability-at-the-execution-site]
---

# Producing a Prisma Migration File With No Database Reachable

## When this applies

You changed `schema.prisma` and must add the matching `migrations/<name>/migration.sql`
in an environment with no reachable database or shadow database — a CI job, an
agent worktree, a sandbox — or where connecting to the developer's database is out
of scope. `prisma migrate dev --create-only` is the usual path and needs both.

## Do this

Generate the SQL as the diff between the schema **before** and **after** your
change, both read from files:

1. Write the previous schema to a project-local scratch file:
   `git show <base-ref>:prisma/schema.prisma > .claude/tmp/prev.prisma`.
2. Run `migrate diff` with the flags of the Prisma major version the project pins
   (read it from the lockfile, not from `npx prisma --version` in another checkout):

| Prisma version | Command |
|----------------|---------|
| 6.x and earlier | `prisma migrate diff --from-schema-datamodel .claude/tmp/prev.prisma --to-schema-datamodel prisma/schema.prisma --script` |
| 7.x | `prisma migrate diff --from-schema .claude/tmp/prev.prisma --to-schema prisma/schema.prisma --script` |

3. Save stdout verbatim as `migration.sql` in a new directory that follows the
   naming of the existing directories under `prisma/migrations/`. Do not hand-edit
   the generated statements; when the SQL is wrong, fix `schema.prisma` and
   regenerate.
4. Delete the scratch file.

Two schema files involve no database: in Prisma 6 the shadow database is "only
required if using --from-migrations or --to-migrations", and the Prisma 7 reference
names the `--from-config-datasource`/`--to-config-datasource` sources as the ones
that read a connection string.

## Edge cases

| Case | Then |
|------|------|
| The command errors because an `env(...)` value in the schema is unset | Set a syntactically valid placeholder for that one command (`DATABASE_URL='postgresql://user:pass@127.0.0.1:1/none'`, an unreachable port). In 6.19.0 the `--from-schema-datamodel` branch reads the file with `getSchemaWithPath` and does not call `loadEnvFile` (only `--from-schema-datasource` does), so no connection is attempted |
| The migration needs a statement Prisma does not generate (a data backfill, `CREATE INDEX CONCURRENTLY`) | Put it in its own migration file after the generated one; for `CONCURRENTLY` follow [databases-schema-design-online-schema-changes] |
| You want to check that the committed migrations match the schema | Use `--from-migrations prisma/migrations --to-schema(-datamodel) prisma/schema.prisma --exit-code` (exit 0 = empty diff, 2 = not empty) where a shadow database is available — checked against the 6.x help text only; that source replays migrations into the shadow database |
| A Prisma 6 command from an older plan carries `--from-schema-datamodel` into a Prisma 7 project | Rename to `--from-schema`/`--to-schema`; Prisma 7 also removed `--from-url`, `--to-url`, `--shadow-database-url` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Hand-write the migration SQL from the schema diff | Generate it with `migrate diff ... --script` from the two schema files | The generated script is by construction the SQL Prisma derives from the two schemas; hand-written SQL must reproduce every name and type by hand, and a mismatch shows up only when a later migration run compares the database with the schema |
| Run `migrate dev --create-only` against the developer's database to get the file | Use the file-to-file diff above | `migrate dev` needs a shadow database and connects to the configured database, which is outside an isolated task's scope |

## Sources

- https://github.com/prisma/prisma/blob/6.19.0/packages/migrate/src/commands/MigrateDiff.ts — help text at tag 6.19.0: `--from-schema-datamodel  Path to a Prisma schema file, uses the datamodel for the diff`; "Shadow database (only required if using --from-migrations or --to-migrations)"; `--script  Render a SQL script to stdout instead of the default human readable summary (not supported on MongoDB)`; the `--from-schema-datamodel` branch calls `getSchemaWithPath(...)` while `loadEnvFile(...)` is called only in the `--from-schema-datasource` branch; `--exit-code  ... (Empty: 0, Error: 1, Not empty: 2)`
- https://www.prisma.io/docs/orm/reference/prisma-cli-reference#migrate-diff — Prisma 7 sources `--from-empty`, `--from-schema`, `--from-migrations`, `--from-config-datasource`; "The `--from-url`, `--to-url`, `--from-schema-datasource`, `--to-schema-datasource`, and `--shadow-database-url` options have been removed. Use `--from-config-datasource` and `--to-config-datasource` instead"
- Field evidence 2026-10-06 (a NestJS + Prisma 6.19 API, plan t2): the migration was produced as the stdout of `migrate diff --from-schema-datamodel <prev> --to-schema-datamodel prisma/schema.prisma --script` with a placeholder `DATABASE_URL` pointing at an unreachable port set defensively, avoiding the shadow database and the developer database
