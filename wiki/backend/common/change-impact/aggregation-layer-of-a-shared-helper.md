---
id: backend-common-change-impact-aggregation-layer-of-a-shared-helper
domain: backend
category: change-impact
applies_to: [general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/functions-aggregate.html
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/reduce
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html
last_verified: 2026-08-14
related: [backend-common-change-impact-call-site-enumeration, databases-schema-design-nullability-and-defaults, testing-quality-checks-that-cannot-pass, testing-quality-generated-sql-property-assertions]
---

# A Plan Unifying Call Sites That Sit in Two Different Aggregation Layers

## When this applies

A plan, task brief, or review comment tells you to unify or replace "the N call
sites" of a helper, and identifies those sites by line number rather than by what
the code does. One of the sites feeds a set-level aggregate in the database while
another returns a per-row value that application code reduces later. Also when a
"shared helper" change landed with one consumer adopting it while the other kept
its old semantics.

Establishing that the site list is _complete_ →
[backend-common-change-impact-call-site-enumeration]. This page is about the
sites the list already names.

## Do this

1. **Open each named site and record which layer owns the reduction**, before
   editing anything. Grep reports both as a call to the same helper; the owner of
   the roll-up rule is what decides whether one helper can serve both:

| What the site does | Who owns the roll-up | Consequence for a shared helper |
|--------------------|----------------------|---------------------------------|
| The helper's output sits inside a set-level aggregate (`SELECT SUM(helper(col))`) | The database's aggregate semantics | Changing the helper changes the rolled-up value |
| The helper's output is a per-row projection (`vacancyArea: helper(col)`) consumed by a later in-language reduce | The application function that reduces the rows | Changing the helper leaves the roll-up rule untouched — the reduce still decides the result |
| The helper's output is returned to a caller that neither aggregates nor reduces | The caller | Neither of the above rules applies; treat it as a third route |

2. **Compare the two layers at the empty and all-missing boundary**, because that
   is where they diverge and where a unification silently picks one convention.
   PostgreSQL computes `sum` over "the non-null input values", and "except for
   `count`, these functions return a null value when no rows are selected. In
   particular, `sum` of no rows returns null, not zero as one might expect." A
   seeded reduce has the opposite default — MDN: "if `initialValue` is provided but
   the array is empty, the solo value will be returned without calling
   `callbackFn`". A rule that treats any missing input as missing output agrees
   with none of them:

| Input | SQL `SUM(v)` | `reduce((a,b)=>a+(b??0), 0)` | `filter(non-null)` then reduce, `null` when empty | strict: any missing → missing |
|-------|--------------|------------------------------|---------------------------------------------------|-------------------------------|
| `[5, null]` | `5` | `5` | `5` | `null` |
| `[null, null]` | `NULL` | `0` | `null` | `null` |
| `[]` (no rows) | `NULL` | `0` | `null` | `null` |

Measured 2026-08-14 (PostgreSQL 16.14 and 17.11; Node v24.8.0). No two columns
agree everywhere, so a plan that moves a rule from one column to another is
changing behaviour even when the helper's text is identical. The `[5, null]` row
is the dangerous one: three of the four routes return a **partial sum** that reads
downstream as a measured total, so a domain whose policy is the fourth column
cannot express its rule with a bare aggregate at all.

3. **Check the plan's acceptance criterion against each route before adopting
   it.** A criterion phrased as a grep count ("this helper appears at exactly two
   sites") is reachable only on the route where both consumers call it. State
   which route makes it reachable, or replace the criterion with one that holds on
   the route you take — a criterion no route satisfies turns the task into
   improvisation ([testing-quality-checks-that-cannot-pass]).

4. **Name one owner of the rule and write it into the plan before editing.** Three
   routes exist: push the reduce into SQL so one aggregate owns it; keep the reduce
   and have the helper render only the per-row value it consumes; or give the rule
   its own pure function and make every other route — the SQL included — a declared
   _mirror_ of it. The third scales past two consumers, because the mirror
   relationship is what a test can assert; the first two leave the rule wherever it
   already was. Recording the choice is what stops the next round re-deriving it.

5. **Assert that every consumer agrees, not that each one is individually
   plausible.** Feed one fixture through all routes and require identical output,
   including at the boundary. A per-consumer test passes while two consumers hold
   different rules — agreement is the property the unification was for, and for the
   SQL route it is asserted on the rendered expression
   ([testing-quality-generated-sql-property-assertions]).

6. **Re-run the enumeration after the edit and report the count with its
   command**, since `grep -c` writes "only a count of selected lines" — a site
   whose call spans two lines, or two calls on one line, moves the number without
   moving the code.

## Edge cases

| Case | Then |
|------|------|
| The reduce is shared with an unrelated field (the same `sumCounts` also folds a parking count) | Its callers are a second enumeration pass — changing the reduce to match the aggregate changes every field it folds, so change the call site rather than the shared reduce |
| Only one consumer's boundary behaviour is specified by the policy document | Implement that one against the policy and record the other as an open decision in the plan; matching it to the specified one by symmetry invents a rule nobody approved |
| The per-row route is a paginated list and the aggregate route is a detail view | They can legitimately differ in cost but not in value; keep one owner of the rule and let the other read the same rendered expression |
| The helper is called from a raw SQL string as well as the builder | The string site is not statically enumerable by the builder's API — enumerate the string form too and record it in the plan |
| A single site is both: a per-row projection that a window function also aggregates | The database owns both; treat it as row one of the step-1 table and drop the application reduce |
| The plan names line numbers and the file has since moved | Re-derive the sites from the code shape, not the numbers, and update the plan — a stale line number points at a site that does something else now |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Adopt "replace the two call sites of this helper" because grep shows two hits | Open both and record which layer reduces the value | A per-row projection and a set-level aggregate are the same text and different operations; only one of them is changed by editing the helper |
| Land the helper at the SQL site and leave the list route on its old reduce | Choose the owning layer in the plan and migrate both consumers, or narrow the task to one consumer explicitly | A helper with one adopted consumer is the producer/consumer drift the unification existed to remove, and both sides stay green |
| Report the task done because the grep count matches the plan | Feed one fixture through every consumer and require identical output at the boundary | The count is satisfied by the text; agreement is the property, and a per-consumer test is green while two consumers still hold different rules |
| Read a `SUM` that returns a number as evidence the value was measured | Check whether any summand was missing before trusting the total | `sum` skips nulls, so `[5, null]` returns `5` — a partial sum reaches sorting and display as though it were complete |
| Wrap the aggregate in `COALESCE(..., 0)` so it matches the seeded reduce | Decide whether zero and absent mean the same thing for this field, and make both layers say so | `sum` of no rows is null by specification; refilling it makes "not measured" indistinguishable from "measured as zero" ([databases-schema-design-nullability-and-defaults]) |

## Sources

- https://www.postgresql.org/docs/current/functions-aggregate.html — `sum` "Computes the sum of the non-null input values"; "It should be noted that except for `count`, these functions return a null value when no rows are selected. In particular, `sum` of no rows returns null, not zero as one might expect". (The page's sentence "All these functions ignore null values in their aggregated input" belongs to Table 9.64, the ordered-set aggregates — not to `sum`; the per-function description above is the sourced statement for `sum`.)
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/reduce — "If the array only has one element (regardless of position) and no `initialValue` is provided, or if `initialValue` is provided but the array is empty, the solo value will be returned without calling `callbackFn`"; a `TypeError` is "Thrown if the array contains no elements and `initialValue` is not provided"
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html — `-c`: "Write only a count of selected lines to standard output" — the count is over lines, not matches
- Measurement 2026-08-14 (PostgreSQL 16.14 and 17.11, both in Docker): over two all-NULL rows `sum(v)` → `NULL`; over zero rows → `NULL`; over `[5, NULL]` → `5`. Node v24.8.0 on the same values: `[null,null].reduce((a,b)=>a+(b??0),0)` → `0`, `[].reduce((a,b)=>a+b,0)` → `0`, `[].reduce((a,b)=>a+b)` → `TypeError: Reduce of empty array with no initial value`, and a filter-then-reduce returning `null` for an empty remainder → `null` — the table in step 2
- Field incident 2026-08-14 (rtb-unified, NEWRTB-2786 building vacancy roll-up): a plan named two SQL call sites of a vacancy-area helper by line number. One was a real `SELECT … SUM(...)`; the list value came from a per-block projection reduced in TypeScript by `deriveDetailBlockRollup` → `sumCounts`, which filters nulls and returns null only when _all_ are null — the skip-missing column of step 2, while the policy wanted the strict column. Adopting the plan as written would have landed the helper at the aggregate while the list kept its reduce, and its "two call sites" acceptance grep was unreachable on that route. Verified in the worktree 2026-08-14: the shipped resolution took step 4's third route — a pure `sumVacancyAreaStrict` single-owns the rule (empty → null, any null → null), the sort SQL is a declared mirror (`CASE WHEN bool_or(v IS NULL) THEN NULL ELSE SUM(v) END`), all three consumers (detail, list, sort) are asserted to agree by `building-vacancy-path-parity.test.ts` (15 tests passing), and `sumCounts` was deliberately left in place for the parking-count axis whose missing semantics differ. The plan's line numbers had already drifted by the time of this check (`sumCounts` at `:1658`, not `:1644`), which is the last edge case above
