# Knowledge flush — 3 insight(s)

Queue drained: `1717316a-…jsonl` (1 row), `ab5516dc-…jsonl` (2 rows). All three
ingested as new pages; none dropped.

## Verified best-practice

### 1. A spy that captures one argument leaves the same call's siblings unasserted

**Claim.** When a review flags one argument of one wiring call and you hold the fix
with a spy, record the whole call and assert every caller-decided argument;
asserting the constant's value is a different claim from asserting that the call
site passes it on, and extracting a resolver moves that gap up a layer.

**Sources checked.**

- https://docs.python.org/3/library/unittest.mock.html — `assert_called_with` is
  "a convenient way of asserting that the last call has been made in a particular
  way" (whole-call, last-call only); a *spec*'d mock "will introspect the
  specification object's signature when matching calls … regardless of whether
  they were passed positionally or by name", and "using autospec will catch
  mistakes where the mock is called with the wrong signature".
- https://jestjs.io/docs/expect — `.toHaveBeenCalledWith` checks arguments "with
  the same algorithm that `.toEqual` uses"; `expect.objectContaining` matches "a
  received object which contains properties that are present in the expected
  object" — a **subset** match, which is why omitted keys stay unasserted (this
  became an edge-case row rather than a recommendation).
- https://github.com/mockito/mockito/blob/main/mockito-core/src/main/java/org/mockito/ArgumentMatchers.java
  — "If you are using argument matchers, **all arguments** have to be provided by
  matchers."
- https://pitest.org/quickstart/basic_concepts/ — "'Survived' means the mutation
  was not detected by the covering test" (how step 5 reads a green per-argument run).

**How verified.** Reproduced both halves locally this session (Python 3,
`unittest.mock`), not just cited:

| Run | Correct call | Mutated call |
|---|---|---|
| partial-capture stub (stores only `kw["port"]`) | passes | **passes** — `host` `0.0.0.0`→`127.0.0.1` undetected |
| `Mock(spec=…)` + `assert_called_with(host=…, port=…, tls=…)` | passes | fails |

The green cell on the correct call is the no-op control: the stronger assertion
discriminates rather than always failing. A second run held
`DEFAULT_PORT == 8914` green across three call-site variants (reads the constant,
reads an extracted `resolve_port()`, hardcodes `8770`) while the recorded-call
assertion was green for the first two and red only for the hardcoded one — the
"value vs wiring" split, and the evidence that the wiring assertion survives the
refactor.

**Confidence: verified** (official docs for every API claim + local reproduction).
The field evidence behind the candidate (a 6-round audit where `port`, then the
extracted resolver, then `host` each survived in turn, the last being a change
whose only failure surface is a Kubernetes readiness probe) is recorded in the
page's Sources as a field measurement, kept distinct from the reproduction.

### 2. pg_trgm degenerates to a full-index scan below three characters

**Claim.** A `LIKE`/`ILIKE` wildcard segment of fewer than three characters yields
no extractable trigrams, so a pg_trgm GIN/GiST index is scanned in full and the
cost moves into the heap recheck — while the plan still reads `Bitmap Index Scan`.

**Sources checked.**

- https://www.postgresql.org/docs/current/pgtrgm.html — "For both `LIKE` and
  regular-expression searches, keep in mind that a pattern with no extractable
  trigrams will degenerate to a full-index scan." Also the padding rule ("Each
  word is considered to have two spaces prefixed and one space suffixed…"), which
  I checked precisely because it is a trap: `show_trgm('cat')` returns four
  trigrams, so "short strings have no trigrams" is **wrong** as stated — padding
  applies to a *word being indexed*, while a `%…%` pattern asserts no word
  boundary to pad against. The page states it that way.
- https://postgrespro.com/list/thread-id/1821635 — Amit Langote, pgsql list
  (2013-05-31): "get_wildcard_trigrams return no trigrams for wildcard part 'st'
  since charlen < 3"; "Hence, GIN_SEARCH_MODE_ALL mode is used and results in full
  index scan instead of trigrams being used." This is what lets the page state the
  rule per wildcard-delimited segment rather than per pattern.
- https://github.com/pgbigm/pg_bigm/blob/master/docs/pg_bigm_en.md — 2-gram index;
  its comparison table rates 1–2 character keyword search "Fast" vs pg_trgm's
  "slow", **and** lists pg_bigm's operators as "LIKE only" vs pg_trgm's "LIKE
  (~~), ILIKE (~~*), ~, ~*". That constraint corrects the candidate, which
  suggested pg_bigm without noting it is not a drop-in for an `ILIKE` workload;
  the page splits those into two decision rows.

