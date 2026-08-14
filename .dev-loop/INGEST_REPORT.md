# Knowledge flush — 3 insight(s)

Queue drained: `~/.dev-loop/queue/3591e35e-…jsonl` (2 rows), `d20b3451-…jsonl` (1 row).

A prior flush run had died after writing three draft pages but before committing —
they were present as **untracked** files in the checkout, with the queue rows still
`pending` and no `INGEST_REPORT.md`. The drafts were treated as unaudited input, not
as output: every citation was re-opened and every measurement re-run. Three defects
were found and fixed (two mis-quotations and one wrong mechanism, below).

## Verified best-practice

### 1. A plan naming "the N call sites" can name sites in two aggregation layers

**Claim.** Before adopting a plan that unifies "the N call sites" of a helper named
by line number, open each and record which layer owns the reduction — a per-row SQL
projection feeding an in-language reduce greps identically to a set-level SQL
aggregate — then check whether the plan's grep-count acceptance criterion is
reachable on the route you take.

**Sources checked.**

- https://www.postgresql.org/docs/current/functions-aggregate.html — `sum` "Computes
  the sum of the non-null input values"; "except for `count`, these functions return
  a null value when no rows are selected. In particular, `sum` of no rows returns
  null, not zero as one might expect".
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/reduce
  — "if `initialValue` is provided but the array is empty, the solo value will be
  returned without calling `callbackFn`"; `TypeError` "Thrown if the array contains
  no elements and `initialValue` is not provided".
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html — `-c` "Write
  only a count of selected lines to standard output".

**How verified.** Measured on PostgreSQL **16.14** and **17.11** (both Docker):
`sum` over all-NULL → `NULL`, over zero rows → `NULL`, over `[5, NULL]` → `5`.
Node **v24.8.0**: seeded reduce → `0` on all-missing and empty; filter-then-reduce →
`null`; `[].reduce(f)` → `TypeError`. Field side re-verified in the live worktree:
`sumVacancyAreaStrict` (empty → null, any null → null) single-owns the rule, the sort
SQL is its declared mirror (`CASE WHEN bool_or(v IS NULL) THEN NULL ELSE SUM(v) END`),
all three consumers are asserted to agree by `building-vacancy-path-parity.test.ts`
(**15 tests passing**), and `sumCounts` was deliberately retained for the
parking-count axis.

**Two corrections to the draft.** (a) It quoted "All these functions ignore null
values in their aggregated input" as a statement about `sum`; extracting the page
text shows that sentence belongs to **Table 9.64, the ordered-set aggregates**
(`mode`, `percentile_cont`) — replaced with `sum`'s own wording. (b) The MDN
sentence was a **paraphrase presented as a verbatim quote** — replaced with the real
one. Also added the strict column to the boundary table: the draft's table only
diverged at empty/all-missing, but `[5, null]` is the dangerous row — three of four
routes return a **partial sum that reads downstream as a measured total**.

**Confidence: verified.**

### 2. Locking a missing-value property in generated SQL — defenses are position-partitioned

**Claim (as corrected).** Refills that defeat the property split by **position**, and
the assertion families are **disjoint**: top-level start/end anchors own a wrapper
placed _outside_ the rendered expression; a function-name check owns named inner
wrappers; an occurrence count on the aggregate owns the nameless inner `CASE` refill;
a literal `THEN NULL` owns a guard rewritten to yield `0`; a captured-alias binding
owns dead-column swaps. Build the coverage matrix and run rename + reflow controls.

**Sources checked.**

- https://www.postgresql.org/docs/current/functions-conditional.html — GREATEST/LEAST
  "NULL values in the argument list are ignored. The result will be NULL only if all
  the expressions evaluate to NULL. (This is a deviation from the SQL standard…)".
- https://dev.mysql.com/doc/refman/8.4/en/comparison-operators.html — "`GREATEST()`
  returns `NULL` if any argument is `NULL`" (the engine divergence, sourced on both
  sides).
- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ —
  opened and enumerated: **sixteen** mutator groups, all replacing or removing nodes
  ("This mutant operator removes the content of every block statement"). Expression
  _wrapping_ is absent, so this mutant class is necessarily hand-seeded. Stated as a
  closed-catalogue absence rather than a bare "no tool does this".
- https://www.postgresql.org/docs/current/functions-aggregate.html (as above).

**How verified — this refutes the draft's central claim.** The draft asserted that
after adding start/end anchors, the `GREATEST` and nameless-`CASE` refills "both
died… the refill caught by the anchor alone". I extracted the **real rendered
`ORDER BY` key** from rtb-unified `buildingListOrderBy('vacancyArea')` via `PgDialect`
and ran six assertion families against six seeded mutants plus two
behaviour-preserving controls (Node v24.8.0):

