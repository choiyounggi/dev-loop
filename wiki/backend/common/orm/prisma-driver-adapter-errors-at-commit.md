---
id: backend-common-orm-prisma-driver-adapter-errors-at-commit
domain: backend
category: orm
applies_to: [prisma, nodejs, typescript, postgresql]
confidence: field-tested
sources:
  - https://www.prisma.io/changelog/2026-04-27
  - https://www.postgresql.org/docs/current/sql-set-constraints.html
  - https://www.postgresql.org/docs/current/sql-createtrigger.html
  - "Installed source, @prisma/adapter-pg 7.10.0 dist/index.mjs (src/pg.ts): PgTransaction.commit() runs no SQL; executeRaw → performIO → onError throws `new DriverAdapterError(convertDriverError(error))`"
  - "Installed source, @prisma/driver-adapter-utils 7.10.0 dist/index.mjs (src/error.ts): `DriverAdapterError` (`name = \"DriverAdapterError\"`, `cause = payload`) and `isDriverAdapterError(error)`"
  - "Field evidence 2026-10-15 (linkly-invitation task t4d, @prisma/client 7.10.0 + @prisma/adapter-pg): a DEFERRABLE INITIALLY DEFERRED constraint trigger's exception escaped an `instanceof Prisma.*Error` wrapper; a BEFORE trigger's exception on the same write was classified"
last_verified: 2026-10-16
related: [backend-common-errors-exception-handling, backend-common-orm-transaction-boundaries, backend-common-orm-prisma-7-config-env-and-generated-client, databases-transactions-multi-row-reorder-on-a-shared-resource]
---

# Prisma Driver-Adapter Errors Raised at COMMIT

## When this applies

A Prisma 7 app runs on a driver adapter (`@prisma/adapter-pg` and siblings) and
has a wrapper that turns Prisma errors into its own error type with
`instanceof Prisma.PrismaClientKnownRequestError` (or other `Prisma.*Error`
classes); the schema has deferred checks that run at COMMIT.

## Do this

**Classify `DriverAdapterError` as a database fault as well, and prove it with
a fixture that fails at COMMIT, not only with one that fails mid-statement.**

1. **Know which errors reach COMMIT.** PostgreSQL checks `DEFERRABLE INITIALLY
   DEFERRED` constraints (UNIQUE, PRIMARY KEY, REFERENCES, EXCLUDE) and fires
   deferred constraint triggers when the transaction commits. A violation then
   comes back from the `COMMIT` statement, not from the write that caused it.

2. **Know what class it arrives as.** The adapter runs every SQL statement,
   including the `COMMIT` Prisma sends, through one path that throws
   `DriverAdapterError` with the mapped error as `cause`. On the query path
   Prisma Client converts that into `PrismaClientKnownRequestError` (P2xxx;
   P2039 for an unmapped driver error since 7.9.0). In the field case on 7.10.0
   the commit-time error reached the app as the raw `DriverAdapterError`, so an
   `instanceof Prisma.*Error` branch skipped it.

3. **Widen the wrapper's check.** Add a name check beside the class checks:

   | Error | Classify as |
   |-------|-------------|
   | `e instanceof Prisma.PrismaClientKnownRequestError` | Database fault, by `e.code` |
   | `e instanceof Error && e.name === "DriverAdapterError"` | Database fault, by `e.cause.kind` (and `e.cause.code` when `kind === "postgres"`) |
   | Anything else | Unexpected error |

   The name check matches what `isDriverAdapterError` from
   `@prisma/driver-adapter-utils` tests (`name` plus an object `cause`). Import
   that helper only when the package is a direct dependency pinned to the
   adapter's version; under pnpm a transitive package does not resolve from
   app code.

4. **Read the cause.** `convertDriverError` maps known SQLSTATEs to a `kind`
   (`23505` → `UniqueConstraintViolation`, `23503` →
   `ForeignKeyConstraintViolation`, `40001`/`40P01` →
   `TransactionWriteConflict`, and more). Any other code becomes
   `kind: "postgres"` with `code`, `severity`, `message` and `detail`. A
   trigger's `RAISE EXCEPTION` without its own SQLSTATE arrives as
   `kind: "postgres"`.

