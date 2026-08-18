---
id: databases-data-survey-surveying-live-data-for-a-rule
domain: databases
category: data-survey
applies_to: [postgresql, mysql, sqlite, general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/functions-aggregate.html
  - https://greatexpectations.io/blog/exploring-data-quality-volume/
last_verified: 2026-08-05
related: [databases-data-survey-catalog-statistics-as-current-state, databases-query-optimization-existence-and-count-checks, databases-schema-design-requirements-to-tables, databases-schema-design-nullability-and-defaults]
---

# Surveying Live Data to Derive a Mapping or Normalization Rule

## When this applies

A task tells you to sample real data to decide a rule — a region/code mapping
table, a normalization or canonicalization spec, an enum's allowed values, a
parsing rule — and you can connect to the database that holds it. You are about to
run distribution queries (`GROUP BY`, `DISTINCT`, `count`) and write the rule from
what comes back.

## Do this

1. **Establish volume before reading distribution.** Run `SELECT count(*)` over the
   target table (and over the exact filtered scope you will survey) as the first
   query. Record the number in the deliverable. A distribution query is evidence
   only about a source you have shown to be populated.
2. Read the count against what each query shape returns on empty input, because the
   shapes disagree:

| Query shape | Result over zero input rows |
|-------------|-----------------------------|
| `SELECT col, count(*) … GROUP BY col` | Zero rows — visually identical to "this column has no values needing normalization" |
| `SELECT DISTINCT col …` | Zero rows — same ambiguity |
| `SELECT count(*) …` (no `GROUP BY`) | One row containing `0` — unambiguous |
| `SELECT max(col)` / `sum(col)` / `array_agg(col)` | One row containing `NULL`, not `0` and not an empty array |

3. When the count is 0, **switch the evidence source instead of the conclusion**:

| Case | Do |
|------|----|
| Table empty, writers exist in the repo | Derive the stored shape from the code that writes the column — every collector/ingester/serializer that assigns it — and from the migration or model that declares its type and nullability |
| Table empty, writers are external | Derive it from the upstream contract (API schema, sample response captured live, feed spec) and label the rule provisional until real rows land |
| Table empty, existing tests populate it | Read the fixtures; they encode the shape the team already agreed on |
| Table populated but the survey scope filtered everything out | Widen the predicate one clause at a time until rows appear — the empty result was about the filter, not the data |

4. **Record the substitution in the artifact you produce.** State in the mapping
   table's header comment or the spec section: the count you observed, the date, and
   which code paths or fixtures the rule was derived from instead. A later reader
   otherwise cannot tell a data-derived rule from a code-derived one.
5. Include `NULL` and the empty string as explicit rows of the rule. A survey over
   real rows shows them; a survey over an empty table cannot
   ([databases-schema-design-nullability-and-defaults]).

## Edge cases

| Case | Then |
|------|------|
| The environment you connected to is not the one holding the data (local vs staging vs prod replica) | Confirm the target before concluding: check the connection's database/host and a table you know is populated. An empty count from the wrong host reads exactly like an empty table |
| Rows exist but every value in the surveyed column is `NULL` | `GROUP BY` returns one group whose key is `NULL`; the rule needs a `NULL` branch, and the non-`NULL` shape still has to come from code |
| The count is small but non-zero (a handful of rows) | Treat it as a sample, not a census: cross-check against the writers before closing the value set, and say in the artifact that the set is open |
| Writers disagree with each other about the stored shape | That disagreement is the finding — record every producer's shape and route the normalization decision to the owner rather than picking one |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read "zero rows returned" from a `GROUP BY` as "no values to normalize" | Run `count(*)` first and branch on it | `GROUP BY` over an empty table returns no rows without error — the empty result carries no information about the values |
| Write the mapping from the shape you expect the data to have | Derive it from the writers and fixtures, then mark it provisional | Tests written against the same assumption pass, so the whole change is green and wrong |
| Skip recording that the survey found no data | Note the count, date, and substituted evidence in the artifact | The next reader inherits a rule that looks data-backed and re-derives nothing |

## Sources

- https://www.postgresql.org/docs/current/functions-aggregate.html — "except for `count`, these functions return a null value when no rows are selected. In particular, `sum` of no rows returns null, not zero as one might expect, and `array_agg` returns null rather than an empty array"
- https://greatexpectations.io/blog/exploring-data-quality-volume/ — volume (row count) as a first-class data-quality dimension; undetected volume anomalies "skew analyses and lead to flawed decision-making"
- Reproduced 2026-08-05 (`sqlite3 :memory:`, empty table): `SELECT area_nm, count(*) … GROUP BY area_nm` → 0 rows; `SELECT count(*)` → one row `0`; `SELECT max(area_nm)` → one row `NULL`
