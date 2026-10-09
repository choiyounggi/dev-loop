# Knowledge flush — 2 insight(s)

Claimed 8 queue rows (run `20261004-022317-4305`): 2 general insights ingested by amending existing pages, plus 6 plan-gap rows that are linkly-only and retired as local-layer candidates.

## Verified best-practice

### 1. One nulls-last order across SQL backends and an in-memory sort (`8d43c437e28dbd89`, databases)

Claim: when a value can be missing and the same order must hold in SQL and in Python (or a Fake repository), put an explicit leading "is absent" key in every implementation. In SQL that is `ORDER BY (col IS NULL), col [DESC]`. In Python, sort the present values and append the missing ones. Test ASC and DESC on every backend. A keyset cursor over that order must carry the is-null flag.

Sources checked:
- https://www.postgresql.org/docs/current/queries-order.html — "By default, null values sort as if larger than any non-null value; that is, NULLS FIRST is the default for DESC order, and NULLS LAST otherwise"
- https://www.sqlite.org/lang_select.html — "NULLs naturally appear at the beginning of an ASC order-by and at the end of a DESC order-by"; https://www.sqlite.org/changes.html — `NULLS FIRST/LAST` added in 3.30.0 (2019-10-04)
- https://dev.mysql.com/doc/refman/8.4/en/working-with-null.html — "NULL values are presented first if you do ORDER BY ... ASC and last if you do ORDER BY ... DESC"; https://dev.mysql.com/doc/refman/8.4/en/select.html has 0 matches for `NULLS LAST` (positive control: 12 matches for `ORDER BY`)
- https://docs.python.org/3/reference/expressions.html — "A default order comparison (<, >, <=, and >=) is not provided; an attempt raises TypeError"
- https://www.sqlite.org/rowvalue.html — a row-value comparison is NULL when substituting values for the NULL could make it either true or false

How it was verified (local, SQLite 3.51.0, Python 3.14.6):
- `ORDER BY k` put NULLs first and `ORDER BY k DESC` put them last. `ORDER BY (k IS NULL), k` and `(k IS NULL), k DESC` put them last in both directions.
- `sorted([3, None, 1])` raised `TypeError: '<' not supported between instances of 'NoneType' and 'int'`.
- `WHERE (k, id) > (NULL, 1)` returned 0 rows.
- A keyset walk with page size 2 over 7 rows (3 NULL) used the branched predicate written into the page. It returned `[3, 6, 2, 5, 1, 4, 7]`, identical to the full `ORDER BY (k IS NULL), k, id`, so it crosses the present→missing boundary correctly.

Session evidence: a DESC-only SQLite test stayed green before the fix while the ASC and sorted-query cases failed (`FAILED (failures=2, errors=8)`).

Wiki correction found during verification: the existing nullability row said "PostgreSQL sorts NULLs last on ASC by default, MySQL first". That is true but names only the ASC side, so it reads as if the engines differ in kind. The docs above show that all three engines flip the NULL position with sort direction. The row is rewritten to say so.

Confidence: **verified**.

### 2. A subprocess with a reduced env and no `HOME` still writes the real home (`8f09bcb6c5d2c42a`, testing)

Claim: if a launched process writes or reads a file under the home directory by default, leaving `HOME` out of the test's subprocess env does not isolate it. Give every launcher/reader test helper a default override (the state-path variable or `HOME`) that points under the scratch directory.

Sources checked:
- https://docs.python.org/3/library/os.path.html — `expanduser`: "On Unix, an initial ~ is replaced by the environment variable HOME if it is set; otherwise the current user's home directory is looked up in the password directory through the built-in module pwd"
- https://nodejs.org/api/os.html — `os.homedir()`: "On POSIX, it uses the $HOME environment variable if defined. Otherwise it uses the effective UID to look up the user's home directory"

How it was verified: under `env -i PATH=/usr/bin:/bin`, Python 3.14.6 printed `False` for `"HOME" in os.environ` and still returned the account's real home directory. Node v26.7.0, run by absolute path, printed `true` for `process.env.HOME === undefined` and also returned the real home.

Session evidence: after the override default was added to both helpers, the real home state directory stayed empty across the full 4237-test suite.

Confidence: **verified**.

## Existing-layer check

Pages read: databases-schema-design-nullability-and-defaults, databases-query-optimization-keyset-pagination, testing-data-test-data-and-isolation, platforms-toolchains-uv-state-directories-under-a-relocated-home

Top `wiki_search` hits (k=5):
- Insight 1: nullability-and-defaults (0.773, sort-order edge case), keyset-pagination (0.770), backend-common-api-design-pagination-contract (0.768, cursor encoding only), databases-indexing-composite-index-column-order (0.763), frontend-rendering-long-lists (0.756, unrelated)
- Insight 2: infrastructure-agent-orchestration-verify-command-in-a-worker-brief (0.778, interpreter propagation, unrelated), testing-data-test-data-and-isolation (0.738, env-derived write path row), platforms-processes-background-services, infrastructure-config-path-valued-config

