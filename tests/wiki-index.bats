#!/usr/bin/env bats
# Tests for scripts/wiki-index.py --build / --incremental — the page parser,
# the section-level chunker, the deterministic test-hash embedder, and the
# atomic write ordering. Stdlib python3 only: DEV_LOOP_WIKI_EMBED_MODEL=test-hash
# keeps every case offline (no 133MB model download).

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/wiki-index.py"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export DEV_LOOP_WIKI_INDEX_DIR="$BATS_TEST_TMPDIR/idx"
  export DEV_LOOP_WIKI_ROOT="$BATS_TEST_TMPDIR/wiki"
  export DEV_LOOP_WIKI_EMBED_MODEL=test-hash
  # The harness that runs this suite may export these; they would flip the
  # env-dependent branches away from the defaults each test states.
  unset DEV_LOOP_WIKI_INDEX DEV_LOOP_WIKI_LOCK_TTL DEV_LOOP_WIKI_RUN_ID DEV_LOOP_WIKI_DEBUG
  IDX="$DEV_LOOP_WIKI_INDEX_DIR"
  WIKI="$DEV_LOOP_WIKI_ROOT"
}

# Three content pages across two domains, each domain index carrying the
# "load when" row that the trigger chunk must absorb.
make_wiki() {
  mkdir -p "$WIKI/alpha/cat" "$WIKI/beta/cat"

  cat > "$WIKI/alpha/index.md" <<'EOF'
# alpha — Domain Index

## cat

| Page | Load when |
|------|-----------|
| [one](cat/one.md) | Handing out fresh credentials to a machine identity on a schedule |
| [two](cat/two.md) | Paging through a long collection without repeating or dropping entries |
EOF

  cat > "$WIKI/beta/index.md" <<'EOF'
# beta — Domain Index

## cat

| Page | Load when |
|------|-----------|
| [three](cat/three.md) | Re-sending an event to a subscriber whose endpoint went quiet |
EOF

  cat > "$WIKI/alpha/cat/one.md" <<'EOF'
---
id: alpha-cat-one
domain: alpha
category: cat
confidence: verified
last_verified: 2026-01-01
---

# one

## When this applies

Rotating api keys for a service account.

## Do this

1. Issue the replacement key before revoking the old one.
2. Keep both keys valid for one full deploy cycle.
3. Revoke the previous key once no caller presents it.

## Edge cases

| Case | Do |
|------|----|
| The consumer caches the key for a day | Overlap the validity window with the cache ttl |
| The revoke call fails midway | Re-run it; revocation is idempotent |

## Instead of

| Instead of | Do |
|------------|----|
| Rotating on a fixed calendar date | Rotate on issue age so a late deploy cannot strand a caller |

## Sources

- https://example.invalid/one
EOF

  cat > "$WIKI/alpha/cat/two.md" <<'EOF'
---
id: alpha-cat-two
domain: alpha
category: cat
confidence: verified
last_verified: 2026-01-02
---

# two

## When this applies

Choosing a pagination cursor for a list endpoint.

## Do this

1. Encode the sort key and the tiebreaker id into the cursor.

## Sources

- https://example.invalid/two
EOF

  cat > "$WIKI/beta/cat/three.md" <<'EOF'
---
id: beta-cat-three
domain: beta
category: cat
confidence: provisional
last_verified: 2026-01-03
---

# three

## When this applies

Retrying a webhook delivery after a timeout.

## Do this

1. Retry with exponential backoff and full jitter.
2. Give up after the stated attempt budget and record a dead letter.

## Edge cases

| Case | Do |
|------|----|
| The receiver is slow but healthy | Raise the timeout before raising the retry count |

## Sources

- https://example.invalid/three
EOF
}

chunk_count() {
  sqlite3 "$IDX/wiki.db" "select count(*) from chunks where $1"
}

@test "normal: build indexes every page and writes the manifest" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ -f "$IDX/wiki.db" ]
  [ -f "$IDX/manifest.json" ]
  [ "$(jq -r '.pages | length' "$IDX/manifest.json")" = "3" ]
  [ "$(jq -r '.model' "$IDX/manifest.json")" = "test-hash" ]
  [ "$(jq -r '.dim' "$IDX/manifest.json")" = "64" ]
  [ "$(jq -r '.plugin_version' "$IDX/manifest.json")" = "$(jq -r .version "${BATS_TEST_DIRNAME}/../.claude-plugin/plugin.json")" ]
  # every indexed page carries a sha256 of the file on disk
  [ "$(jq -r '.pages["alpha/cat/one.md"]' "$IDX/manifest.json")" = "$(shasum -a 256 "$WIKI/alpha/cat/one.md" | cut -d' ' -f1)" ]
  # negative control: a path that was never indexed is absent
  run jq -e '.pages["alpha/cat/nope.md"]' "$IDX/manifest.json"
  [ "$status" -ne 0 ]
}