**How verified.** Doc quotes fetched and read this session. The quantitative half
is the candidate's own field `EXPLAIN (ANALYZE, BUFFERS)` on a 4.64M-row table
(3-char 17 ms / 4 buffers vs 2-char 18,789 ms / 121,837 buffers,
`Rows Removed by Index Recheck: 4,640,486`, 3 rows matched) — **not** re-run here:
no PostgreSQL was reachable in this environment (`psql` absent, Docker daemon
down, no postgres pod in the local cluster). It is labelled a field measurement
with its date and table size, and no claim in the page depends on my having
re-run it.

**Confidence: verified** (mechanism doc-sourced; magnitude field-measured).

### 3. `@Transactional(timeout=N)` does not reach a raw JdbcTemplate path by itself

**Claim.** The declared timeout reaches `JdbcTemplate` only through a
`ConnectionHolder` bound by `JpaTransactionManager`; when that bind is skipped the
raw path runs unbounded, and the two paths raise **different** Spring exceptions.

**Sources checked (source read at pinned tags, not from memory).**

- `JpaTransactionManager` javadoc — "To be able to register a DataSource's
  Connection for plain JDBC code, this instance needs to be aware of the
  DataSource (`setDataSource(DataSource)`)"; "will autodetect the DataSource used
  as the connection factory of the EntityManagerFactory, so you usually don't need
  to explicitly specify the 'dataSource' property"; "this requires a
  vendor-specific `JpaDialect` to be configured".
- `JpaTransactionManager.java` @ v6.2.0 — `conHolder.setTimeoutInSeconds(...)`
  sits inside `if (getDataSource() != null)` **and** requires
  `getJpaDialect().getJdbcConnection(em, …) != null`, else it logs "Not exposing
  JPA transaction … does not support JDBC Connection retrieval".
  `DefaultJpaDialect.getJdbcConnection` returns `null`. This is a **correction**:
  the candidate named only the DataSource wiring, so a Boot app (where the
  DataSource is autodetected) would have looked exempt; the dialect branch and the
  DataSource-instance-identity branch are separate failure modes, and the debug
  log line is a checkable diagnostic. The page's step 2 is a 4-row table because
  of this.
- `DataSourceUtils` javadoc + `DataSourceUtils.java` @ v6.2.0 — `applyTimeout`
  applies "the current transaction timeout, **if any**"; it looks the holder up by
  the `DataSource` instance and otherwise falls back to the passed timeout only
  `if (timeout >= 0)`. `JdbcTemplate.applyStatementSettings` calls it with
  `getQueryTimeout()`, whose field default is `private int queryTimeout = -1` —
  so with no holder, nothing is set at all.
- Exception split: Hibernate `PostgreSQLDialect.java` maps SQLState `"57014"` →
  `org.hibernate.QueryTimeoutException`, and `HibernateJpaDialect.java` @ v6.2.0
  converts that to `org.springframework.dao.QueryTimeoutException`. On the raw
  path, PgJDBC's `PSQLException extends SQLException` with
  `PSQLState.QUERY_CANCELED = "57014"`, so `SQLExceptionSubclassTranslator`'s
  `instanceof SQLTimeoutException` branch misses and its
  `SQLStateSQLExceptionTranslator` fallback maps class `57`
  (`Set.of("08","53","54","57","58")`) → `DataAccessResourceFailureException`.
- **Version boundary found while verifying, which the candidate did not know.**
  `main` special-cases `"57014".equals(sqlState)` → `QueryTimeoutException`. I
  fetched the file at seven released tags to find where it starts:

| Tag | `"57014".equals` present |
|---|---|
| v5.3.31, v6.0.0, v6.2.0, v6.2.1, v6.2.3, v6.2.5, v6.2.8 | no |
| v7.0.0, `main` | yes |

So the candidate's exception claim is correct for Spring Framework ≤ 6.2.x and
inverts at 7.0.0. The page states both, and an `Instead of` row requires pinning
the framework version any single-branch handler assumes.

**How verified.** Every quote above was fetched this session; the version table
came from downloading the same file at each tag and grepping it. The timing half
(Hibernate cancelled at 10,012 ms → 400 vs raw JdbcTemplate 151,558 ms /
163,489 ms → 500 on one annotated endpoint, 11/11 errors over 30 days matching the
per-path status split) is the candidate's production p6spy measurement, labelled as
such.

