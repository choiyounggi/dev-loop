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