@test "normal: index.md files are never indexed as content pages" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ "$(chunk_count "path like '%index.md'")" = "0" ]
  # negative control: the content pages themselves did land
  [ "$(chunk_count "path = 'alpha/cat/one.md'")" != "0" ]
}

@test "normal: chunk rules split each page by its own sections" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]

  run sqlite3 "$IDX/wiki.db" "select section || '|' || count(*) from chunks where path='alpha/cat/one.md' group by section order by section"
  [ "$status" -eq 0 ]
  [[ "$output" == *"directive|3"* ]]
  [[ "$output" == *"edge_case|2"* ]]
  [[ "$output" == *"instead_of|1"* ]]
  [[ "$output" == *"trigger|1"* ]]

  # the trigger chunk absorbs the domain index's own "load when" sentence
  run sqlite3 "$IDX/wiki.db" "select text from chunks where path='alpha/cat/one.md' and section='trigger'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Rotating api keys for a service account"* ]]
  [[ "$output" == *"Load when:"* ]]
  [[ "$output" == *"machine identity on a schedule"* ]]

  # metadata rides along on every chunk
  run sqlite3 "$IDX/wiki.db" "select distinct page_id || '|' || domain || '|' || category || '|' || confidence || '|' || last_verified from chunks where path='alpha/cat/one.md'"
  [ "$status" -eq 0 ]
  [ "$output" = "alpha-cat-one|alpha|cat|verified|2026-01-01" ]

  # negative control: a page with no Edge cases / Instead of section yields
  # neither kind, and its single Do-this item is one directive chunk
  [ "$(chunk_count "path='alpha/cat/two.md' and section='edge_case'")" = "0" ]
  [ "$(chunk_count "path='alpha/cat/two.md' and section='instead_of'")" = "0" ]
  [ "$(chunk_count "path='alpha/cat/two.md' and section='directive'")" = "1" ]
}

@test "normal: table header and separator rows are not chunks" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  # "| Case | Do |" and "|------|----|" must not become edge_case chunks:
  # one.md has exactly 2 data rows.
  [ "$(chunk_count "path='alpha/cat/one.md' and section='edge_case'")" = "2" ]
  run sqlite3 "$IDX/wiki.db" "select text from chunks where path='alpha/cat/one.md' and section='edge_case'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"---"* ]]
  # negative control: the real row text did survive
  [[ "$output" == *"caches the key for a day"* ]]
}

@test "normal: the test-hash embedder is deterministic across builds" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  first=$(sqlite3 "$IDX/wiki.db" "select hex(embedding) from chunks where path='alpha/cat/one.md' and section='trigger'")
  [ -n "$first" ]

  DEV_LOOP_WIKI_INDEX_DIR="$BATS_TEST_TMPDIR/idx2" run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  second=$(sqlite3 "$BATS_TEST_TMPDIR/idx2/wiki.db" "select hex(embedding) from chunks where path='alpha/cat/one.md' and section='trigger'")
  [ "$first" = "$second" ]

  # negative control: different text embeds differently
  other=$(sqlite3 "$IDX/wiki.db" "select hex(embedding) from chunks where path='beta/cat/three.md' and section='trigger'")
  [ -n "$other" ]
  [ "$first" != "$other" ]
}

@test "error: a page with broken frontmatter is skipped and the build still succeeds" {
  make_wiki
  printf '%s\n' '# no frontmatter at all' 'body' > "$WIKI/alpha/cat/bad.md"
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip alpha/cat/bad.md"* ]]
  [ "$(chunk_count "path='alpha/cat/bad.md'")" = "0" ]
  [ "$(sqlite3 "$IDX/wiki.db" "select count(*) from pages where path='alpha/cat/bad.md'")" = "0" ]
  # negative control: the three good pages were still indexed
  [ "$(sqlite3 "$IDX/wiki.db" "select count(*) from pages")" = "3" ]
}

@test "error: an unparseable page still lets the index settle to fresh" {
  make_wiki
  printf '%s\n' '# no frontmatter at all' 'body' > "$WIKI/alpha/cat/bad.md"
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]

  # The manifest is the cache key of the whole directory: a skipped page has to
  # carry its sha there, or every session would reindex over one bad file.
  [ "$(jq -r '.pages | length' "$IDX/manifest.json")" = "4" ]
  [ "$(jq -r '.pages["alpha/cat/bad.md"]' "$IDX/manifest.json")" = "$(shasum -a 256 "$WIKI/alpha/cat/bad.md" | cut -d' ' -f1)" ]

  run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]

  # an --incremental pass does not un-settle it either
  run python3 "$SCRIPT" --incremental
  [ "$status" -eq 0 ]
  run python3 "$SCRIPT" --status
  [ "$output" = "fresh" ]

  # negative control: fixing the page's content does make it stale again, and
  # the repaired page then gets indexed
  cat > "$WIKI/alpha/cat/bad.md" <<'PAGEEOF'