**Confidence: verified** (framework behaviour read from pinned source + javadoc;
production magnitudes field-measured).

## Existing-layer check

Routed via `INDEX.md` → the three domain indexes, then read every page whose "load
when" line overlapped. Full-body reads: `testing-quality-tests-that-cannot-fail`,
`testing-mocking-what-to-mock`, `databases-indexing-index-selection`. Targeted
reads (grep for timeout/JdbcTemplate/trigram/LIKE/arg-capture terms, to establish
absence of coverage): the remaining ids below.

Pages read: testing-quality-tests-that-cannot-fail, testing-mocking-what-to-mock, testing-quality-behavior-not-implementation, backend-common-change-impact-call-site-enumeration, databases-indexing-index-selection, databases-query-optimization-reading-execution-plans, databases-indexing-partial-and-expression-indexes, databases-indexing-covering-indexes, backend-common-orm-transaction-boundaries, backend-common-reliability-timeouts-and-retries, backend-common-errors-exception-handling, backend-java-jpa-persistence-context, backend-java-spring-proxy-pitfalls

**Overlaps found, and why each is composition rather than duplication.**

| Existing page | Overlap | Resolution |
|---|---|---|
| `testing-mocking-what-to-mock` | Its step 1 last row and step 2 already say to "assert the **outbound contract**: which command, with what arguments", and one edge row says to "deep-equal the full stub-recorded call sequence" | Closest neighbour, but its subject is *whether* to replace a dependency — folding assertion-completeness in would break "one case per page". Kept separate; added the new id to its `related:` and a pointer on the outbound-contract row |
| `testing-quality-tests-that-cannot-fail` | Owns per-assertion mutation granularity and the "testing the mock instead of the code" row | The new page cites it for the mutation step instead of restating it; added the new id to its `related:` |
| `databases-indexing-index-selection` | Line 51 routes `LIKE '%term%'` to "a trigram or full-text index type" | That advice has an unstated precondition — exactly the new page. Extended the row to carry the minimum-keyword-length pointer, plus a `related:` link |
| `databases-query-optimization-reading-execution-plans` | Owns plan reading generally | Cited from "When this applies"; the new page adds only the trigram-specific counter to read (`Rows Removed by Index Recheck`) |
| `backend-common-reliability-timeouts-and-retries` | One row: "Dependency is a DB with its own driver timeout — set both the driver statement timeout and your outer deadline" | Consistent, and the new page is the Spring-specific mechanism for why the driver timeout is silently absent. Reciprocal `related:` added |
| `backend-common-orm-transaction-boundaries` | Transaction scope; no timeout content (grep: only an external-API-in-transaction row) | Reciprocal `related:` added |
| `backend-java-spring-proxy-pitfalls` | Owns "the annotation had no effect at all" | Cited as the upstream check in step 2's table, so the two failure modes stay distinguishable |
| `backend-java-jpa-persistence-context`, `backend-common-errors-exception-handling`, `databases-indexing-partial-and-expression-indexes`, `databases-indexing-covering-indexes` | No overlapping directive | Linked where relevant (case-folded expression index; exception handling) |

**Conflicts flagged:** none. No existing page states a contradicting directive.

**Coverage gaps confirmed by grep before creating:** `trgm|trigram|ILIKE` matches
exactly one file in the whole wiki (`index-selection.md`, the one row above);
`call_args|assert_called_with|toHaveBeenCalledWith|argument captor` matches exactly
one (`what-to-mock.md`); no page mentions `statement_timeout`, `JdbcTemplate`, or
`QueryTimeout`.

**Format invariants checked mechanically after writing:** body lines 94 / 75 / 90
(limit 120); every `related:` id and inline `[page-id]` reference resolves to a
page in this checkout (16/16); no banned vague qualifier in any directive (the two
`usually`/`Consider` hits were a verbatim Spring javadoc quote in Sources, left
intact, and one `Instead of` anti-pattern label, reworded); every prohibition word
occurs only inside an `Instead of` row or a quoted source.

## Open-PR check

