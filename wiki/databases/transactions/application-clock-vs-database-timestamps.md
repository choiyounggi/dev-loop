---
id: databases-transactions-application-clock-vs-database-timestamps
domain: databases
category: transactions
applies_to: [postgresql, mysql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/functions-datetime.html
  - https://www.postgresql.org/docs/current/dml-returning.html
  - https://www.postgresql.org/docs/current/transaction-iso.html
last_verified: 2026-08-27
related:
  [
    databases-transactions-isolation-level-selection,
    databases-data-survey-audit-columns-as-update-evidence,
    backend-common-jobs-scheduled-job-overlap,
    backend-common-change-impact-inserting-a-guard-before-an-existing-side-effect,
    testing-quality-injected-clock-duration-assertions,
  ]
---

# Comparing an Application Clock Against a Database Timestamp Column

## When this applies

A predicate compares a value your application produced (`new Date()`,
`Instant.now()`) against a timestamp column the database filled itself —
`created_on > $boundary`, `updated_at < $cutoff`, "rows older than N minutes".
Also when one step classifies rows by such a boundary and a **later** step
cancels, deletes, or cleans up the rows that classification chose.

## Do this

1. **Take the boundary from the database's own clock, in the statement that
   already touches those rows, using `RETURNING`.** The docs give this as
   `RETURNING`'s purpose — it is "very handy when relying on computed default
   values", returning them "without needing a separate database query". A column
   declared `default now()` is filled by the server; reading the same server's
   clock is what makes the two sides comparable.

2. **Produce the boundary once per decision and pass that value forward.**
   Recomputing the same formula in the follow-up step creates a *second* `now`,
   later than the first. For a `created_on <= boundary` shape the target set
   silently **widens**, so a row the first step classified as fresh — and meant
   to protect — falls inside the second step's cleanup set. Make the propagation
   structural: have the boundary helper take `now` as a parameter, and put the
   boundary in the classification's **return type** so the next step receives it
   instead of re-deriving it.

3. **When no database value is available to read, decide which direction of
   error is safe before choosing a margin**, and record the asymmetry:

| Clock relationship | Effect on a "rows newer than boundary" predicate | Read it as |
|--------------------|--------------------------------------------------|------------|
| App clock ahead of DB | Boundary sits in the DB's future — rows written in the gap are missed | Under-count: the dangerous direction for cancel/cleanup guards |
| App clock behind DB | Boundary sits in the DB's past — extra rows are included | Over-count: safe for a guard, wasteful for a batch |
| Unknown / unbounded skew | No margin is provable | Read the DB clock (step 1) or widen to the safe direction and say so |

4. **State the margin's assumption in the code.** A margin encodes "skew is
   smaller than this", which nothing in the query verifies — write that sentence
   next to the constant so the next reader knows what would invalidate it.

5. **Separate "same clock" from "correct ordering".** In PostgreSQL `now()` is
   `transaction_timestamp()`, the **start** time of the transaction: the docs
   state `statement_timestamp()` and `transaction_timestamp()` "return the same
   value during the first statement of a transaction, but might differ during
   subsequent statements", while `clock_timestamp()` "returns the actual current
   time, and therefore its value changes even within a single SQL statement". A
   long transaction that started earlier and committed later therefore stamps an
   **earlier** value than a short one that committed before it — so timestamp
   order is not commit order, and a reader can observe a row whose stamp
   precedes a boundary it was not visible for.

6. **When the decision must not miss a concurrently committed row, close the
   window with a lock or isolation level rather than a finer timestamp.**
   Take an advisory lock around classify-then-act, or run it `SERIALIZABLE`
   ([databases-transactions-isolation-level-selection]); timestamp precision
   does not create the mutual exclusion the correctness argument needs.

## Edge cases

| Case | Then |
|------|------|
| The column's default is `now()` and the app also writes the field on some paths | The table now holds two clocks in one column — pick one writer, and backfill or document the mixed range before using the column as a boundary ([databases-data-survey-audit-columns-as-update-evidence]) |
| The statement inserts nothing to `RETURNING` from (a pure read) | Select the clock explicitly (`SELECT now()`) in the same transaction and pass it down, so every predicate in the decision shares one value |
| Rows are stamped by several application hosts | Their clocks differ from each other as well as from the DB; a server-side default is the only single clock available |
| The boundary crosses a DST change or the column is `timestamp without time zone` | Compare in UTC/`timestamptz` end to end — a local-time column makes the comparison ambiguous for one hour a year ([platforms-environment-timezone-and-locale]) |
| The follow-up step runs in a different process or job | The boundary has to travel in the payload; a job that recomputes `now` on pickup reintroduces the widening from step 2 |
| MySQL rather than PostgreSQL | `NOW()` is likewise fixed for the statement while `SYSDATE()` reads the live clock — the same one-clock rule applies, with those two names |
| The test asserts elapsed time between two readings of the clock | Inject the clock so the assertion is deterministic ([testing-quality-injected-clock-duration-assertions]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pass `new Date()` as the boundary against a `default now()` column | Read the boundary from the DB (`RETURNING`, or `SELECT now()` in the same transaction) | The column is filled by the server's clock; comparing it to the app's makes skew an unmeasured term in the predicate |
| Recompute the same boundary formula in the cleanup step | Return the boundary from the classification and pass it in | The second `now` is later, so `<= boundary` widens and rows classified as protected become eligible |
| Add a fixed margin (`now - 5s`) and move on | Pick the direction the error must fall in, then set the margin, and write the skew assumption beside it | A margin without a stated direction is as likely to widen the dangerous side as the safe one |
| Treat equal timestamps as equal commit order | Order by a sequence/identity column, or serialize the decision with a lock | `now()` is transaction-start time, so a later-committing transaction can carry an earlier stamp |
| Tighten to `clock_timestamp()` to fix a missed row | Close the window with an advisory lock or `SERIALIZABLE` | The gap is visibility between two statements, not resolution — a finer clock narrows the race without removing it |

## Sources

- https://www.postgresql.org/docs/current/functions-datetime.html — "`transaction_timestamp()` is equivalent to `CURRENT_TIMESTAMP`"; "`statement_timestamp()` and `transaction_timestamp()` return the same value during the first statement of a transaction, but might differ during subsequent statements. `clock_timestamp()` returns the actual current time, and therefore its value changes even within a single SQL statement" — the basis for steps 5 and the MySQL row's analogue
- https://www.postgresql.org/docs/current/dml-returning.html — `RETURNING` obtains data from modified rows "without needing a separate database query", and is "very handy when relying on computed default values"; this is the mechanism in step 1
- https://www.postgresql.org/docs/current/transaction-iso.html — the isolation levels behind step 6's alternative to timestamp precision
- Field measurement 2026-08-26 (pg-boss 10.4.2): `src/plans.js` declares `created_on timestamp with time zone not null default now()` — the column is server-stamped, so an application-generated boundary compares two clocks. A mutation replacing the propagated boundary with a fresh `new Date()` reddened one wiring assertion, and an independent reviewer raised the transaction-visibility limit separately, which is what step 5 records
- Field measurement 2026-08-24 (`rtb-unified`, `packages/orpc/src/routers/batch.ts`): the in-flight batch check states "one `now` per decision" as an invariant and enforces it by having the boundary helper take `now` as a parameter; the classification's own result type omitted the boundary, which is the shape that invites the step-2 recomputation in the follow-up step
