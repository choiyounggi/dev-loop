---
id: databases-indexing-trigram-index-short-patterns
domain: databases
category: indexing
applies_to: [postgresql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/pgtrgm.html
  - https://postgrespro.com/list/thread-id/1821635
  - https://github.com/pgbigm/pg_bigm/blob/master/docs/pg_bigm_en.md
last_verified: 2026-08-10
related:
  [
    databases-indexing-index-selection,
    databases-query-optimization-reading-execution-plans,
    databases-indexing-partial-and-expression-indexes,
    databases-indexing-covering-indexes,
  ]
---

# Substring Search on a Trigram Index When the Keyword Is Shorter Than Three Characters

## When this applies

A `LIKE`/`ILIKE '%keyword%'` search is served by a PostgreSQL `pg_trgm` GIN or
GiST index, and the keyword comes from a user — so it can be one or two
characters. Also when such a search is fast for ordinary words and slow for short
ones, or when `EXPLAIN` shows a `Bitmap Index Scan` on the trigram index and the
query is still slow, or when you are choosing the minimum length for a search
input.

Reading the plan that shows this → [databases-query-optimization-reading-execution-plans].
Choosing the index type in the first place → [databases-indexing-index-selection].

## Do this

1. **Count the characters between wildcards, not the characters the user typed.**
   The index is searched by extracting trigrams from the pattern, and "a pattern
   with no extractable trigrams will degenerate to a full-index scan". A
   wildcard-delimited segment of fewer than three characters yields none:
   `get_wildcard_trigrams` "return[s] no trigrams for wildcard part 'st' since
   charlen < 3", so "GIN_SEARCH_MODE_ALL mode is used and results in full index
   scan instead of trigrams being used". `show_trgm('cat')` returning four
   trigrams does not contradict this — that padding applies to a *word* being
   indexed, and a `%…%` pattern asserts no word boundary to pad against.

2. **Read the cost from the recheck counters, not from the scan node's name.**
   The plan still reads `Bitmap Index Scan` on the trigram index; what changes is
   that the candidate bitmap becomes every row, so the work moves into the heap
   recheck. `EXPLAIN (ANALYZE, BUFFERS)` is what shows it — compare
   `Rows Removed by Index Recheck` against the table's row count and the buffer
   count against the short and long pattern.

3. **Pick the branch by whether short keywords are a supported input:**

| Situation | Do |
|-----------|-----|
| The search field has no other selective filter and short keywords are optional | Enforce a minimum keyword length at the API boundary and return a stated validation error, so the cost is refused rather than paid |
| The same query carries another selective condition (owner, department, tenant, date range) | Give that condition its own index and let it produce the bitmap, then let the substring match run as a heap filter — this bounds the scan by the selective condition instead of the pattern |
| Short keywords must return results and the operator is `LIKE` | Evaluate `pg_bigm`, which "allows a user to create **2-gram** (bigram) index", and whose own comparison rates "Full text search with 1-2 characters keyword" as "Fast" against pg_trgm's "Slow" — footnoted with the same mechanism, "only sequential scan or index full scan (not normal index scan) can run" |
| Short keywords must return results and the query needs `ILIKE`, `~`, or `~*` | Keep pg_trgm and normalize instead — index and query one case-folded expression ([databases-indexing-partial-and-expression-indexes]) — because pg_bigm's index supports "LIKE only" while pg_trgm supports "LIKE (~~), ILIKE (~~*), ~, ~*" |
| The short keyword is a prefix, not an infix (`'ab%'`) | Serve it from a B-tree on the column (or its case-folded expression) — a left-anchored pattern needs no trigrams |

4. **Verify the chosen branch on production-scale data before shipping it.** The
   degeneration is invisible at small row counts, where a full index scan is
   cheap; measure at the table's real size.

## Edge cases

| Case | Then |
|------|------|
| The other WHERE conditions appear under `Bitmap Heap Scan` as `Filter` rather than as `Index Cond` | They are not reducing the scan — they are applied after the rows are read, so the plan is still paying the full recheck. Add the index that lets one of them drive the bitmap |
| The query returns very few rows, so the result looks cheap | Read the cost from buffers and recheck counts, not from the row count — the scan reads the whole index and rechecks the whole heap whichever way the match comes out |
| Only some of the keyword's wildcard segments are short (`'%ab%defg%'`) | The pattern has extractable trigrams from the longer segment, so the index search works; the short segment contributes nothing and is checked on recheck |
| The column is searched with both a short and a long keyword in one `OR` | The short branch degenerates independently; split the branches so the long one keeps its index path, or apply the length rule per branch |
| The table is small today and the search is new | Record the row count at which the branch was chosen — the same query flips from acceptable to a full-table recheck with growth, and nothing in the plan's shape changes when it does |
| A GiST trigram index is used instead of GIN | The same extraction rule governs it: with no extractable trigrams there is nothing to look up, and the docs' degeneration statement covers "both `LIKE` and regular-expression searches" |
| The workload is non-alphabetic text (Japanese, Chinese, Korean) | The same comparison lists pg_trgm's full text search for non-alphabetic language as "Not supported", so the 3-character rule bites ordinary two-character words — treat pg_bigm as the default candidate rather than the fallback. Its footnote records the alternative, "commenting out KEEPONLYALNUM macro variable in contrib/pg_trgm/pg_trgm.h and rebuilding pg_trgm module", which makes the choice a build-vs-extension decision rather than a capability wall |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read `Bitmap Index Scan` on the trigram index as proof the index is doing the work | Compare `Rows Removed by Index Recheck` with the table's row count | The node name is the same in both cases; the recheck count is what separates a lookup from a full scan |
| Add a second trigram index, or `REINDEX`, because the short-keyword query is slow | Apply the length rule from step 3 | The index is being scanned in full by design for a pattern with no trigrams; another copy of it is scanned in full too |
| Raise `work_mem` or add heap-side tuning to make the short query fit | Refuse the short pattern at the boundary or give the query a selective driver index | The cost is proportional to the table, not to the memory available for the bitmap |
| Assume a two-character search is cheap because it returns three rows | Measure buffers for a two-character and a three-character pattern on the same index | Measured 2026-08-10 on a 4.64M-row table: a 3-character `ILIKE` ran 17 ms / 4 buffers, the 2-character one 18,789 ms / 121,837 buffers, with `Rows Removed by Index Recheck: 4,640,486` and 3 rows matched |
| Swap pg_trgm for pg_bigm to fix a slow `ILIKE` | Decide the case-folding strategy first, then choose | pg_bigm's operator support is "LIKE only"; an `ILIKE` workload has to be rewritten to a normalized expression either way |

## Sources

- https://www.postgresql.org/docs/current/pgtrgm.html — "For both `LIKE` and regular-expression searches, keep in mind that a pattern with no extractable trigrams will degenerate to a full-index scan"; "The index search works by extracting trigrams from the search string and then looking these up in the index. The more trigrams in the search string, the more effective the index search is"; "A trigram is a group of three consecutive characters taken from a string"; and the padding rule — "Each word is considered to have two spaces prefixed and one space suffixed when determining the set of trigrams contained in the string" — which is why `show_trgm` on a short *word* still returns trigrams while a `%…%` pattern yields none
- https://postgrespro.com/list/thread-id/1821635 — Amit Langote, pgsql list thread (2013-05-31): "When I debugged a partial match case such as 'column like '%st%'', it appears that get_wildcard_trigrams return no trigrams for wildcard part 'st' since charlen < 3"; "Hence, GIN_SEARCH_MODE_ALL mode is used and results in full index scan instead of trigrams being used". This is the mechanism behind the docs' one-sentence statement, and it is stated in terms of the wildcard-delimited segment rather than the whole pattern
- https://github.com/pgbigm/pg_bigm/blob/master/docs/pg_bigm_en.md — "The pg_bigm module provides full text search capability in [PostgreSQL]. This module allows a user to create **2-gram** (bigram) index for faster full text search." Its pg_trgm comparison table (verified against the raw file 2026-08-10, cell by cell) reads: "Phrase matching method for full text search" 3-gram vs 2-gram; "Available text search operators" "LIKE (~~), ILIKE (~~*), ~, ~*" vs "LIKE only"; "Full text search for non-alphabetic language (e.g., Japanese)" "Not supported (\*1)" vs "Supported"; "Full text search with 1-2 characters keyword" "Slow (\*2)" vs "Fast"; "Available index" "GIN and GiST" vs "GIN only". Footnote (\*2) gives the mechanism independently of the PostgreSQL docs — "Because, in this search, only sequential scan or index full scan (not normal index scan) can run" — and footnote (\*1) records that pg_trgm's non-alphabetic limit is liftable "by commenting out KEEPONLYALNUM macro variable … and rebuilding pg_trgm module". The operator row is the constraint that decides step 3's last two rows
- Field measurement 2026-08-10 (PostgreSQL, 4,640,489-row table, `gin(tip_ctn gin_trgm_ops)`, `EXPLAIN (ANALYZE, BUFFERS)`): a 3-character `ILIKE '%…%'` ran 17 ms reading 4 buffers; a 2-character `ILIKE '%TI%'` on the same index and column ran 18,789 ms reading 121,837 buffers with `Rows Removed by Index Recheck: 4,640,486` and 3 rows actually matching. Both plans showed a `Bitmap Index Scan` on the trigram index, and the query's other conditions appeared as `Filter` on the `Bitmap Heap Scan`, reducing nothing
