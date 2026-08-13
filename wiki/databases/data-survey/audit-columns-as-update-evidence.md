---
id: databases-data-survey-audit-columns-as-update-evidence
domain: databases
category: data-survey
applies_to: [postgresql, mysql, general]
confidence: verified
sources:
  - https://github.com/spring-projects/spring-data-jpa/blob/main/spring-data-jpa/src/main/java/org/springframework/data/jpa/domain/support/AuditingEntityListener.java
  - https://docs.hibernate.org/orm/6.6/querylanguage/html_single/Hibernate_Query_Language.html
  - https://github.com/hibernate/hibernate-orm/blob/6.6/hibernate-core/src/main/java/org/hibernate/event/internal/DefaultFlushEntityEventListener.java
  - https://www.postgresql.org/docs/current/sql-createtrigger.html
last_verified: 2026-08-13
related: [databases-data-survey-surveying-live-data-for-a-rule, databases-schema-design-nullability-and-defaults, backend-java-jpa-not-null-check-and-lifecycle-callbacks]
---

# Audit Columns as Evidence About a Row's Update History

## When this applies

You are surveying live rows and about to turn an audit column into a behavioural
claim: `update_dt`/`updated_at`/`modified_by` is NULL (or unchanged) on every row of
interest and you read that as "these rows were never modified", "this feature is
unused", or "the bad values came in at insert and nothing touched them since". Also
when an incident investigation needs to know whether writes to those rows were
*attempted*.

Deriving a mapping or enum rule from a survey → [databases-data-survey-surveying-live-data-for-a-rule].

## Do this

1. **Identify what writes the column before reading it as history**, and bound the
   claim to that writer:

| Written by | Records | A NULL therefore means |
|------------|---------|------------------------|
| ORM lifecycle callback (`@PreUpdate`; Spring Data's `AuditingEntityListener.touchForUpdate` is `@PreUpdate`) | Only updates that reached the entity's flush action | No *successful, entity-level* update ran |
| Application code assigning the field | Only the code paths that assign it | No update through those paths |
| DB trigger (`BEFORE UPDATE … FOR EACH ROW`) or a generated/`ON UPDATE` column | Every statement the database executed on the row, whatever the client | The row's columns were not updated |

2. **State the bounded claim in the deliverable**: "no update ran through the path that
   stamps this column, as of <date>" — not "never updated". Name the writer you found
   in directive 1 alongside the count.
3. **Enumerate the write paths that leave the column untouched** before concluding
   anything, and check each against the code:

| Path | Why the column stays as it was |
|------|-------------------------------|
| The update failed pre-flush | Validation that runs before the update action is scheduled — e.g. Hibernate's not-null check → [backend-java-jpa-not-null-check-and-lifecycle-callbacks] — throws before any `@PreUpdate` listener runs |
| Bulk JPQL/HQL `update`, or native SQL | "The effect of an `update` or `delete` statement is not reflected in the persistence context": no entity flush, so no callback and no `@Version` bump unless the statement is `versioned` |
| Another service, migration, or manual SQL writes the table | It never loaded the entity, so the ORM's auditing was never in the path |
| The transaction rolled back after the callback set the field | The in-memory stamp is discarded with the transaction |

4. **Judge update history on an independent axis** — a history/audit table, the
   application logs for the writing endpoint, CDC/WAL, or a DB-side trigger installed
   going forward. Record which axis the conclusion rests on.
5. **Require one positive control before acting on the absence.** Find at least one row
   whose audit column *is* set by the same writer (or a test that exercises it). Absent
   that, the NULLs are equally explained by "the writer never worked here", and any
   decision built on them (backfill, drop the column, close the ticket as "unused") is
   resting on an unmeasured mechanism.

## Edge cases

| Case | Then |
|------|------|
| Only old rows are NULL | The auditing was added later — find the migration or the earliest non-null value and read NULL as "before instrumentation", not as behaviour |
| `updated_at` equals `created_at` on every row | The writer stamps both at insert; equality is evidence of no update only if you have confirmed the update path stamps it (directive 5) |
| Every non-null value shares one timestamp | A backfill or bulk migration wrote them; those rows carry no per-row update history |
| The column is `NOT NULL DEFAULT now()` | It cannot distinguish "inserted" from "updated" at all — pair it with a separate insert timestamp or a history table |
| The claim needed is "did anyone *read*/attempt this" | Audit columns cannot answer it in any configuration; go to application logs or the DB's statement/audit logging |
| Rows are soft-deleted | The delete may run as an update through a different path than the business update → [databases-schema-design-soft-delete] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude "never modified" from all-NULL audit columns | State the bounded claim (directive 2), then confirm on an independent axis (directive 4) | The column records successes of one path; failed, bulk, and out-of-band writes leave it untouched |
| Treat the audit column as the failure timeline in an incident | Use application logs or a history table for attempts, and keep the audit column for confirmed successes | The investigation's subject is the failing write, which is exactly the event the column cannot record |
| Add `@PreUpdate` auditing to close the gap you just found | Add a DB trigger (or generated column) when the requirement is "every statement, whatever the client" | Callback auditing is bypassed by bulk DML, native SQL, and other services by construction |

## Sources

- https://github.com/spring-projects/spring-data-jpa/blob/main/spring-data-jpa/src/main/java/org/springframework/data/jpa/domain/support/AuditingEntityListener.java — `AuditingEntityListener.touchForCreate` is annotated `@PrePersist` and `touchForUpdate` `@PreUpdate`, so `@LastModifiedDate` is written by a JPA lifecycle callback
- https://docs.hibernate.org/orm/6.6/querylanguage/html_single/Hibernate_Query_Language.html — mutation statements: "The effect of an `update` or `delete` statement is not reflected in the persistence context, nor in the state of entity objects held in memory at the time the statement is executed"; "It's the responsibility of the client program to maintain synchronization of state held in memory with the database"; `update` leaves `@Version` attributes alone unless the `versioned` keyword is used
- https://github.com/hibernate/hibernate-orm/blob/6.6/hibernate-core/src/main/java/org/hibernate/event/internal/DefaultFlushEntityEventListener.java — `scheduleUpdate` runs the nullability check before `EntityUpdateAction` is queued, so a pre-flush validation failure precedes every `@PreUpdate` listener
- https://www.postgresql.org/docs/current/sql-createtrigger.html — "A trigger that is marked `FOR EACH ROW` is called once for every row that the operation modifies"; the trigger is defined on the relation, not in a client, which is what makes it the axis independent of the application's write path
- Field observation 2026-08-13 (PostgreSQL, `manage.building_tenant_floor_info`): all 574 rows with a NULL business code also had `update_dt` NULL, which read as "never edited"; those rows' UPDATEs were in fact failing in Hibernate's `Nullability` check before `EntityUpdateAction` was created, so the `@PreUpdate` stamp never ran. The same repository also updates a table by bulk JPQL without setting `updateDt`, a second path with the same signature