---
id: alpha-cat-bad
domain: alpha
category: cat
confidence: verified
last_verified: 2026-01-04
---

## When this applies

Recovering a page that used to be malformed.

## Do this

1. Rebuild the index after repairing the frontmatter.
PAGEEOF
  run python3 "$SCRIPT" --status
  [ "$output" = "incremental" ]
  run python3 "$SCRIPT" --incremental
  [ "$status" -eq 0 ]
  [ "$(chunk_count "path='alpha/cat/bad.md'")" != "0" ]
  run python3 "$SCRIPT" --status
  [ "$output" = "fresh" ]
}

@test "error: a page whose frontmatter has no closing delimiter is skipped" {
  make_wiki
  printf '%s\n' '---' 'id: alpha-cat-unterminated' 'domain: alpha' '' '## When this applies' 'x' > "$WIKI/alpha/cat/unterminated.md"
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ "$(sqlite3 "$IDX/wiki.db" "select count(*) from pages")" = "3" ]
  [ "$(chunk_count "path='alpha/cat/unterminated.md'")" = "0" ]
  # negative control: a well-formed page in the same directory was indexed
  run jq -e '.pages["alpha/cat/one.md"]' "$IDX/manifest.json"
  [ "$status" -eq 0 ]
  [ "$(chunk_count "path='alpha/cat/one.md'")" != "0" ]
}

@test "error: a missing wiki root exits 4 and writes no index" {
  DEV_LOOP_WIKI_ROOT="$BATS_TEST_TMPDIR/nope" run python3 "$SCRIPT" --build
  [ "$status" -eq 4 ]
  [ ! -f "$IDX/wiki.db" ]
  [ ! -f "$IDX/manifest.json" ]
}

@test "boundary: an empty wiki root builds an empty index" {
  mkdir -p "$WIKI"
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ "$(jq -r '.pages | length' "$IDX/manifest.json")" = "0" ]
  [ "$(chunk_count "1=1")" = "0" ]
  # negative control: the database file itself was still created
  [ -f "$IDX/wiki.db" ]
}

@test "boundary: a single-page wiki indexes that one page" {
  mkdir -p "$WIKI/alpha/cat"
  cat > "$WIKI/alpha/cat/one.md" <<'EOF'
---
id: alpha-cat-one
domain: alpha
category: cat
confidence: verified
last_verified: 2026-01-01
---

## When this applies

Rotating api keys for a service account.

## Do this

1. Issue the replacement key before revoking the old one.
EOF
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ "$(jq -r '.pages | length' "$IDX/manifest.json")" = "1" ]
  # a page with no domain index still yields a trigger chunk (no "Load when:")
  [ "$(chunk_count "section='trigger'")" = "1" ]
  run sqlite3 "$IDX/wiki.db" "select text from chunks where section='trigger'"
  [[ "$output" != *"Load when:"* ]]
  # negative control: the Do-this item is still chunked
  [ "$(chunk_count "section='directive'")" = "1" ]
}

@test "boundary: the build is atomic and a rebuild is idempotent" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  before=$(chunk_count "1=1")
  [ "$before" -gt 0 ]

  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ "$(chunk_count "1=1")" = "$before" ]

  # no transient artifacts survive the swap
  run bash -c "ls '$IDX' | grep -c 'wiki.db.tmp'"
  [ "$output" = "0" ]
  # negative control: the finished database is there under its final name
  [ -f "$IDX/wiki.db" ]
}

@test "boundary: the default HOME location is untouched when the index dir is overridden" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.dev-loop/wiki-index" ]
  # negative control: the override location did receive the index
  [ -f "$IDX/wiki.db" ]
}

@test "boundary: --incremental removes a deleted page from the index" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ "$(chunk_count "path='alpha/cat/two.md'")" != "0" ]

  rm "$WIKI/alpha/cat/two.md"
  run python3 "$SCRIPT" --incremental
  [ "$status" -eq 0 ]
  [ "$(chunk_count "path='alpha/cat/two.md'")" = "0" ]
  run jq -e '.pages["alpha/cat/two.md"]' "$IDX/manifest.json"
  [ "$status" -ne 0 ]
  # negative control: the surviving pages kept their rows
  [ "$(chunk_count "path='alpha/cat/one.md'")" != "0" ]
  [ "$(jq -r '.pages | length' "$IDX/manifest.json")" = "2" ]
}

