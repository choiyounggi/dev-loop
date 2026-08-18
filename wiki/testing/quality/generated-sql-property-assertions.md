---
id: testing-quality-generated-sql-property-assertions
domain: testing
category: quality
applies_to: [postgresql, mysql, general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/functions-conditional.html
  - https://www.postgresql.org/docs/current/functions-aggregate.html
  - https://dev.mysql.com/doc/refman/8.4/en/comparison-operators.html
  - https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/
last_verified: 2026-08-14
related: [testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, databases-schema-design-nullability-and-defaults, backend-common-change-impact-aggregation-layer-of-a-shared-helper]
---

# Locking a Missing-Value Property in Generated SQL the Suite Never Executes

## When this applies

A test asserts on the SQL a query builder renders (`.toSQL()`, `sqlToQuery()`, a
compiled-string snapshot) because CI has no database to run it against, and the
property you need is semantic rather than textual — "a missing value must stay
missing", "the tenant filter must stay applied". Also when such an assertion is
green and a hand-seeded mutant that refills the missing value survives it.

Asserting that a _call site_ still exists in hand-written source, rather than a
property of a generated string, is a different subject — that guard binds an
anchor to a site, this one binds a property to a whole expression.

## Do this

1. **Partition the refill by _position_ before choosing any pattern.** A refill
   that defeats the property can be written in one of two places, and the two are
   caught by disjoint assertion families. No single family covers both, so the
   question "is this property locked?" has no answer until both positions are
   named:

| Position | Example | What can catch it |
|----------|---------|-------------------|
| Outside the expression | `COALESCE(<whole rendered key>, 0)` | Top-level start/end anchors (any wrapper, unnamed included) |
| Inside the expression | `ELSE COALESCE(SUM(v),0)`, `ELSE GREATEST(SUM(v),0)` | A function-name check — the anchors cannot see it |
| Inside, no name at all | `ELSE (CASE WHEN SUM(v) IS NULL THEN 0 ELSE SUM(v) END)` | An occurrence count on the aggregate itself |
| Inside, guard result | `WHEN bool_or(v IS NULL) THEN 0` (guard yields zero) | A literal assertion on what the guard returns |
| Inside, decoy operand | guard and aggregate both moved to an unrelated column | Binding both to the alias captured from the anchor |

2. **Anchor the whole rendered expression — opening token and closing token — for
   the outside position.** Any wrapper then has to add text before the opening or
   between the close and whatever follows (the alias, the sort direction, the
   comma), so the anchors catch the class rather than enumerated names.

3. **Assert the guard's _result_, not just its presence, for the inside
   position.** `WHEN <guard> THEN NULL` as a literal is what separates "a guard
   exists" from "the guard yields missing"; a guard rewritten to yield `0` leaves
   every structural anchor intact.

4. **Assert the aggregate's occurrence count.** A nameless `CASE` refill has to
   evaluate the aggregate a second time, so "`SUM(` appears exactly once" is the
   only family that reddens on it — and it doubles as the single-evaluation
   regression guard for a correlated subquery.

5. **Bind the guarded identifier and the aggregated identifier to an alias
   captured from the anchor** rather than hardcoding the name. Capturing keeps a
   behaviour-preserving rename green while a swapped or dead column still reddens.

6. **Build the coverage matrix, one hand-seeded mutant per row of step 1, and
   record which family killed each.** A mutant no family kills is a missing
   family; a family that kills nothing is dead weight. Stryker's published
   catalogue enumerates sixteen mutator groups that replace or remove nodes —
   Block Statement "removes the content of every block statement" — and wrapping
   an expression in a call is not among them, so nothing seeds this class for you.

7. **Run behaviour-preserving controls and require green**: rename the alias, and
   reflow the rendered whitespace. Without them, a pattern narrowed until every
   mutant dies is indistinguishable from one narrowed to nothing
   ([testing-quality-harness-reverse-controls]).

## Edge cases

| Case | Then |
|------|------|
| The property is "missing stays missing" but the column is `NOT NULL` in the schema | The aggregate still produces `NULL` over zero rows — `sum` of no rows returns null — so keep the assertion and note that the schema does not supply it |
| A bare aggregate is the refill (`SUM` alone, no wrapper) | `SUM` skips nulls, so a partial sum reads as a measured total; the property needs the guard, and the guard is what step 3 pins ([backend-common-change-impact-aggregation-layer-of-a-shared-helper]) |
| The same expression is rendered into both the select list and `ORDER BY` | Anchor each occurrence separately: `ORDER BY` renders without an alias, so the select-list anchor does not fit it |
| The builder emits bind placeholders (`$1`) whose numbering shifts with unrelated query changes | Anchor the structure around the placeholder and assert the bound parameter list separately, so an added filter elsewhere does not redden the property test |
| The builder normalizes or reflows whitespace between versions | Match a token sequence with bounded gaps rather than a literal multi-line string, and keep the step-7 reflow control |
| CI can run a real database | Assert the property by executing the query over an all-missing fixture and requiring `null` — an executed result outranks any string assertion, and the string test becomes a fast redundancy |
| The refill is legitimate for this field (zero and absent genuinely mean the same thing) | Move the decision to the schema or the API contract and delete the assertion, rather than keeping a guard the code is meant to violate ([databases-schema-design-nullability-and-defaults]) |
| A mutant survives every family | Read it as a missing position in step 1, not a pattern to tighten: identify where the mutant put its refill, and add the family that owns that position |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert the inner expression (`/SUM\(\s*v\s*\)/`) and call the property locked | Add the top-level anchors and the three inside-position families | A wrapper preserves every token the inner assertion reads, so `COALESCE(SUM(v),0)` passes an assertion written to forbid exactly that |
| Treat top-level anchors as primary and the name check as redundant | Keep both, and know which position each owns | Measured: an inner `COALESCE`/`GREATEST` refill leaves both anchors matching — only the name check reddens it, so dropping the name check reopens the hole |
| Rely on names once you have anchors | Add the aggregate-occurrence count as well | A nameless `CASE WHEN … IS NULL THEN 0 ELSE …` refill passes the anchors _and_ the denylist; the duplicated aggregate is its only signature |
| Hardcode the alias in the anchor to make the pattern precise | Capture the alias from the anchor and require guard and aggregate to reference it | A hardcoded alias reddens on a rename that changes no behaviour, and a red run on correct code is what gets an assertion loosened |
| Ship the assertions because all seeded mutants died | Run the rename and reflow controls and require green | An over-narrowed pattern kills every mutant and every correct variant alike; the controls separate the two |
| Port a name denylist from another project's engine | State the engine and check that engine's NULL rule for each listed function | `GREATEST(NULL, 0)` is `0` on PostgreSQL and `NULL` on MySQL, so the same list protects different properties on the two |

## Sources

- https://www.postgresql.org/docs/current/functions-conditional.html — GREATEST/LEAST: "NULL values in the argument list are ignored. The result will be NULL only if all the expressions evaluate to NULL. (This is a deviation from the SQL standard...)"; COALESCE "returns the first of its arguments that is not null. Null is returned only if all arguments are null"
- https://www.postgresql.org/docs/current/functions-aggregate.html — "except for `count`, these functions return a null value when no rows are selected. In particular, `sum` of no rows returns null, not zero as one might expect" — the property under test exists because of this
- https://dev.mysql.com/doc/refman/8.4/en/comparison-operators.html — "`GREATEST()` returns `NULL` if any argument is `NULL`"; for LEAST, "If any argument is `NULL`, the result is `NULL`. No comparison is needed" — the engine-dependence behind the last `Instead of` row
- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ — sixteen mutator groups, all replacing or removing nodes ("This mutant operator removes the content of every block statement"); wrapping an expression in a call is absent from the catalogue, so step-6 mutants are hand-seeded
- Measured 2026-08-14 (PostgreSQL 16.14 and 17.11, both in Docker): over two all-NULL rows and over zero rows `sum(v)` → `NULL`; over `[5, NULL]` → `5` (the partial sum); `GREATEST(NULL,0)` → `0`, `GREATEST(NULL,NULL)` → `NULL`, `LEAST(NULL,0)` → `0`; `COALESCE(sum(v),0)`, `GREATEST(sum(v),0)` and `CASE WHEN sum(v) IS NULL THEN 0 ELSE sum(v) END` all → `0`
- Local reproduction 2026-08-14 (Node v24.8.0, six assertion families against the real rendered ORDER BY key of rtb-unified `buildingListOrderBy('vacancyArea')`): each seeded refill was killed by exactly one family — outer `COALESCE` by the start/end anchors, inner `COALESCE`/`GREATEST` by the name check only (both anchors still matched), a nameless inner `CASE` refill by the aggregate-occurrence count only (anchors and name check both passed), a guard rewritten to yield `0` by the literal `THEN NULL`, and a dead-column swap by the captured-alias binding. Both controls (alias rename, whitespace reflow) stayed green across all six
- Field measurement 2026-08-14 (rtb-unified, NEWRTB-2786): assertions bounded to the inner `CASE`/`SUM` left `ELSE COALESCE(SUM(x),0)` and a whole-subquery `COALESCE` alive across a green run; adding a name check still left a nameless single-evaluation `CASE` refill alive. The shipped test file carries the anchors, the `THEN NULL` literal, the captured-alias binding and a name check, and its correlated-subquery fingerprint count is keyed on the source column rather than the aggregate — which is why the nameless refill was the one form still standing when the matrix was built
