---
id: databases-schema-design-verifying-additive-migrations
domain: databases
category: schema-design
applies_to: [postgresql, sqlalchemy]
confidence: verified
sources:
  - https://docs.sqlalchemy.org/en/20/core/metadata.html
  - https://docs.sqlalchemy.org/en/20/core/defaults.html
  - https://www.postgresql.org/docs/current/ddl-alter.html
last_verified: 2026-08-05
related: [databases-schema-design-online-schema-changes, databases-schema-design-nullability-and-defaults, testing-data-test-data-and-isolation, testing-quality-tests-that-cannot-fail]
---

# Proving a Hand-Rolled Additive Migration Actually Runs

## When this applies

The project has no migration tool (no Alembic/Flyway). Schema comes from an ORM
`create_all()`-style call plus hand-written `ALTER TABLE ... ADD COLUMN IF NOT
EXISTS` statements in the same init function, and you are adding a column and
writing the test that proves the change reaches an already-deployed database.

## Do this

1. **Know which statement actually adds the column.** `create_all()` "will issue
   queries that first check for the existence of each individual table, and if not
   found will issue the CREATE statements" — an existing table is skipped whole, so
   a column newly declared on the model is never added by it. Only the explicit
   `ALTER` adds it. Adding `server_default=` to the model changes only the CREATE
   TABLE DDL; against an already-created table it emits nothing.

2. **Choose the test's starting DB state deliberately** — it decides which code path
   runs:

| Test DB state | What `init_db()` exercises | Verdict |
|---------------|----------------------------|---------|
| No tables at all (fresh CI database) | `create_all()` creates every column; the ALTER block finds nothing to add | Green without the migration path ever running |
| Tables already at the new shape (calling `init_db()` twice) | Both `create_all()` and the ALTER no-op | Proves idempotency only, never application |
| Tables at the **previous** shape (new columns dropped) | The ALTER block runs — the path a deploy will take | The only state that tests the migration |

3. **Reproduce the previous shape explicitly**: `ALTER TABLE t DROP COLUMN <new>`
   for each new column, then call `init_db()`, then assert. Put the restore in a
   `finally` block so a failed assertion does not leave the database half-migrated
   for the rest of the suite.

4. **Assert against the catalog, not the ORM.** Query `information_schema.columns`
   for `data_type`, `is_nullable`, and `column_default` per column. The model object
   reports what you declared; only the catalog reports what the database has.

5. **Assert what pre-existing rows read back.** Insert a row before the drop, and
   after `init_db()` assert its value for each new column. Postgres fills existing
   rows from the `DEFAULT` in the `ADD COLUMN` clause — "the default value will be
   returned the next time the row is accessed" — so a constant default is instant
   and correct. An `ADD COLUMN` written without a `DEFAULT` leaves those rows NULL,
   which is the defect this assertion exists to catch.

## Edge cases

| Case | Then |
|------|------|
| The new column is `NOT NULL` | `ADD COLUMN ... NOT NULL` against a non-empty table needs the `DEFAULT` in the same statement, or it fails outright — assert `is_nullable='NO'` *and* the surviving row's value |
| The default is volatile (`clock_timestamp()`), generated, or identity | Each existing row is updated at `ALTER` time — a rewrite under `ACCESS EXCLUSIVE`; size it as a maintenance operation ([databases-schema-design-online-schema-changes]) |
| Tests run on SQLite while production is Postgres | `information_schema` does not exist and `ADD COLUMN` default semantics differ — run this test against the production engine or it proves nothing about the deploy |
| The suite shares one database across tests | The drop/restore window is visible to anything running concurrently — serialize this test or give it its own schema ([testing-data-test-data-and-isolation]) |
| CI always starts from an empty database | Both paths ship, so keep a fresh-create assertion too; the drop-and-restore test covers only the upgrade path |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Call `init_db()` twice and call that the migration test | Drop the new columns, re-run `init_db()`, assert catalog + existing rows | Two calls against an already-correct schema exercise only the no-op path |
| Declare `server_default=` on the model and expect deployed tables to pick it up | Put the `DEFAULT` in the `ALTER TABLE ADD COLUMN` statement and assert an old row's value | `server_default` shapes CREATE TABLE only; SQLAlchemy states ALTER "is outside of the scope of SQLAlchemy itself" |
| Assert the new column exists by selecting it through the ORM | Query `information_schema.columns` for type, nullability, and default | A successful SELECT proves presence, not type/nullability/default — the parts a hand-written ALTER gets wrong |
| Leave the dropped columns in place when an assertion fails | Restore in `finally` | A failed run otherwise poisons every later test against that database |

## Sources

- https://docs.sqlalchemy.org/en/20/core/metadata.html — `create_all()` "will issue queries that first check for the existence of each individual table, and if not found will issue the CREATE statements"; altering constructs "via the ALTER statement … is outside of the scope of SQLAlchemy itself" (Alembic is the recommended tool)
- https://docs.sqlalchemy.org/en/20/core/defaults.html — `Column.server_default` "gets placed in the CREATE TABLE statement during a `Table.create()` operation"; `Column.default` is applied client-side at INSERT. Neither backfills existing rows
- https://www.postgresql.org/docs/current/ddl-alter.html — "Adding a column with a constant default value does not require each row of the table to be updated … Instead, the default value will be returned the next time the row is accessed"; volatile defaults update every row at `ALTER TABLE` time
- Field context: a 2026-08 schema task added six columns; the drop-and-restore test re-checked `data_type` / `is_nullable='NO'` / `column_default` per column from `information_schema` and asserted a pre-existing row read back its defaults, in a 397-test suite