@test "boundary: a relative index dir anchors to HOME, not to the working directory" {
  make_wiki
  # Run from a directory that is NOT the worktree root: a CWD-relative resolution
  # would land the index under $BATS_TEST_TMPDIR instead of the scratch HOME.
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  DEV_LOOP_WIKI_INDEX_DIR="relative-idx" run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ -f "$HOME/relative-idx/wiki.db" ]
  [ -f "$HOME/relative-idx/manifest.json" ]
  # negative control: nothing was written next to the working directory
  [ ! -e "$BATS_TEST_TMPDIR/elsewhere/relative-idx" ]
}

@test "boundary: a relative wiki root anchors to the plugin root, not to the working directory" {
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  # "wiki" relative to the plugin root is the real bundled wiki
  DEV_LOOP_WIKI_ROOT="wiki" run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" != "disabled" ]
  # negative control: a relative root that exists under neither anchor is disabled
  DEV_LOOP_WIKI_ROOT="no-such-dir" run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "disabled" ]
}

@test "error: an unavailable embedding backend exits 5 with a named reason" {
  make_wiki
  run python3 -c "import fastembed"
  [ "$status" -ne 0 ]

  # A real model name under a python3 without fastembed: documented code, no traceback
  DEV_LOOP_WIKI_EMBED_MODEL="BAAI/bge-small-en-v1.5" run python3 "$SCRIPT" --build
  [ "$status" -eq 5 ]
  [[ "$output" == *"embedding backend unavailable"* ]]
  [[ "$output" != *"Traceback"* ]]
  # the failed build left no half-written index and released its lock
  [ ! -f "$IDX/wiki.db" ]
  [ ! -e "$IDX/.build.lock" ]

  # negative control: the test backend still builds from the same state
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ -f "$IDX/wiki.db" ]
}

@test "error: --incremental with an unavailable backend exits 5 and keeps the index" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  before=$(sqlite3 "$IDX/wiki.db" "select count(*) from chunks")
  [ "$before" -gt 0 ]
  printf '%s\n' 'An edit that makes the index stale.' >> "$WIKI/alpha/cat/two.md"

  DEV_LOOP_WIKI_EMBED_MODEL="BAAI/bge-small-en-v1.5" run python3 "$SCRIPT" --incremental
  [ "$status" -eq 5 ]
  [[ "$output" == *"embedding backend unavailable"* ]]
  # negative control: the existing index is untouched and still queryable
  [ "$(sqlite3 "$IDX/wiki.db" "select count(*) from chunks")" = "$before" ]
  [ ! -e "$IDX/.build.lock" ]
}

@test "boundary: --build and --incremental each leave the index as one file" {
  # A1 promises a single file that survives a reboot. The writer must leave
  # wiki.db alone in the index dir — no -wal/-shm carried over from its own run.
  # Readers are a separate story: a read-only SQLite connection cannot delete a
  # WAL on close, so `search`/`page`/`eval` do leave sidecars behind. That is
  # why every assertion below runs BEFORE anything reads the database.
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ -f "$IDX/wiki.db" ]
  [ ! -f "$IDX/wiki.db-wal" ]
  [ ! -f "$IDX/wiki.db-shm" ]
  [ ! -f "$IDX/wiki.db.tmp" ]

  # A new page whose text lands in a chunked section (appending to "## Sources"
  # would change the file's sha without ever producing a searchable chunk).
  cat > "$WIKI/alpha/cat/four.md" <<'PAGEEOF'
---
id: alpha-cat-four
domain: alpha
category: cat
confidence: verified
last_verified: 2026-01-05
---

## When this applies

Walking a long result set in batches.

## Do this

1. Prefer a keyset cursor over a numeric offset.
PAGEEOF
  run python3 "$SCRIPT" --incremental
  [ "$status" -eq 0 ]
  [ ! -f "$IDX/wiki.db-wal" ]
  [ ! -f "$IDX/wiki.db-shm" ]

  # the edit is durably in the main file: a fresh process reads it back
  run python3 "$SCRIPT" search --query "keyset cursor over a numeric offset" --k 5 --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r 'any(.[]; .snippet | test("keyset cursor"))')" = "true" ]

  # negative control: with wiki.db moved aside a reader finds nothing, so the
  # rows above came from that one file
  mv "$IDX/wiki.db" "$IDX/wiki.db.moved"
  run python3 "$SCRIPT" search --query "keyset cursor over a numeric offset" --k 5 --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
  mv "$IDX/wiki.db.moved" "$IDX/wiki.db"
  [ "$(sqlite3 "$IDX/wiki.db" "select count(*) from chunks")" != "0" ]
}