5. **Test both timings.** In the integration suite, create the commit-time
   fixture in the test database and assert the wrapper's classification:

   ```sql
   CREATE CONSTRAINT TRIGGER fail_at_commit
     AFTER UPDATE ON <table>
     DEFERRABLE INITIALLY DEFERRED
     FOR EACH ROW EXECUTE FUNCTION <raise_fn>();
   ```

   Keep a statement-time fixture (a `BEFORE` trigger, or an immediate
   constraint) next to it. The pair proves each branch of step 3. Drop both
   in the test's teardown.

## Edge cases

| Case | Then |
|------|------|
| The write runs outside an explicit `$transaction` | Run the commit-time fixture against each wrapped operation anyway; the classification evidence is the test result, not a reading of which statements Prisma batches |
| The app upgrades Prisma (7.x patch or 8) | Re-run the commit-time fixture; whether Prisma Client converts commit-path errors can change between releases |
| The wrapper forwards the lower layer's fault message and prints its own label otherwise | Assert the full log line for both fixtures, so a misclassified error shows up as the wrong label |
| Another adapter (`adapter-neon`, `adapter-mariadb`, `adapter-better-sqlite3`) | The conversion above is `adapter-pg`'s; read that adapter's error conversion and run the same two fixtures |
| `SET CONSTRAINTS ... IMMEDIATE` inside the transaction | Checks then run at the end of each statement, so the error takes the query path; keep the commit-time fixture for the default timing |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust a fault wrapper because its statement-time error tests pass | Add a commit-time fixture and assert the same classification | COMMIT errors take a different path and arrive as a different class |
| Branch only on `instanceof Prisma.PrismaClientKnownRequestError` | Also match `name === "DriverAdapterError"` and read `cause.kind` | A raw adapter error from COMMIT fails the `instanceof` check |
| Import `isDriverAdapterError` from a transitive dependency | Use the name check, or add `@prisma/driver-adapter-utils` as a direct dependency at the adapter's version | pnpm does not hoist transitive packages into app resolution |

## Sources

- https://www.prisma.io/changelog/2026-04-27 — before the fix a raw driver error with no specific mapping was rethrown and could crash the client; prisma/prisma#29512 surfaces it as a catchable P2039 (`PrismaClientKnownRequestError`); the 7.9.0 release notes carry the same change (read through WebSearch on 2026-10-16)
- https://www.postgresql.org/docs/current/sql-set-constraints.html — "DEFERRED constraints are not checked until transaction commit"; UNIQUE, PRIMARY KEY, REFERENCES and EXCLUDE can be deferrable
- https://www.postgresql.org/docs/current/sql-createtrigger.html — `CONSTRAINT` creates a constraint trigger (AFTER ROW, plain tables) whose firing time `SET CONSTRAINTS` can adjust
- Installed `@prisma/adapter-pg` 7.10.0 `dist/index.mjs` (read 2026-10-16): `PgTransaction.commit()` only calls `cleanup` and `client.release()`; `executeRaw` → `performIO` → `onError` throws `new DriverAdapterError(convertDriverError(error))`; `convertDriverError` maps `23505`, `23503`, `23502`, `40001`/`40P01` and others to named kinds, and the `default` branch returns `kind: "postgres"` with `code`, `severity`, `message`, `detail`, `column`, `hint`
- Installed `@prisma/driver-adapter-utils` 7.10.0 `dist/index.mjs` (read 2026-10-16): `class DriverAdapterError extends Error { name = "DriverAdapterError"; cause; … this.cause = payload }`; `isDriverAdapterError(error)` returns `error.name === "DriverAdapterError" && typeof error.cause === "object"`. In the same pnpm project the package exists only under `node_modules/.pnpm/@prisma+driver-adapter-utils@7.10.0/`; `node_modules/@prisma/driver-adapter-utils` does not exist (app code cannot import it without a direct dependency)
- Field evidence 2026-10-15 (linkly-invitation task t4d, @prisma/client 7.10.0): `CREATE CONSTRAINT TRIGGER ... AFTER UPDATE ... DEFERRABLE INITIALLY DEFERRED` raising an exception made the admin wrapper log `[admin] unexpected error in setTheme`; a BEFORE trigger on the same `setTheme` was logged as `database fault in setTheme (P20xx)`; re-run by the session after the auditor's measurement. Not re-run in this flush