Overlap and decision per insight:
- **Insight 1 → merged into two pages (no new page).**
  - nullability-and-defaults already had a "Sort order with NULLs" edge case. It is rewritten (see the correction above), and one row is added for cross-implementation parity: the `(col IS NULL)` leading key, the Python present/missing split, and the both-directions test.
  - keyset-pagination had no row for a nullable sort key. An edge-case row is added: the cursor `(k_is_null, k, id)` and the branched predicate.
  - The two pages now link each other in `related:`.
  - No conflict: the existing "state `NULLS FIRST/LAST` explicitly" advice still stands. The new row covers the case where that syntax is missing or a non-SQL implementation must match.
- **Insight 2 → merged into testing-data-test-data-and-isolation.**
  - Its existing row "derives a write path from the environment … point that variable at a scratch dir" assumes the test sets the variable. The new case is the opposite: the test removes `HOME` and expects that to isolate. Added one directive row and one Instead-of row.
  - The page already lists the uv relocated-HOME page in `related:` (the reverse direction is already present), so no new link is needed.
  - No conflict.
- Adversarial review (fresh-context reviewer, read-only) found 5 defects, all fixed before commit: the DESC keyset walk needs both branches flipped (missing branch `id < :id`), the Python parity form now partitions records and reverses each part for DESC, "every major engine" / "several SQL backends" scoped to the three sourced engines, the HOME fallback scoped to POSIX, and an unsourced consequence in the Instead-of row softened. Both DESC and ASC keyset walks and the Python records form were re-run against the full SQL order on SQLite 3.51.0: all match.
- Prohibitions lint after the edits: `node scripts/wiki-lint-prohibitions.js wiki/` → `compliant: 79`, `violations: 0`.
- Body lines: nullability-and-defaults 49, keyset-pagination 42, test-data-and-isolation 88 (all ≤120).

## Open-PR check

Open `knowledge/*` heads listed: #223, #225, #226, #227, #228, #229, #230, #231, #233, #234, #235, #236. Each head was fetched and its `wiki/` diff searched for `nulls last/first`, `IS NULL)`, `keyset`, `expanduser`, `password database`, `getpw`, `HOME`.

- Insight 1: no open head adds anything on NULL ordering or keyset cursors. No open head touches `wiki/databases/`. Verdict: **new**.
- Insight 2: hits in #223/#227/#233/#234 were unchanged context lines or unrelated pages (redirection order, LLVM tool hiding, the uv index row). None covers HOME fallback in a reduced subprocess env. Verdict: **new**.
- Same-file check: #228 edits the `related:` line of test-data-and-isolation.md. This PR leaves that page's `related:` and `last_verified` lines untouched (the date bump was reverted for that reason), so the two hunks stay separated by unchanged lines. #223/#225/#226/#228/#234/#236 edit `wiki/testing/index.md`, but none changes the test-data-and-isolation row this PR extends.

## Routing decision

| Insight | Target | Action |
|---------|--------|--------|
| 1 nulls-last parity | databases/schema-design/nullability-and-defaults.md | Rewrote the sort-order edge case and added a parity row with 6 sources (4 docs, a local reproduction, field evidence). Bumped `last_verified` |
| 1 nullable keyset cursor | databases/query-optimization/keyset-pagination.md | Added an edge-case row and the SQLite rowvalue source. Bumped `last_verified` |
| 2 HOME fallback | testing/data/test-data-and-isolation.md | Added 1 directive row, 1 Instead-of row and 4 body sources |
| plumbing | wiki/databases/index.md, wiki/testing/index.md, log.md | Extended the load-when lines and added 3 ingest log entries |

No new category: both insights fit existing categories (schema-design / query-optimization / testing-data).

## Local-layer candidates

All 6 are linkly (`linkly-vendace`) planning gaps for task t207 (Text equality / RFC-0056). Each names linkly's own `lower.py`, `interp.py`, `spec.py`, Guard IR fields and RFC numbers, so it would be wrong in any other codebase. They are excluded from this PR and retired from the queue. To record them, run wiki-ingest inside that project.

- `2853f16e74fff5b5` → `wiki-local/backend/compiler/text-equality-pairing-at-lowering.md`
- `c7f4ab2f012d8942` → `wiki-local/backend/compiler/enum-literal-membership-did-you-mean.md`
- `5b443bc0f0792f3e` → `wiki-local/backend/compiler/mode-a-text-equality-evaluation.md`
- `f15c62da48b21f53` → `wiki-local/backend/compiler/spec-result-text-equality.md`
- `3bfcec36a4add6bf` → `wiki-local/backend/rfc-process/rfc-0056-chain-update-structure.md`
- `fb90baac661b611d` → `wiki-local/backend/compiler/text-equality-operator-coverage.md`