@test "normal: eval --report prints per-case records, one sweep row, and the final floor line" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  cat > "$BATS_TEST_TMPDIR/cases.json" <<'EOF'
[
  {"query": "Rotating api keys for a service account.", "expected_page_id": "alpha-cat-one", "source": "test"},
  {"query": "Choosing a pagination cursor for a list endpoint.", "expected_page_id": "alpha-cat-two", "source": "test"},
  {"query": "Whether a spacecraft trajectory needs a mid-course correction burn", "expected_page_id": null, "source": "test"}
]
EOF
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/cases.json" --k 5 --report
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 20 ]
  [ "${lines[0]}" = '{"query": "Rotating api keys for a service account.", "expected_page_id": "alpha-cat-one", "rank": 1, "top_score": 0.690066, "expected_score": 0.690066, "source": "test"}' ]
  [ "${lines[1]}" = '{"query": "Choosing a pagination cursor for a list endpoint.", "expected_page_id": "alpha-cat-two", "rank": 1, "top_score": 0.774597, "expected_score": 0.774597, "source": "test"}' ]
  [ "${lines[2]}" = '{"query": "Whether a spacecraft trajectory needs a mid-course correction burn", "expected_page_id": null, "rank": null, "top_score": 0.434122, "expected_score": null, "source": "test"}' ]
  [ "${lines[3]}" = '{"floor": "0.60", "recall": "1.00", "fpr": "0.00", "top1_hits": 2}' ]
  [ "${lines[19]}" = "floor: 0.60 recall 1.00 fpr 0.00" ]

  # negative control: the default (no --report) call over the same file still
  # prints only the classic one-line form, unchanged
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/cases.json" --k 5
  [ "$status" -eq 0 ]
  [ "$output" = "recall@5 1.00 hits 2 total 2" ]
}

@test "error: eval with a missing cases file exits 3 with a named stderr line" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/does-not-exist.json" --k 5
  [ "$status" -eq 3 ]
  [[ "$output" == *"cases file not found"* ]]
}

@test "error: eval with a malformed case object exits 3 naming the case index" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  printf '[{"query": "x"}]' > "$BATS_TEST_TMPDIR/bad.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/bad.json" --k 5
  [ "$status" -eq 3 ]
  [[ "$output" == *"malformed case at index 0"* ]]
}

@test "error: eval --report with no index still exits 4" {
  make_wiki
  printf '[{"query": "x", "expected_page_id": "y"}]' > "$BATS_TEST_TMPDIR/cases.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/cases.json" --k 5 --report
  [ "$status" -eq 4 ]
  [[ "$output" == *"no index"* ]]
}

@test "boundary: eval --report over an empty cases list prints only the sweep and 'none separable'" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  printf '[]' > "$BATS_TEST_TMPDIR/empty.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/empty.json" --k 5 --report
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 17 ]
  [ "${lines[0]}" = '{"floor": "0.60", "recall": "0.00", "fpr": "0.00", "top1_hits": 0}' ]
  [ "${lines[16]}" = "floor: none separable" ]

  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/empty.json" --k 5
  [ "$status" -eq 0 ]
  [ "$output" = "recall@5 0.00 hits 0 total 0" ]
}

@test "boundary: eval --report over a negatives-only file counts total as 0 and reports no separable floor" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  printf '[{"query": "Whether a spacecraft trajectory needs a mid-course correction burn", "expected_page_id": null, "source": "test"}]' > "$BATS_TEST_TMPDIR/neg.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/neg.json" --k 5
  [ "$status" -eq 0 ]
  [ "$output" = "recall@5 0.00 hits 0 total 0" ]

  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/neg.json" --k 5 --report
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 18 ]
  [ "${lines[0]}" = '{"query": "Whether a spacecraft trajectory needs a mid-course correction burn", "expected_page_id": null, "rank": null, "top_score": 0.434122, "expected_score": null, "source": "test"}' ]
  [ "${lines[17]}" = "floor: none separable" ]
}

@test "boundary: eval --report ranks a positive whose expected page is absent from the index as null" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  printf '[{"query": "Rotating api keys for a service account.", "expected_page_id": "nonexistent-page-id", "source": "test"}]' > "$BATS_TEST_TMPDIR/absent.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/absent.json" --k 5 --report
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = '{"query": "Rotating api keys for a service account.", "expected_page_id": "nonexistent-page-id", "rank": null, "top_score": 0.690066, "expected_score": null, "source": "test"}' ]
}

@test "error: eval with invalid JSON in the cases file exits 3 naming it as malformed" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  printf '[{"query": ' > "$BATS_TEST_TMPDIR/broken.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/broken.json" --k 5
  [ "$status" -eq 3 ]
  [[ "$output" == *"malformed cases file"* ]]
}