| Mutant                         | killed by                     | anchors saw it? |
| ------------------------------ | ----------------------------- | --------------- |
| `COALESCE(<whole key>, 0)`     | start+end anchors, alias bind | yes             |
| `COALESCE(SUM(x),0)` (inner)   | name check **only**           | **no**          |
| `GREATEST(SUM(x),0)` (inner)   | name check **only**           | **no**          |
| guard yields `0` (nameless)    | literal `THEN NULL` **only**  | **no**          |
| inner `CASE` refill (nameless) | aggregate-occurrence **only** | **no**          |
| dead column (`0 AS z`)         | captured-alias bind **only**  | **no**          |
| control: alias rename `s`→`x`  | — (green, correct)            | —               |
| control: whitespace reflow     | — (green, correct)            | —               |

So each mutant dies to **exactly one** family, both controls stay green across all
six, and top-level anchors are **blind by construction** to any inner-position
refill. Shipping the draft's guidance ("anchors primary, denylist secondary/
redundant") would have licensed dropping the family that is the only defense for two
of the mutants. I also confirmed the gap is live in the shipped repo test: its
single-evaluation fingerprint counts `total_vacancy_area_sqm`/`block_office`, not the
aggregate, so the nameless inner `CASE` refill survives the real suite too.

**Confidence: verified** (mechanism corrected and locally reproduced).

### 3. Retiring a provisional marker in a reviewed design document

**Claim.** Split the marker's hits into axes — body statement / review-checklist row
passed _because_ the marker exists / round-history entry / convention legend — edit
only the first two, rewrite the checklist rows in the same commit as the body, annotate
history rather than rewording it, and report counts with the axis and command.

**Sources checked.**

- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/grep.html — `-c` counts
  selected **lines**, so word mentions and multi-marker lines give different totals.
- https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions — Nygard:
  "'proposed' … or 'accepted' once it is agreed"; "may be marked as 'deprecated' or
  'superseded' with a reference to its replacement"; and "If a decision is reversed,
  we will keep the old one around, but mark it as superseded" (added this session — it
  is the directly on-point quote for annotate-don't-reword).
- https://www.rfc-editor.org/rfc/rfc7322.html — verified verbatim against the RFC
  text: "It is helpful for authors to clearly identify where text should be updated
  to reflect the newly assigned values. For example, the use of 'TBD1', 'TBD2', etc.,
  is recommended…".

**How verified.** All three quotes extracted from the fetched source text, not from a
summary. Field evidence is the NEWRTB-2435 ADR session: two `[추정]` body lines
converted, two checklist rows (L858, L860) instantly stale, and three legitimate
counts over one file (19 / 17 / 11) that reconciled only once the axis was named.
No external source states the checklist-staleness mechanism.

**Confidence: field-tested** for the mechanism; the grep/ADR/RFC supports are
`verified`. Page frontmatter carries `verified` on the strength of the three cited
sources plus the reproduced count-axis split; the checklist-staleness step is the
field-observed part and is attributed as such in Field context.

## Existing-layer check

Routed via `INDEX.md`, then read each domain index and every page whose "load when"
overlapped.

<!-- prettier-ignore -->
Pages read: qa-document-verification-editing-a-gated-document, qa-document-verification-spec-document-gates, backend-common-change-impact-call-site-enumeration, testing-quality-spec-artifact-checks, testing-quality-checks-that-cannot-pass, testing-quality-harness-reverse-controls, testing-quality-tests-that-cannot-fail, databases-schema-design-nullability-and-defaults

Overlaps and decisions:

- **`editing-a-gated-document`** was the strongest merge candidate for insight 3: its
  step 1 anchor table, step 4 ("never a global count") and step 5 (baseline re-run)
  neighbour the same territory. Kept **separate** because its subject is a _machine_
  gate breaking on an edit, while insight 3's subject is the document's reference to
  **itself** — a human checklist row whose evidence is the marker being deleted, which
  no anchor kind in that table covers. The new page states the split explicitly in
  both directions and links to it.
- **`call-site-enumeration`** owns _completeness_ of the site list ("did the search
  miss sites?"). Insight 1 is about sites the list already names being different
  _kinds_ of operation. Kept separate; the new page opens by pointing completeness
  questions back to it, and it is in `related:`.
- **`spec-artifact-checks` / `checks-that-cannot-pass`** cover check construction and
  unreachable gates. Insight 2's subject (a semantic property of a generated string
  vs. an open-ended wrapper class) is not covered; `checks-that-cannot-pass` is
  linked from insight 1 for the unreachable grep-count criterion.