Listed all 17 open `knowledge/*` heads. Three of them (**#72, #52, #49**) produced
suspiciously **empty** `wiki/` diffs on a first pass, because `git fetch origin
<branch>` and `repos/choiyounggi/dev-loop/git/refs/heads/<branch>` both 404 for
them. Rather than read an empty diff as "no overlap", I re-read all three through
`refs/pull/<n>/head`, and then established the actual cause: those heads live on
the contributor fork `dch0202-rsquare/dev-loop` (this flush's own account), not on
upstream — all three refs resolve there (`6a3ff08`, `bd03fbe`, `346dd95`). They are
alive and pushable, so `fold` was a genuinely available verdict for them; it was
not taken for the content reasons below. This PR is likewise opened from the fork.

Files touched by each open head, matched against the three candidates:

| Candidate | Overlapping open PRs | Verdict |
|---|---|---|
| 1 — captured call arguments (testing/mocking) | #52 adds `testing/quality/source-text-wiring-assertions.md`; #49 adds `testing/quality/value-preserving-refactor-assertions.md` + `unasserted-return-fields.md`; #47/#52 modify `tests-that-cannot-fail.md` | **new** |
| 2 — pg_trgm short patterns (databases/indexing) | none — zero open heads touch `wiki/databases/**` | **new** |
| 3 — raw JDBC in a JPA transaction (backend/java/jpa) | none — the backend-touching heads (#68, #58, #56, #55, #51, #50, #72) are all under `backend/common/**` or `backend/python/**`; zero touch `wiki/backend/java/**` | **new** |

**Why candidate 1 is `new` and not `fold`**, having read all three in-flight pages
in full or in relevant part:

- `#52 source-text-wiring-assertions` — same *word* "wiring", different subject: it
  is about asserting by **regex over source text** when no seam exists (anchor
  uniqueness, comment stripping, bound sizing). The new page is about the case
  where a seam **does** exist and a recorder captured the call. Its own "Instead
  of" even routes away from text guards when the behaviour is reachable, which is
  the situation the new page occupies. No directive is duplicated.
- `#49 value-preserving-refactor-assertions` — nearest in spirit (a literal
  replaced by a config read; sentinel substitution to prove the dependency). Its
  trigger is a *value-preserving refactor of a source of truth*; the new page's is
  *a reviewed fix to one argument of one call*, and its distinct content is
  argument-set completeness across one call — the thing #49 does not address.
- `#49 unasserted-return-fields` — the mirror direction (fields a function
  **returns** that no assertion reads). The new page is the call/argument
  direction. Deliberately kept as siblings.

No candidate is a pending duplicate, so nothing was dropped and no sibling
duplicate PR is opened here.

**Merge-order note for the owner:** this branch adds one id to
`wiki/testing/quality/tests-that-cannot-fail.md`'s `related:` list, a file #47 and
#52 also modify. It is a single-line frontmatter addition. If any of #47/#49/#52
merge first, the reciprocal links to `testing-quality-source-text-wiring-assertions`,
`-value-preserving-refactor-assertions` and `-unasserted-return-fields` become
resolvable and are worth adding to the new page then — they are intentionally
omitted now because AGENTS.md invariant 4 requires every `related:` id to resolve,
and those pages do not exist on `main`.

## Routing decision

| Insight | Domain / category | Page | New category? |
|---|---|---|---|
| 1 | `testing` / `mocking` | `wiki/testing/mocking/captured-call-arguments.md` (`testing-mocking-captured-call-arguments`) | No — `mocking` is the category that owns stub/spy mechanics; `quality` owns whether a test can fail (already cited), and the subject here is what the double records |
| 2 | `databases` / `indexing` | `wiki/databases/indexing/trigram-index-short-patterns.md` (`databases-indexing-trigram-index-short-patterns`) | No — `indexing` owns index-type suitability; the case is a precondition on one index type, and `query-optimization/reading-execution-plans` stays the owner of plan reading |
| 3 | `backend` / `java` → `jpa` | `wiki/backend/java/jpa/raw-jdbc-inside-a-jpa-transaction.md` (`backend-java-jpa-raw-jdbc-inside-a-jpa-transaction`) | No — the mechanism is `JpaTransactionManager`/`JpaDialect`, so it belongs in the `jpa` category rather than `spring` (which owns proxy-level "the annotation did nothing") or `backend/common` (language-agnostic principles; this is stack-specific source behaviour) |

Plumbing updated: `wiki/testing/index.md`, `wiki/databases/index.md`,
`wiki/backend/java/index.md` each +1 "load when" row; `log.md` +1 ingest entry.
`INDEX.md` unchanged — all three domains are already listed and their "route here
when" lines already cover these cases.