@test "error: eval with a top-level JSON value that is not a list exits 3 without a traceback" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  for body in 'null' '"text"' '{"query": "x", "expected_page_id": null}'; do
    printf '%s' "$body" > "$BATS_TEST_TMPDIR/notlist.json"
    run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/notlist.json" --k 5
    [ "$status" -eq 3 ]
    [[ "$output" == *"malformed cases file"* ]]
    [[ "$output" != *"Traceback"* ]]
  done
}

@test "error: eval with a cases file that is not valid UTF-8 exits 3 without a traceback" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  printf '[{"query": "\xff", "expected_page_id": null}]' > "$BATS_TEST_TMPDIR/latin.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/latin.json" --k 5
  [ "$status" -eq 3 ]
  [[ "$output" == *"malformed cases file"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "error: eval names the offending index for a case without a query and for a non-object case" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  printf '[{"query": "ok", "expected_page_id": null}, {"expected_page_id": "alpha-cat-one"}]' > "$BATS_TEST_TMPDIR/noquery.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/noquery.json" --k 5
  [ "$status" -eq 3 ]
  [[ "$output" == *"malformed case at index 1"* ]]

  printf '[{"query": "ok", "expected_page_id": null}, {"query": "ok", "expected_page_id": null}, null]' > "$BATS_TEST_TMPDIR/nonobj.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/nonobj.json" --k 5
  [ "$status" -eq 3 ]
  [[ "$output" == *"malformed case at index 2"* ]]
}

@test "error: eval checks the cases file before it looks for the index" {
  make_wiki
  printf '[{"query": "x"}]' > "$BATS_TEST_TMPDIR/bad.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/bad.json" --k 5
  [ "$status" -eq 3 ]
  [[ "$output" == *"malformed case at index 0"* ]]
}

@test "normal: the sweep counts a score equal to a floor and picks the first floor meeting both limits (controlled scores)" {
  run python3 - "$SCRIPT" <<'PYEOF'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("wiki_index", sys.argv[1])
wi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wi)

# (expected_score, rank, top_score); rank None = expected page absent from the top-k
POSITIVES = [
    (0.95, 1, 0.95), (0.90, 1, 0.90), (0.86, 1, 0.86), (0.82, 1, 0.82),
    (0.78, 2, 0.88), (0.74, 1, 0.74), (0.72, 1, 0.72), (0.68, 1, 0.68),
    (0.62, 3, 0.91), (None, None, 0.97),
]

def run(negative_tops):
    table, cases = {}, []
    for i, (exp, rank, top) in enumerate(POSITIVES):
        if rank is None:
            table["p%d" % i] = [{"page_id": "other", "score": top}]
        elif rank == 1:
            table["p%d" % i] = [{"page_id": "want", "score": exp}]
        else:
            table["p%d" % i] = ([{"page_id": "other", "score": top}]
                                + [{"page_id": "filler", "score": 0.5}] * (rank - 2)
                                + [{"page_id": "want", "score": exp}])
        cases.append({"query": "p%d" % i, "expected_page_id": "want", "source": "t"})
    for i, top in enumerate(negative_tops):
        table["n%d" % i] = [{"page_id": "other", "score": top}]
        cases.append({"query": "n%d" % i, "expected_page_id": None, "source": "t"})
    wi.search = lambda cfg, query, k=5, **kw: table[query]
    return wi.evaluate_report(None, cases, 5)

FLOORS = ["0.60", "0.62", "0.64", "0.66", "0.68", "0.70", "0.72", "0.74",
          "0.76", "0.78", "0.80", "0.82", "0.84", "0.86", "0.88", "0.90"]
# recall counts expected_score >= floor over 10 positives (a score equal to
# the floor counts); top1 counts rank-1 positives at or above the floor.
RECALL = ["0.90", "0.90", "0.80", "0.80", "0.80", "0.70", "0.70", "0.60",
          "0.50", "0.50", "0.40", "0.40", "0.30", "0.30", "0.20", "0.20"]
TOP1 = [7, 7, 7, 7, 7, 6, 6, 5, 4, 4, 4, 4, 3, 3, 2, 2]

# Scenario A: negatives at 0.66 and 0.64 (each equal to a floor) plus eight low ones.
records, sweep, verdict = run([0.66, 0.64] + [0.30] * 8)
assert [r["floor"] for r in sweep] == FLOORS
assert [r["recall"] for r in sweep] == RECALL, [r["recall"] for r in sweep]
assert [r["top1_hits"] for r in sweep] == TOP1, [r["top1_hits"] for r in sweep]
FPR_A = ["0.20", "0.20", "0.20", "0.10", "0.00"] + ["0.00"] * 11
assert [r["fpr"] for r in sweep] == FPR_A, [r["fpr"] for r in sweep]
# first floor with fpr <= 0.10 (1/10, equal to the limit) and recall >= 0.80 (8/10, equal to the limit)
assert verdict == {"floor": "0.66", "recall": "0.80", "fpr": "0.10", "top1_hits": 7}, verdict
assert list(records[0]) == ["query", "expected_page_id", "rank", "top_score", "expected_score", "source"]
assert (records[4]["rank"], records[4]["top_score"], records[4]["expected_score"]) == (2, 0.88, 0.78)
assert (records[8]["rank"], records[8]["expected_score"]) == (3, 0.62)
assert (records[9]["rank"], records[9]["top_score"], records[9]["expected_score"]) == (None, 0.97, None)
assert (records[10]["expected_page_id"], records[10]["rank"], records[10]["top_score"]) == (None, None, 0.66)

# Scenario B: two negatives at 0.69 keep fpr at 0.20 until floor 0.70, where recall is only 0.70.
records, sweep, verdict = run([0.69, 0.69] + [0.30] * 8)
assert [r["fpr"] for r in sweep] == ["0.20"] * 5 + ["0.00"] * 11, [r["fpr"] for r in sweep]
assert sweep[5] == {"floor": "0.70", "recall": "0.70", "fpr": "0.00", "top1_hits": 6}, sweep[5]
assert verdict is None, verdict
print("CONTROLLED-SWEEP-OK")
PYEOF
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTROLLED-SWEEP-OK"* ]]
}

