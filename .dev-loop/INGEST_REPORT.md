# Knowledge flush — 3 insight(s)

Queue drained: `~/.dev-loop/queue/cd5970a5-…jsonl` (2 rows), `~/.dev-loop/queue/d5a117bb-…jsonl` (1 row).
All three came out of one investigation (Hibernate's application-level not-null check
and what it does to audit columns), so they route to two pages, not three.

## Verified best-practice

### I1 — attribute `PropertyValueException: not-null property references a null or transient value` by path shape, not by the word "transient"; and exclude `@PreUpdate` from cause and fix on the UPDATE path

**Claim.** Both throw sites share one hardcoded message literal, so the wording
carries no discriminating information; a dotted path means a composite
(`@Embeddable`) sub-attribute, a plain name means a top-level attribute. On UPDATE the
check runs before `EntityUpdateAction` exists, so no `@PreUpdate`/`@PostUpdate`
listener has run — a listener is neither a candidate cause nor a viable fix.

**Sources checked and how.**

- `Nullability.java` (5.6) fetched raw and read on disk: line 108-112 throws with
  `persister.getPropertyNames()[i]`; line 119-123 throws with
  `buildPropertyPath( persister.getPropertyNames()[i], breakProperties )`. Same literal
  both times. `checkSubElementsNullability` (line 143-167) enters
  `checkComponentNullability` only for `isComponentType()` (`CompositeType`) or a
  collection whose **element type** is composite — so dots have exactly two producers.
- Uniqueness of the literal: `gh api search/code 'q="not-null property references a
  null or transient value" repo:hibernate/hibernate-orm'` → 5 hits, of which
  **1 is production code** (`engine/internal/Nullability.java`); the other 4 are tests.
  So no other class emits this message.
- Ordering: `DefaultFlushEntityEventListener.scheduleUpdate` — source comment "check
  nullability but do not doAfterTransactionCompletion command execute" then
  `new Nullability( session ).checkNullability( values, persister, true )` (5.6 line
  320) immediately followed by `new EntityUpdateAction(...)` (line 325). Re-checked on
  branch **6.6** (253 → 258) and **7.0** (253 → 258) — same order in all three.
  `EntityUpdateAction.execute()` (line 170) calls `preUpdate()` (line 176), i.e. after
  the check.
- INSERT side: `AbstractEntityInsertAction.nullifyTransientReferencesIfNotAlready()`
  (6.6, lines 122-126) runs `nullifyTransientReferences( getState() )` and then
  `new Nullability( getSession() ).checkNullability( getState(), getPersister(), false )`
  — which is where "or transient" in the message comes from.
- Distinct exception for the genuine unsaved-instance case:
  `gh api search/code 'q="object references an unsaved transient instance"'` → 1
  production hit (`metamodel/mapping/EntityIdentifierMapping.java`), a different
  message.
