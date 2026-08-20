---
id: testing-strategy-orm-generated-test-schema
domain: testing
category: strategy
applies_to: [java, kotlin, jpa, hibernate, spring, general]
confidence: field-tested
sources:
  - https://docs.spring.io/spring-boot/reference/data/sql.html
  - https://docs.spring.io/spring-boot/how-to/data-initialization.html
  - https://jakarta.ee/specifications/persistence/3.1/apidocs/jakarta.persistence/jakarta/persistence/column
  - https://docs.hibernate.org/orm/6.4/javadocs/org/hibernate/tool/schema/Action.html
last_verified: 2026-08-18
related:
  [
    qa-environments-test-environment-parity,
    testing-strategy-test-level-choice,
    backend-java-jpa-entity-mapping,
    databases-schema-design-nullability-and-defaults,
  ]
---

# Reproducing a Model-vs-Database Drift When Tests Build Their Own Schema

## When this applies

A defect comes from the ORM model and the real database disagreeing — the entity
declares `nullable = false` while the column is nullable, a length or type differs,
an index the model assumes is absent — and you are planning a regression test for
it. Also when reviewing a plan whose verification step is "add a test that
reproduces it" for any drift-shaped defect.

## Do this

1. **Read the test profile's schema source before promising a reproduction.** The
   answer decides whether a test can hold this defect at all:

| Test schema source | Can the drift exist there | Verification to plan instead |
|---|---|---|
| Generated from the ORM model (`ddl-auto: create-drop` / `create` / `update`) | No — the column is created *from* the declaration under test | A schema-comparison gate, or a test database built from the migrations |
| Built by the migration tool (Flyway/Liquibase) against a real engine | Yes | The regression test, plus `ddl-auto: validate` so the mismatch fails startup |
| Pointed at a shared pre-provisioned database | Yes, if that database tracks production DDL | The regression test, plus a check that the schema is current |

2. **When the schema is generated from the model, say so in the plan and switch
   the verification target.** Two mechanisms hold this class of defect:
   - `spring.jpa.hibernate.ddl-auto: validate` against a migration-built test
     database — startup fails on the mismatch, which is the drift itself;
   - a query against `information_schema.columns` in CI comparing the deployed
     schema's nullability/type against the model's declarations.

3. **Name the environment the claim covers when reporting the fix.** "Tests pass"
   from an entity-generated schema clears the code path and not the drift; state
   which dimension is unmatched, the way an environment-parity inventory does
   ([qa-environments-test-environment-parity]).

4. **Fix the drift at its source in the same change.** The declaration and the
   column are two artifacts of one contract: correct whichever is wrong (a
   migration that adds `NOT NULL` after backfilling, or an entity change to
   `nullable = true`), so the gate you add in step 2 stays green for the right
   reason ([databases-schema-design-nullability-and-defaults]).

## Edge cases

| Case | Then |
|------|------|
| The test profile uses an embedded database (H2/HSQL) that Spring Boot auto-creates | Same blind spot with a second layer — dialect differences also hide engine-specific behaviour; put the drift gate on a real engine |
| You want the reproduction anyway, via a native `INSERT` of the offending row | The generated schema still carries the constraint, so the insert is refused by the database rather than by the code under test — record that as "not reproducible here", not as "cannot happen" |
| The runtime failure is Hibernate's own not-null check rather than the database's | It reproduces only where the entity metadata and the row disagree, so it needs a row the generated schema cannot store — same routing as above |
| The project has no migration tool | The drift gate is the `information_schema` comparison; add it before promising any test-level reproduction |
| The drift is in an index or a default rather than nullability | Same rule — anything the generator writes from the model is unobservable in a generated schema; compare catalogs |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Plan "add a failing test, then fix the entity" for a model-vs-DB mismatch | Check `ddl-auto` first, then plan a schema-comparison gate when it generates | A generated schema materialises the declaration under test, so the failing state cannot be constructed and the plan's red step never happens |
| Read a green suite as evidence the drift is gone | Read it as evidence about the generated schema only, and check the deployed catalog | The suite and production are describing different schemas; only one of them was built from the migrations |
| Set `ddl-auto: update` on the test profile to get "closer to real" | Point the test database at the migrations and use `validate` | `update` still derives DDL from the model, so it hides the same class of mismatch while adding non-deterministic schema state |

## Sources

- https://docs.spring.io/spring-boot/reference/data/sql.html — "By default, JPA databases are automatically created **only** if you use an embedded database"; and `spring.jpa.hibernate.ddl-auto` maps to "Hibernate's own internal property name … `hibernate.hbm2ddl.auto`". This page shows `create-drop` as an example and does not enumerate the value set — the enumeration below comes from Hibernate's own javadoc
- https://docs.hibernate.org/orm/6.4/javadocs/org/hibernate/tool/schema/Action.html — the schema-tooling actions and their legacy `hbm2ddl.auto` names: `NONE` "No action" (`none`), `CREATE_DROP` "Drop the schema and then recreate it on `SessionFactory` startup" (`create-drop`), `UPDATE` "Update (alter) the database schema" (`update`), `VALIDATE` "Validate the database schema" (`validate`) — the recreate-on-startup semantics is why a generated test schema always matches the current model
- https://docs.spring.io/spring-boot/how-to/data-initialization.html — "If you are using a higher-level database migration tool, like Flyway or Liquibase, you should use them alone to create and initialize the schema"; and "Be careful when switching from in-memory to a 'real' database that you do not make assumptions about the existence of the tables and data in the new platform"
- https://jakarta.ee/specifications/persistence/3.1/apidocs/jakarta.persistence/jakarta/persistence/column — `@Column`'s `nullable` element is "(Optional) Whether the database column is nullable", default `true` — a declaration the schema generator writes into DDL, which is why a generated schema cannot contradict it
- Field measurement 2026-08-18 (RTB `manage` repository): `application.yml` runs `ddl-auto: none` with the deployed schema owned by migrations, while `application-test.yml` runs `ddl-auto: create-drop`; entity `RentRoll` declares `nullable = false` on a column whose production catalog reports `is_nullable = 'YES'`. The failure occurs only against the deployed schema, and the suite is green because its schema is generated from the same declaration the defect is about