@test "normal: eval --report prints the first separable floor when negatives outscore the low floors" {
  make_wiki
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  python3 - "$BATS_TEST_TMPDIR/sep.json" <<'PYEOF'
import json, sys
cases = [{"query": "Choosing a pagination cursor for a list endpoint.", "expected_page_id": "alpha-cat-two", "source": "t"}]
cases += [{"query": "Rotating api keys for a service account.", "expected_page_id": None, "source": "t"}] * 2
cases += [{"query": "Whether a spacecraft trajectory needs a mid-course correction burn", "expected_page_id": None, "source": "t"}] * 8
json.dump(cases, open(sys.argv[1], "w"))
PYEOF
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/sep.json" --k 5 --report
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 28 ]
  [ "${lines[11]}" = '{"floor": "0.60", "recall": "1.00", "fpr": "0.20", "top1_hits": 1}' ]
  [ "${lines[15]}" = '{"floor": "0.68", "recall": "1.00", "fpr": "0.20", "top1_hits": 1}' ]
  [ "${lines[16]}" = '{"floor": "0.70", "recall": "1.00", "fpr": "0.00", "top1_hits": 1}' ]
  [ "${lines[20]}" = '{"floor": "0.78", "recall": "0.00", "fpr": "0.00", "top1_hits": 0}' ]
  [ "${lines[27]}" = "floor: 0.70 recall 1.00 fpr 0.00" ]

  # the classic call over the same file counts the one positive only
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/sep.json" --k 5
  [ "$status" -eq 0 ]
  [ "$output" = "recall@5 1.00 hits 1 total 1" ]
}

# Shared by the two `state:` tests: one python program (one detector, one
# trigger-chunk lookup) with three modes, so the reverse control exercises the
# very code the real-file test runs.
#   check <cases>                      exit 1 when a positive copies >= 8 consecutive words of its target's trigger chunk
#   shape <cases>                      exit 1 when the calibration file breaks the size/schema/id contract
#   plant <cases> <out> <index> <how>  write <out> with case <index>'s query replaced by head8 | tail9 | tail7 words of its target chunk
paraphrase_py() {
  python3 - "${BATS_TEST_DIRNAME}/.." "$@" <<'PYEOF'
import importlib.util, json, re, sys
from pathlib import Path

sys.dont_write_bytecode = True  # importing the plugin script must not leave scripts/__pycache__
repo_root = Path(sys.argv[1])
mode = sys.argv[2]
wiki_root = repo_root / "wiki"

spec = importlib.util.spec_from_file_location("wiki_index", repo_root / "scripts" / "wiki-index.py")
wiki_index = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wiki_index)
load_when = wiki_index.load_when_map(wiki_root)

def words_of(text):
    return re.findall(r"[a-z0-9]+", text.lower())

def windows(text, n=8):
    words = words_of(text)
    return {" ".join(words[i:i + n]) for i in range(len(words) - n + 1)}

def page_doc(path_str):
    doc = wiki_index.parse_page(repo_root / path_str, wiki_root)
    assert doc is not None, "unreadable page: %s" % path_str
    return doc

def trigger_chunk_for(path_str):
    doc = page_doc(path_str)
    chunks = wiki_index.chunk_page(doc, load_when.get(doc["path"]))
    return next(c for c in chunks if c["section"] == "trigger" and c["ordinal"] == 0)["text"]

cases = json.load(open(sys.argv[3], encoding="utf-8"))

