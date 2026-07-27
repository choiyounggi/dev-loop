---
id: databases-query-optimization-streaming-large-result-sets
domain: databases
category: query-optimization
applies_to: [postgresql, python, general]
confidence: verified
sources:
  - https://github.com/psycopg/psycopg2/blob/master/doc/src/usage.rst
  - https://github.com/psycopg/psycopg2/blob/master/doc/src/cursor.rst
  - https://openpyxl.readthedocs.io/en/stable/optimized.html
last_verified: 2026-07-13
related: [databases-query-optimization-keyset-pagination]
---

# Streaming Large Query Result Sets into the App

## When this applies

A single query returns a very large result (hundreds of thousands of rows or
more) and your process reads it all into the app — typically to export to a file
(Excel/CSV) or feed another sink. The pain is process **memory peak**, not query
speed. (Splitting the read into many bounded queries → keyset-pagination.)

## Do this

| Situation | Do |
|-----------|----|
| Stream a large single-query result to the app | Server-side cursor (`cursor(name=...)` in psycopg2 → PostgreSQL `DECLARE`) fetching in chunks via `itersize`/`fetchmany` — the DB sends batches, client memory stays minimal |
| Server-side cursor is unavailable (env blocks transactions/`BEGIN`) | Client-side cursor + `fetchmany(N)` batches so you never build the full Python list (`fetchall`), and write output through a **streaming writer** instead of buffering it |
| Output is Excel | openpyxl `Workbook(write_only=True)` + `ws.append(row)` — never holds the whole workbook; near-constant memory (<10 MB). Install `lxml` for large dumps (serialization speed, **not** the memory saving) |
| The result must be traversed twice (e.g. a post-pass needs the whole set first) | Don't hold it all in Python — spool each row to a local file (pickle/CSV) once, then stream-read the spool for the second pass |

Why, in order of memory impact:

1. **A client-side (default) cursor pulls the entire result set to the client on
   `execute`.** `fetchmany` only hands you slices of what libpq already buffered,
   so it caps the *Python object* explosion but not the driver buffer. Avoiding
   `fetchall` (the full Python list) is necessary but not sufficient.
2. **Only a server-side (named) cursor truly streams** — the DB ships chunks. But
   it lives *inside a transaction* (created `WITHOUT HOLD`), so it fails under
   autocommit or wherever transaction control is blocked.
3. **The output writer is often the bigger share.** A normal openpyxl workbook
   holds every cell object until `save()`; write-only mode removes that.

## Edge cases

| Case | Then |
|------|------|
| Named cursor under `autocommit=True` | Fetching raises "named cursor isn't valid anymore" / can't use outside a transaction — set `autocommit=False` |
| A read-only access proxy blocks `BEGIN` (e.g. an access-control proxy like QueryPie) | Server-side cursor is impossible (`No permission to execute BEGIN statement`) → fall back to client-side `fetchmany` + spool + streaming writer. Measured: 300k rows `fetchall`+normal workbook 838 MB → `fetchmany`+write-only **38 MB** |
| write-only workbook re-save/append | Only one `save()` is allowed (`WorkbookAlreadySaved`). Set column widths / `freeze_panes` **before** the first `append`; compute `auto_filter` from a row count, not `ws.max_row` (unreliable in write-only) |
| Two-pass over the result via re-running the query | Re-executing a heavy query doubles DB load — spool the single fetch to disk and re-read it instead |

## Sources

- https://github.com/psycopg/psycopg2/blob/master/doc/src/usage.rst — server-side (named) cursors are `WITHOUT HOLD`, invalid after commit / under autocommit; stream large datasets in chunks
- https://github.com/psycopg/psycopg2/blob/master/doc/src/cursor.rst — `fetchmany`/`itersize` semantics
- https://openpyxl.readthedocs.io/en/stable/optimized.html — write-only mode, near-constant memory, one save only, lxml recommended for large dumps
