# Knowledge flush — 1 insight

Source: RNR-3440 (사내 잠재매물 주간 추출 스크립트 메모리 피크 저감). Candidate:
"QueryPie 프록시 경유로 대용량 결과를 스트리밍할 때 server-side named cursor 대신
일반 커서 + `fetchmany` + openpyxl `write_only`."

## Verified best-practice

**Claim 1 — psycopg2 server-side (named) cursor requires a transaction; fails under autocommit.**
- Source: psycopg2 usage docs — `https://github.com/psycopg/psycopg2/blob/master/doc/src/usage.rst` (via Context7). Quote: "Named cursors are typically created 'WITHOUT HOLD', meaning they exist only within the current transaction. Attempting to fetch from them after a commit or in autocommit mode raises an exception."
- Matches my live repro (`can't use a named cursor outside of transactions`). → **verified**

**Claim 2 — a client-side (default) cursor pulls the whole result set to the client on execute; `fetchmany` only caps the Python-list explosion.**
- Source: psycopg2 cursor/usage docs + FAQ (named-cursor advantage = "data is fetched in chunks … minimal client memory"). By contrast the default cursor buffers the full result in libpq. → **verified**

**Claim 3 — openpyxl `write_only` gives near-constant memory (<10 MB); one save only; lxml is for serialization speed, not the memory saving.**
- Source: openpyxl Optimised Modes — `https://openpyxl.readthedocs.io/en/stable/optimized.html` (via WebSearch). "keeping memory usage under 10Mb"; "A write-only workbook can only be saved once"; "make sure you have lxml installed" for large dumps (speed).
- This **corrects** the raw candidate's "lxml unnecessary" → precise form: unnecessary *for the memory win*, recommended *for large-dump speed*. Confirmed by my server test (write-only worked with lxml absent). → **verified**

**Claim 4 — QueryPie blocks `BEGIN`, so server-side cursor is impossible there.**
- Environment-specific, no external source. Live repro in gui context: `autocommit=False` + named cursor → `[ENGINE] No permission to execute BEGIN statement`. → **field-tested**. Generalized in the page to "a read-only access-control proxy that blocks transaction control", with QueryPie as the concrete example (not a product-specific page).
- Memory figure 838 MB → 38 MB (300k synthetic rows) is my RNR-3440 measurement (`ru_maxrss`, separate processes).

## Existing-layer check

- Pages read: `databases/index.md`, `databases/query-optimization/keyset-pagination.md`, `backend/python/index.md`.
- Overlap: keyset-pagination is the nearest neighbor (both handle large result sets) but a **distinct** topic — pagination splits the read into many bounded queries; this page streams a *single* query's result in chunks. Not a duplicate → new page + **bidirectional `related` link** added to both.
- backend/python has no DB-cursor page; the psycopg2/openpyxl specifics live as concrete examples inside the databases page rather than a separate python page (no duplication).
- Conflicts: none found.

## Routing decision

- Target: **`databases/query-optimization/streaming-large-result-sets.md`** (new page).
- Category `query-optimization` fits (memory-bounding how a query's result is pulled into the app is query-execution optimization); no new category needed.
- Registered in `databases/index.md` (query-optimization section) and appended to `log.md`.