if mode == "check":
    positives = [(i, c) for i, c in enumerate(cases) if c.get("expected_page_id")]
    violations = []
    for i, case in positives:
        overlap = windows(case["query"]) & windows(trigger_chunk_for(case["path"]))
        if overlap:
            violations.append((i, sorted(overlap)[0]))
    for i, window in violations:
        print("case %d copies its target's trigger text: %r" % (i, window), file=sys.stderr)
    print("checked %d cases (%d positive), %d violations" % (len(cases), len(positives), len(violations)))
    sys.exit(1 if violations else 0)

if mode == "shape":
    problems = []
    positives = [c for c in cases if c.get("expected_page_id")]
    negatives = [c for c in cases if not c.get("expected_page_id")]
    if len(cases) < 50 or len(positives) < 35 or len(negatives) < 15:
        problems.append("size %d/%d/%d is below 50/35/15" % (len(cases), len(positives), len(negatives)))
    for i, c in enumerate(cases):
        if not c.get("source"):
            problems.append("case %d has no source" % i)
    for i, c in enumerate(cases):
        if c.get("expected_page_id") and page_doc(c["path"])["page_id"] != c["expected_page_id"]:
            problems.append("case %d: %s does not hold page %s" % (i, c["path"], c["expected_page_id"]))
    for problem in problems:
        print(problem, file=sys.stderr)
    print("shape %d/%d/%d, %d problems" % (len(cases), len(positives), len(negatives), len(problems)))
    sys.exit(1 if problems else 0)

if mode == "plant":
    out_path, index, how = sys.argv[4], int(sys.argv[5]), sys.argv[6]
    words = words_of(trigger_chunk_for(cases[index]["path"]))
    # the domain index carries a row for this page, so the embedded trigger chunk must end with its "Load when:" sentence
    assert "load when" in " ".join(words), "trigger chunk lacks the Load when tail"
    picked = {"head8": words[:8], "tail9": words[-9:], "tail7": words[-7:]}[how]
    cases[index]["query"] = "task " + " ".join(picked)
    json.dump(cases, open(out_path, "w", encoding="utf-8"))
    sys.exit(0)

sys.exit("unknown mode: %s" % mode)
PYEOF
}

@test "state: the paraphrase detector flags copied trigger and load-when text but not a 7-word overlap (reverse control)" {
  cases="${BATS_TEST_DIRNAME}/fixtures/wiki-retrieval-calibration.json"
  [ -f "$cases" ]
  # known-good: the real file is clean
  run paraphrase_py check "$cases"
  [ "$status" -eq 0 ]
  # known-bad: 8 copied words from the page's trigger text, and 9 copied
  # words from the tail that carries the domain index's "Load when:" sentence
  for how in head8 tail9; do
    run paraphrase_py plant "$cases" "$BATS_TEST_TMPDIR/planted-$how.json" 20 "$how"
    [ "$status" -eq 0 ]
    run paraphrase_py check "$BATS_TEST_TMPDIR/planted-$how.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"case 20 copies its target's trigger text"* ]]
  done
  # boundary: 7 copied words stay under the 8-word window
  run paraphrase_py plant "$cases" "$BATS_TEST_TMPDIR/planted-tail7.json" 20 tail7
  [ "$status" -eq 0 ]
  run paraphrase_py check "$BATS_TEST_TMPDIR/planted-tail7.json"
  [ "$status" -eq 0 ]
}

@test "state: the calibration file keeps its size, source and id contract and every positive paraphrases its target" {
  cases="${BATS_TEST_DIRNAME}/fixtures/wiki-retrieval-calibration.json"
  [ -f "$cases" ]
  run paraphrase_py shape "$cases"
  [ "$status" -eq 0 ]
  run paraphrase_py check "$cases"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(35 positive), 0 violations"* ]]

  # negative controls: an emptied file, a row without its source, and a row
  # whose id does not match its page must each fail the shape check
  printf '[]' > "$BATS_TEST_TMPDIR/empty.json"
  run paraphrase_py shape "$BATS_TEST_TMPDIR/empty.json"
  [ "$status" -eq 1 ]
  python3 - "$cases" "$BATS_TEST_TMPDIR" <<'PYEOF'
import json, sys
cases = json.load(open(sys.argv[1]))
nosrc = json.loads(json.dumps(cases)); del nosrc[3]["source"]
badid = json.loads(json.dumps(cases)); badid[20]["expected_page_id"] = "wrong-page-id"
json.dump(nosrc, open(sys.argv[2] + "/nosrc.json", "w"))
json.dump(badid, open(sys.argv[2] + "/badid.json", "w"))
PYEOF
  run paraphrase_py shape "$BATS_TEST_TMPDIR/nosrc.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"case 3 has no source"* ]]
  run paraphrase_py shape "$BATS_TEST_TMPDIR/badid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"case 20:"* ]]
}