- **`harness-reverse-controls`** owns the control-run principle; insight 2 cites it
  for the rename/reflow controls rather than restating it.
- **`nullability-and-defaults`** owns the zero-vs-absent modelling decision; both new
  pages defer to it rather than re-arguing it.
- No conflicts with existing directives were found. No existing page was modified
  except the three domain indexes (one new row each) and `log.md`.

Verification of this section: all 11 cross-referenced page ids were resolved against
the checkout's `wiki/` with a bogus-id control proving the check can fail (a first
attempt using bash associative arrays reported every id "OK" vacuously on macOS bash
3.2 and was discarded). `scripts/wiki-lint-prohibitions.js` over the whole wiki:
**61 directives / 61 compliant / 0 violations**, and a seeded bare prohibition in the
new testing page moved it to 62/61/1, proving the linter actually reads these files.

## Open-PR check

Listed 28 open `knowledge/*` PRs: #103 #101 #95 #92 #91 #86 #80 #79 #78 #76 #74 #73
#72 #69 #68 #66 #64 #62 #61 #58 #57 #56 #55 #52 #51 #50 #49 #47.

Four head branches (#49, #52, #74, #76 among them) no longer exist as `origin/`
refs, so all 28 were fetched via `refs/pull/N/head` and diffed against `origin/main`.
A first sweep returned zero hits for all three candidates — treated as a harness
failure rather than a result, and a `knip` positive control confirmed it: `grep -q`
was killing `git fetch` with SIGPIPE, so only 4 of 28 refs had actually been
fetched. Re-run with all 28 refs present and the control passing.

Per-candidate verdicts:

| Candidate                             | Overlapping open PR content                                                                                                                                                                                                                        | Verdict |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| 1 — aggregation layer of a helper     | #76 `cross-module-consumer-census` (same category, but "does anyone consume this?" ≠ "do these consumers do the same kind of thing?"); #49 `stale-artifact-baselines` mentions rollup **rows** excluded from a total — adjacent, different subject | **new** |
| 2 — generated-SQL property assertions | #52 `source-text-wiring-assertions` (anchors, but binding an anchor to a _site_ in hand-written source, not bracketing a generated expression against wrappers); #72 mentions `COALESCE` once as a read-with-default example                       | **new** |
| 3 — retiring a provisional marker     | #103 modifies `editing-a-gated-document` (whitespace **reflow** breaking single-line substring anchors — different mechanism); #78 uses "provisional" for a data-derived rule                                                                      | **new** |

No sibling duplicate PR is being opened. Two coordination notes for the reviewer:

- **#103 also edits `wiki/qa/index.md`** (rewording the `editing-a-gated-document`
  row) while this PR adds a new row to the same table; #76/#95/#103 also touch
  `wiki/backend/index.md`. These are adjacent-line index edits, not content
  conflicts — whichever merges second may need a one-line table rebase.
- Insight 2's page carries a deliberate **prose-only** pointer to the wiring-guard
  rules instead of a `[id]` link, because `testing-quality-source-text-wiring-assertions`
  exists only in unmerged #52. Once #52 lands, that sentence should become a link.

## Routing decision

| Insight | Target                                                                                               | Why this layer                                                                                                                                                                                                                                                                                                                                                 |
| ------- | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1       | `backend/common/change-impact/aggregation-layer-of-a-shared-helper.md` (new page, existing category) | The decision is about application-code structure — which layer owns a reduction — and is language-agnostic. `change-impact` already holds the pre-change survey work; this completes the trio: completeness (`call-site-enumeration`), reachability (#76's census), operational kind (this). SQL/index mechanics stay in `databases`, which the page links to. |
| 2       | `testing/quality/generated-sql-property-assertions.md` (new page, existing category)                 | It is about what a test must assert and how to prove the assertion can fail — `testing/quality`, alongside `tests-that-cannot-fail` and `harness-reverse-controls`. Not `databases`: the subject is the assertion, not the query.                                                                                                                              |
| 3       | `qa/document-verification/retiring-a-provisional-marker.md` (new page, existing category)            | Document-deliverable verification, sibling to `editing-a-gated-document` (machine anchors) and `spec-document-gates` (verdict policy). This page owns the document's references to itself.                                                                                                                                                                     |

No new category was created; all three fit existing ones. Indexes updated with one
"load when" row each (`wiki/backend/index.md`, `wiki/testing/index.md`,
`wiki/qa/index.md`) plus a `log.md` entry recording the ingest and the three
corrections.