- Counter-source read for the folklore this corrects:
  https://www.baeldung.com/hibernate-not-null-error attributes the same message to two
  causes ("null value for a column marked nullable = false" / "an association
  referencing an unsaved instance") and never mentions the path shape.

**Confidence: verified** (primary source read on three branches + reproducible
`gh api` code searches).

### I2 — Hibernate's core not-null check is silently off when Bean Validation is active and `hibernate.check_nullability` is unset; measure it instead of inferring it

**Sources checked.**

- https://docs.hibernate.org/orm/6.6/javadocs/org/hibernate/cfg/ValidationSettings.html
  — `CHECK_NULLABILITY`: "Enable nullability checking, raises an exception if an
  attribute marked as not null is null at runtime"; "Defaults to disabled if Bean
  Validation is present in the classpath and annotations are used, or enabled
  otherwise."
- `TypeSafeActivator.applyCallbackListeners`, read on disk for **5.6** (lines 114-115)
  and **6.6** (lines 116-117): guarded by `modes.contains( CALLBACK ) ||
  modes.contains( AUTO )`, then, under the comment "de-activate not-null tracking at
  the core level when Bean Validation is present unless the user explicitly asks for
  it", `if ( cfgService.getSettings().get( CHECK_NULLABILITY ) == null )
  … setCheckNullability( false )`. So the toggle is driven by a classpath/dependency
  change, exactly as the candidate claimed.
- `Nullability` line 69-73 corroborates in-source: "Typically when Bean Validation is
  on, we don't want to validate null values at the Hibernate Core level. Hence the
  checkNullability setting."
- Measurement API existence checked before writing it into a directive:
  `SessionFactoryImplementor.getSessionFactoryOptions()` (javadoc: "Get the options
  used to build this factory") and `SessionFactoryOptions.isCheckNullability()`
  (`boolean isCheckNullability()`).
- Skip conditions written into directive 4 read from `Nullability` lines 92-104
  (`getPropertyInsertability`/`getPropertyUpdateability`, `UNFETCHED_PROPERTY`,
  `GenerationTiming.NEVER`); that `@UpdateTimestamp` is in-memory generated was
  confirmed via `UpdateTimestamp.java` (`@ValueGenerationType(generatedBy =
  UpdateTimestampGeneration.class)`) → `UpdateTimestampGeneration.getGenerationTiming()
  == GenerationTiming.ALWAYS` with a non-null `getValueGenerator()`.
- Enforcement-layer claim cross-read at
  https://thorben-janssen.com/hibernate-tips-whats-the-difference-between-column-nullable-false-and-notnull/
  — `@Column(nullable = false)` "adds a not null constraint to the database column, if
  Hibernate creates the database table definition"; `@NotNull` is what Bean Validation
  checks on pre-update/pre-persist. This is also why that article describes Hibernate
  "just executing the SQL UPDATE" — it describes the Bean-Validation-present default,
  i.e. the check switched off.

**Confidence: verified.**

### I3 — an audit column is evidence only about the writer that sets it, so all-NULL `update_dt` cannot separate "never updated" from "every update failed"

**Sources checked.**

- Spring Data JPA `AuditingEntityListener` read on disk: `touchForCreate` is
  `@PrePersist` (line 84-85), `touchForUpdate` is `@PreUpdate` (line 104-105) — so
  `@LastModifiedDate` is written by a JPA lifecycle callback and inherits the ordering
  established in I1.
- Bulk-DML claim taken from the primary Hibernate guide
  (https://docs.hibernate.org/orm/6.6/querylanguage/html_single/Hibernate_Query_Language.html):
  "The effect of an `update` or `delete` statement is not reflected in the persistence
  context, nor in the state of entity objects held in memory at the time the statement
  is executed"; `@Version` is untouched unless the statement is `versioned`. I looked
  for a primary statement that callbacks specifically are not invoked and did **not**
  find one in the 6.6 user guide, the 6.6 query-language guide, or the Jakarta
  Persistence 3.1 spec page (§4.10's body was not in the served content). The page
  therefore states the doc-backed fact (no persistence-context effect → no flush action
  → no callback) and does not assert a spec quotation it cannot cite.
- Trigger axis: https://www.postgresql.org/docs/current/sql-createtrigger.html — "A
  trigger that is marked `FOR EACH ROW` is called once for every row that the operation
  modifies." The doc states per-row firing; client-independence is the structural
  consequence of the trigger living on the relation, and the page words it that way
  rather than quoting the doc for it.
- Field evidence carried over from the session: PRD `manage.building_tenant_floor_info`
  — 574 rows with a NULL business code, all with `update_dt` NULL, whose UPDATEs were
  dying in `Nullability` before `EntityUpdateAction` was created.

**Confidence: verified** for the mechanism (callback ordering, `@PreUpdate` writer,
bulk-DML persistence-context semantics); the production observation that motivated it
is labelled as a field observation in the page's Sources.

## Existing-layer check

Routed via `INDEX.md` → `backend` (application-code concern, JVM subtree) and
`databases` (reading live rows to derive a claim), then read each domain index and
every page whose "load when" overlapped.

Pages read: backend-java-jpa-entity-mapping, backend-java-jpa-persistence-context, backend-java-kotlin-frameworks-and-jpa, databases-schema-design-nullability-and-defaults, databases-data-survey-surveying-live-data-for-a-rule, databases-schema-design-soft-delete

Also read (non-page routing/schema files): `INDEX.md`, `wiki/backend/index.md`,
`wiki/backend/java/index.md`, `wiki/databases/index.md`, `wiki/debugging/index.md`,
`AGENTS.md`, `templates/page.md`.

**Overlaps and what I did.**

| Existing page | Overlap | Decision |
|---------------|---------|----------|
| `backend-java-jpa-persistence-context` | Owns flush timing and dirty checking — the *when does flush happen* question. Says nothing about the validation that runs inside `scheduleUpdate` or about callback ordering | No duplication; new page links it and stays off flush-timing |
| `backend-java-kotlin-frameworks-and-jpa` | Rule 3 covers "Kotlin non-null property vs nullable column"; rule 5 covers `@field:NotNull` targets | Closest existing coverage, but it is a Kotlin *class-shape* page, not a runtime-enforcement page. Kept separate; the new page defers the `@field:` target to it by id rather than restating it |
| `databases-schema-design-nullability-and-defaults` | Column-side NOT NULL/defaults design | Complementary axis (declaring vs interpreting/enforcing); linked from both new pages |
| `databases-data-survey-surveying-live-data-for-a-rule` | Same category and the same failure family ("a survey result read as more than it is"), but its subject is deriving mapping/enum/normalization rules and the empty-result substitution | Not a merge: adding an audit-column directive would contradict its own "When this applies". New sibling page in the same category, one-way link to it |
| `debugging/signals/reading-error-messages` (index line only) | Generic error-reading methodology | Left alone — the insight is stack-specific mechanics, which AGENTS.md routes to the owning domain |

**Conflicts flagged.** None. No existing directive says the opposite of anything
ingested here.

**Related links added.** New JPA page → `backend-java-jpa-persistence-context`,
`backend-java-kotlin-frameworks-and-jpa`,
`databases-schema-design-nullability-and-defaults`,
`databases-data-survey-audit-columns-as-update-evidence`. New data-survey page →
`databases-data-survey-surveying-live-data-for-a-rule`,
`databases-schema-design-nullability-and-defaults`,
`backend-java-jpa-not-null-check-and-lifecycle-callbacks`. Inline id references also
made to `databases-schema-design-soft-delete`. Back-links into
`surveying-live-data-for-a-rule.md` were deliberately **not** added: PR #78 edits that
file's `related:` line, and a one-way link satisfies invariant 4 without contending
for the same line.

## Open-PR check

Listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`
→ 23 open heads: #86, #80, #79, #78, #76, #74, #73, #72, #69, #68, #66, #64, #62, #61,
#58, #57, #56, #55, #52, #51, #50, #49, #47.

Per-head `wiki/**` file lists pulled with `gh pr view <n> --json files` (the heads are
cross-repo forks — `git fetch origin <head>` fails with "couldn't find remote ref", so
`gh pr diff` was used for content). Heads touching the two categories I ingest into:

| Head | Files in my categories | Content overlap? |
|------|------------------------|------------------|
| #73 | `wiki/backend/java/jpa/raw-jdbc-inside-a-jpa-transaction.md`, `wiki/backend/java/index.md` | **No.** Subject is a raw JDBC connection used inside a JPA transaction. Same category and same index file, different case |
| #78 | `wiki/databases/data-survey/catalog-statistics-as-current-state.md`, `surveying-live-data-for-a-rule.md`, `wiki/databases/index.md` | **No.** Diffed in full: its subject is catalog estimates (`relpages`/`reltuples`/`pg_stats`) being stale relative to the heap — a staleness-of-statistics case, not a writer-coverage case. Family resemblance only |
| #74 | `wiki/databases/index.md` (+ query-optimization pages) | No — index row only |

Verdicts: **I1 → new**, **I2 → new** (both into one page, same mechanism/one case per
AGENTS.md rule 1), **I3 → new**. Nothing folded, nothing dropped.

**Contention to expect at merge (not duplication):** three additive index rows —
`wiki/backend/java/index.md` (also touched by #73) and `wiki/databases/index.md` (also
touched by #74 and #78). Each is a one-row table append; resolve by keeping both rows.
`wiki/backend/index.md` was intentionally not modified (it routes to the subtree index
only), which keeps this PR off the file that #76/#72/#68/#58/#55/#51 all edit.

I3 does **not** link `databases-data-survey-catalog-statistics-as-current-state`
(#78's new page) even though the pairing would be apt: that id does not exist on `main`
yet, and invariant 4 would break if #78 is rejected. Worth adding as a `related:` on
whichever of the two merges second.

## Routing decision

| Insight | Target | New category? |
|---------|--------|---------------|
| I1 + I2 | `backend/java/jpa/not-null-check-and-lifecycle-callbacks.md` (id `backend-java-jpa-not-null-check-and-lifecycle-callbacks`), **new page** in the existing `jpa` category | No — `backend/java/jpa` already exists and holds entity-mapping/persistence-context |
| I3 | `databases/data-survey/audit-columns-as-update-evidence.md` (id `databases-data-survey-audit-columns-as-update-evidence`), **new page** in the existing `data-survey` category | No — `data-survey` exists (created for `surveying-live-data-for-a-rule`) and its remit is exactly "reading live data as evidence" |

**Why I1 and I2 share one page.** They are the same mechanism seen from two sides: the
exception thrown by `Nullability` (I1) and whether `Nullability` runs at all (I2). Both
are answered from the same source lines, and a reader arriving with either question
needs the other half — splitting them would produce two pages whose "load when" lines
each pull in the other.

**Why I3 is not on the JPA page.** Its situation is "I am looking at production rows
and about to state a behavioural conclusion" — a survey, reached from the `databases`
domain, and true for any callback-written audit column (not only Hibernate's). The JPA
page owns the ORM mechanism; the data-survey page owns the evidential rule and links to
it.

**Domain hints honoured.** Queue hints were `backend` (I1, I2) and `databases` (I3);
both matched the routing that `INDEX.md` produced independently.

Sizes: 91 and 73 body lines (limit 120). Both pages carry `confidence: verified` and
`last_verified: 2026-08-13`.

**Citation ledger** (12 distinct URLs across the two pages, so the reviewer can spot a
gap rather than trust a blanket claim):

| URL | How it was opened this session |
|-----|-------------------------------|
| hibernate-orm `engine/internal/Nullability.java` (5.6) | raw fetch → read on disk (226 lines) |
| hibernate-orm `event/internal/DefaultFlushEntityEventListener.java` (6.6) | raw fetch of 5.6 read on disk; 6.6 and 7.0 fetched and grepped for the two call sites |
| hibernate-orm `action/internal/AbstractEntityInsertAction.java` (6.6) | raw fetch → grepped call site |
| hibernate-orm `boot/beanvalidation/TypeSafeActivator.java` (6.6) | raw fetch → read lines 95-125; 5.6 equivalent also fetched |
| `ValidationSettings` javadoc (6.6) | WebFetch (quote extracted) |
| `SessionFactoryOptions` javadoc (6.6) | WebFetch (signature confirmed) |
| Hibernate Query Language guide (6.6) | WebFetch (mutation-statement quote extracted) |
| spring-data-jpa `AuditingEntityListener.java` | raw fetch → grepped annotations |
| `thorben-janssen.com` @Column vs @NotNull | WebFetch (quotes extracted) |
| `baeldung.com/hibernate-not-null-error` | WebFetch (used as the counter-source) |
| PostgreSQL `CREATE TRIGGER` | WebFetch (FOR EACH ROW quote extracted) |
| — | Each of the blob/javadoc/guide URLs *as written in the frontmatter* additionally
  re-checked with `curl -o /dev/null -w '%{http_code}' -L` → 200 (9 of them; the two
  WebFetch-only pages above were opened by WebFetch, not curl) |

Two things this flush did **not** establish, stated so a later revise can close them:
a primary-source quotation that bulk JPQL skips lifecycle callbacks specifically (the
Jakarta Persistence §4.10 body was not in the served spec page), and the Hibernate 7.x
equivalent of `TypeSafeActivator` (checked on 5.6 and 6.6 only; the flush-order check
did cover 7.0).

## Decision Log

- **Intent.** Drain 3 queued `★ Insight` candidates from one investigation into the
  wiki as a single reviewed PR: 2 new pages, no merges into existing pages, no
  candidate dropped.
- **Chose** one page for I1+I2 (`backend/java/jpa/not-null-check-and-lifecycle-callbacks`)
  because both answer from the same `Nullability` source lines and either question
  needs the other's answer. **Rejected** splitting them into an "error attribution"
  page and a "configuration" page — their "load when" lines would each pull in the
  other, which AGENTS.md rule 1 exists to prevent.
- **Chose** `databases/data-survey` for I3. **Rejected** merging it into
  `surveying-live-data-for-a-rule` (its "When this applies" is scoped to deriving
  mapping/normalization/enum rules — an audit-column directive would contradict its own
  trigger) and **rejected** putting it on the JPA page (the evidential rule holds for
  any callback-written audit column, not only Hibernate's).
- **Rejected** adding a back-link inside `surveying-live-data-for-a-rule.md`: open PR
  #78 edits that file's `related:` line, and invariant 4 is satisfied by the one-way
  link from the new page.
- **Rejected** linking `databases-data-survey-catalog-statistics-as-current-state`
  (apt, but it exists only on #78's head — a broken id if #78 is rejected).
- **Left out on purpose:** no edit to `wiki/backend/index.md` (it routes to the subtree
  index only), which keeps this PR off the file six open PRs already touch.
- **Downgraded one claim rather than sourcing it loosely:** the candidate asserted bulk
  JPQL "skips callbacks". The page states the doc-backed persistence-context fact and
  the mechanism it implies; the callbacks-specifically quotation is listed above as not
  established from a primary source.
- **Cross-Check:** no independent adversarial reviewer was run — subagent/CLI
  delegation was outside this invocation's scope. What *was* done, first-hand this
  session: Hibernate sources read on disk for 5.6/6.6/7.0 (flush-order verified on all
  three), `gh api search/code` used to prove the message literal has exactly one
  production occurrence, every frontmatter URL opened (ledger above, 9 additionally
  re-checked for HTTP 200), all 8 `related:`/inline ids resolved against `wiki/` by
  script, both pages measured under the 120-line limit, and the flush gate's own
  `Pages read:` resolution reproduced locally. Treat the two "not established" items
  above as the known gaps.
