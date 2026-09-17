#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Tests for the query surface of the bundled-wiki index: the `search` / `page` /
# `eval` CLI contract (scripts/wiki-index.py), the fail-open launcher
# (scripts/wiki-mcp-launch.sh) with .mcp.json, the two-tool stdio adapter
# (scripts/wiki-mcp.py), and the retrieval eval set.
# DEV_LOOP_WIKI_EMBED_MODEL=test-hash keeps every always-run case offline.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/wiki-index.py"
  LAUNCH="${BATS_TEST_DIRNAME}/../scripts/wiki-mcp-launch.sh"
  ADAPTER="${BATS_TEST_DIRNAME}/../scripts/wiki-mcp.py"
  MCP_JSON="${BATS_TEST_DIRNAME}/../.mcp.json"
  HOME_REAL="$HOME"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  # uv resolves both its package cache and its managed interpreters from HOME,
  # which the line above just moved to a scratch dir. Without these two the
  # uv-backed cases below could only ever skip: uv would fall back to a
  # different interpreter whose offline resolution is not in the cache.
  export UV_CACHE_DIR="${UV_CACHE_DIR:-$HOME_REAL/.cache/uv}"
  export UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-$HOME_REAL/.local/share/uv/python}"
  export DEV_LOOP_WIKI_INDEX_DIR="$BATS_TEST_TMPDIR/idx"
  export DEV_LOOP_WIKI_ROOT="$BATS_TEST_TMPDIR/wiki"
  export DEV_LOOP_WIKI_EMBED_MODEL=test-hash
  unset DEV_LOOP_WIKI_INDEX DEV_LOOP_WIKI_LOCK_TTL DEV_LOOP_WIKI_RUN_ID DEV_LOOP_WIKI_DEBUG
  IDX="$DEV_LOOP_WIKI_INDEX_DIR"
  WIKI="$DEV_LOOP_WIKI_ROOT"
  PINS=(--with 'sqlite-vec>=0.1.6,<0.2')

  SHIM="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$SHIM"
  SHIM_LOG="$BATS_TEST_TMPDIR/uv.log"
  cat > "$SHIM/uv" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$SHIM_LOG"
exit \${UV_SHIM_RC:-0}
EOF
  chmod +x "$SHIM/uv"
}

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

build_index() {
  make_wiki
  python3 "$SCRIPT" --build
}

# uv with the sqlite-vec wheel already in its cache — the vec0 half of the
# scan/vec0 contract cannot be exercised without it.
vec_available() {
  command -v uv >/dev/null 2>&1 || return 1
  uv run --offline "${PINS[@]}" python -c 'import sqlite_vec' >/dev/null 2>&1
}

# --- search / page / eval ---

@test "normal: search ranks the page whose trigger text is queried" {
  build_index
  run python3 "$SCRIPT" search --query "rotating api keys for a service account" --k 3 --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.[0].page_id')" = "alpha-cat-one" ]
  [ "$(printf '%s' "$output" | jq -r '.[0].section')" = "trigger" ]
  # the documented row shape, exactly — t9-rag-skills binds to these keys
  [ "$(printf '%s' "$output" | jq -r '.[0] | keys | join(",")')" = "confidence,last_verified,page_id,path,score,section,snippet" ]
  [ "$(printf '%s' "$output" | jq -r '.[0].path')" = "alpha/cat/one.md" ]
  [ "$(printf '%s' "$output" | jq -r '.[0].confidence')" = "verified" ]
  [ "$(printf '%s' "$output" | jq -r '.[0].last_verified')" = "2026-01-01" ]
  # negative control: an unrelated page did not take the top slot
  [ "$(printf '%s' "$output" | jq -r '.[0].page_id')" != "beta-cat-three" ]
}

@test "normal: search returns a snippet, never the page body" {
  build_index
  run python3 "$SCRIPT" search --query "rotating api keys for a service account" --k 3 --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r 'all(.[]; .snippet | length <= 240)')" = "true" ]
  # negative control: the frontmatter/body markers never appear in a snippet
  [ "$(printf '%s' "$output" | jq -r 'any(.[]; .snippet | test("## Do this"))')" = "false" ]
}

@test "normal: a domain filter keeps only that domain's pages" {
  build_index
  run python3 "$SCRIPT" search --query "retrying a webhook delivery" --k 5 --domain beta --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r 'length > 0')" = "true" ]
  [ "$(printf '%s' "$output" | jq -r 'all(.[]; .page_id | startswith("beta-"))')" = "true" ]

  # negative control: the same query filtered to alpha returns no beta page
  run python3 "$SCRIPT" search --query "retrying a webhook delivery" --k 5 --domain alpha --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r 'any(.[]; .page_id | startswith("beta-"))')" = "false" ]
}

@test "error: search with no index returns an empty array and exits 0" {
  make_wiki
  [ ! -f "$IDX/wiki.db" ]
  run python3 "$SCRIPT" search --query "anything at all" --k 5 --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
  # negative control: after a build the same query is no longer empty
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  run python3 "$SCRIPT" search --query "rotating api keys" --k 5 --json
  [ "$output" != "[]" ]
}

@test "error: search with an unreadable index returns an empty array" {
  build_index
  printf 'not a database' > "$IDX/wiki.db"
  run python3 "$SCRIPT" search --query "rotating api keys" --k 5 --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "boundary: k=0, k above the cap, an unknown domain, and an empty query" {
  build_index

  run python3 "$SCRIPT" search --query "rotating api keys" --k 0 --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]

  run python3 "$SCRIPT" search --query "rotating api keys" --k 51 --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r 'length <= 50')" = "true" ]
  # negative control: the cap did not empty the result
  [ "$(printf '%s' "$output" | jq -r 'length > 0')" = "true" ]

  run python3 "$SCRIPT" search --query "rotating api keys" --k 5 --domain nosuchdomain --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]

  run python3 "$SCRIPT" search --query "" --k 5 --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]

  run python3 "$SCRIPT" search --query "!!! ??? ..." --k 5 --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "normal: page prints the full body of one page" {
  build_index
  run python3 "$SCRIPT" page --page-id alpha-cat-one
  [ "$status" -eq 0 ]
  [[ "$output" == *"## When this applies"* ]]
  [[ "$output" == *"## Do this"* ]]
  [[ "$output" == *"id: alpha-cat-one"* ]]
  # negative control: it is this page's body, not another's
  [[ "$output" != *"Retrying a webhook delivery"* ]]
}

@test "error: page with an unknown page_id exits 1" {
  build_index
  run python3 "$SCRIPT" page --page-id nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown page_id: nope"* ]]
}

@test "error: page with no index exits 1" {
  make_wiki
  run python3 "$SCRIPT" page --page-id alpha-cat-one
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown page_id: alpha-cat-one"* ]]
}

@test "contract: the pure-python scan and the vec0 KNN rank identically" {
  vec_available || skip "uv with a cached sqlite-vec wheel is required for the vec0 half"
  make_wiki
  run uv run --offline "${PINS[@]}" python "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ "$(sqlite3 "$IDX/wiki.db" "select value from meta where key='vec0'")" = "1" ]

  scan=$(uv run --offline "${PINS[@]}" python "$SCRIPT" search --query "rotating api keys for a service account" --k 5 --engine scan --json | jq -r '[.[] | .page_id + ":" + .section] | join(",")')
  vec=$(uv run --offline "${PINS[@]}" python "$SCRIPT" search --query "rotating api keys for a service account" --k 5 --engine vec0 --json | jq -r '[.[] | .page_id + ":" + .section] | join(",")')
  [ -n "$scan" ]
  [ "$scan" = "$vec" ]

  # negative control: the domain-filtered vec0 result is a different sequence
  vecbeta=$(uv run --offline "${PINS[@]}" python "$SCRIPT" search --query "rotating api keys for a service account" --k 5 --engine vec0 --domain beta --json | jq -r '[.[] | .page_id + ":" + .section] | join(",")')
  [ "$vecbeta" != "$scan" ]
}

@test "normal: eval prints recall over a cases file" {
  build_index
  cat > "$BATS_TEST_TMPDIR/cases.json" <<'EOF'
[
  {"query": "Rotating api keys for a service account.", "expected_page_id": "alpha-cat-one"},
  {"query": "Choosing a pagination cursor for a list endpoint.", "expected_page_id": "alpha-cat-two"},
  {"query": "Retrying a webhook delivery after a timeout.", "expected_page_id": "beta-cat-three"}
]
EOF
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/cases.json" --k 5
  [ "$status" -eq 0 ]
  [ "$output" = "recall@5 1.00 hits 3 total 3" ]

  # At k=1 the ranking itself is what decides, so the negative control below
  # measures retrieval quality rather than the size of the fixture.
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/cases.json" --k 1
  [ "$status" -eq 0 ]
  [ "$output" = "recall@1 1.00 hits 3 total 3" ]

  # negative control: the same queries with expectations rotated by one must
  # not score the same — otherwise the eval would pass on any ranking at all
  jq -c '[ .[0].query, .[1].query, .[2].query ] as $q | [ {query: $q[0], expected_page_id: .[1].expected_page_id}, {query: $q[1], expected_page_id: .[2].expected_page_id}, {query: $q[2], expected_page_id: .[0].expected_page_id} ]' "$BATS_TEST_TMPDIR/cases.json" > "$BATS_TEST_TMPDIR/rotated.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/rotated.json" --k 1
  [ "$status" -eq 0 ]
  [ "$output" = "recall@1 0.00 hits 0 total 3" ]
}

@test "error: eval without an index exits 4" {
  make_wiki
  printf '%s\n' '[{"query": "x", "expected_page_id": "y"}]' > "$BATS_TEST_TMPDIR/cases.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/cases.json" --k 5
  [ "$status" -eq 4 ]
  [[ "$output" == *"no index"* ]]
}

@test "boundary: eval over an empty cases file reports zero of zero" {
  build_index
  printf '%s\n' '[]' > "$BATS_TEST_TMPDIR/empty.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/empty.json" --k 5
  [ "$status" -eq 0 ]
  [ "$output" = "recall@5 0.00 hits 0 total 0" ]
}

# --- launch script and .mcp.json ---

# A PATH that carries the ordinary utilities but no uv. Skipped rather than
# guessed at if this runner happens to install uv there.
bare_path_without_uv() {
  PATH=/usr/bin:/bin command -v uv >/dev/null 2>&1 && return 1
  return 0
}

@test "normal: serve runs uv with the three pins and the adapter, without --python" {
  PATH="$SHIM:$PATH" run bash "$LAUNCH"
  [ "$status" -eq 0 ]
  [ -f "$SHIM_LOG" ]
  line=$(tail -1 "$SHIM_LOG")
  [[ "$line" == "run "* ]]
  [[ "$line" == *"--with sqlite-vec>=0.1.6,<0.2"* ]]
  [[ "$line" == *"--with fastembed>=0.7,<1"* ]]
  [[ "$line" == *"--with mcp>=2,<3"* ]]
  [[ "$line" == *"/scripts/wiki-mcp.py" ]]
  # no interpreter pin: uv resolves one against the packages' own floor
  [[ "$line" != *"--python"* ]]

  # negative control: a copy that pins an interpreter fails that same assertion
  cp "$LAUNCH" "$BATS_TEST_TMPDIR/pinned.sh"
  sed 's/uv run "${PINS\[@\]}"/uv run --python 3.12 "${PINS[@]}"/' "$LAUNCH" > "$BATS_TEST_TMPDIR/pinned.sh"
  : > "$SHIM_LOG"
  PATH="$SHIM:$PATH" run bash "$BATS_TEST_TMPDIR/pinned.sh"
  [ "$status" -eq 0 ]
  line=$(tail -1 "$SHIM_LOG")
  [[ "$line" == *"--python"* ]]
}

@test "normal: the index verb forwards its arguments to the indexer" {
  PATH="$SHIM:$PATH" run bash "$LAUNCH" index --incremental
  [ "$status" -eq 0 ]
  line=$(tail -1 "$SHIM_LOG")
  [[ "$line" == *"/scripts/wiki-index.py --incremental" ]]
  # negative control: it did not launch the MCP adapter instead
  [[ "$line" != *"wiki-mcp.py"* ]]

  PATH="$SHIM:$PATH" run bash "$LAUNCH" index --build
  [ "$status" -eq 0 ]
  [[ "$(tail -1 "$SHIM_LOG")" == *"/scripts/wiki-index.py --build" ]]
}

@test "error: without uv the launcher exits 0 and says nothing" {
  bare_path_without_uv || skip "this runner resolves uv from /usr/bin:/bin"
  PATH=/usr/bin:/bin run bash "$LAUNCH"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$SHIM_LOG" ]
}

@test "error: a failing uv is swallowed, and explained only under the debug flag" {
  UV_SHIM_RC=7 PATH="$SHIM:$PATH" run bash "$LAUNCH"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  UV_SHIM_RC=7 DEV_LOOP_WIKI_DEBUG=1 PATH="$SHIM:$PATH" run bash "$LAUNCH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exited 7 (fail-open)"* ]]
  # negative control: a succeeding uv prints nothing even with the debug flag
  DEV_LOOP_WIKI_DEBUG=1 PATH="$SHIM:$PATH" run bash "$LAUNCH"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "boundary: the off switch stops the launcher before it calls uv" {
  for value in 0 off false; do
    DEV_LOOP_WIKI_INDEX="$value" PATH="$SHIM:$PATH" run bash "$LAUNCH"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  [ ! -f "$SHIM_LOG" ]
  # negative control: left on, the same invocation does reach uv
  DEV_LOOP_WIKI_INDEX=1 PATH="$SHIM:$PATH" run bash "$LAUNCH"
  [ "$status" -eq 0 ]
  [ -f "$SHIM_LOG" ]
}

@test "boundary: an unknown verb exits 0 without calling uv" {
  PATH="$SHIM:$PATH" run bash "$LAUNCH" bogus
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$SHIM_LOG" ]

  DEV_LOOP_WIKI_DEBUG=1 PATH="$SHIM:$PATH" run bash "$LAUNCH" bogus
  [ "$status" -eq 0 ]
  [[ "$output" == *"unknown verb bogus"* ]]
  [ ! -f "$SHIM_LOG" ]
}

@test "normal: .mcp.json registers dev-loop-wiki as a stdio server through the launcher" {
  run jq -e '.mcpServers["dev-loop-wiki"].type == "stdio"' "$MCP_JSON"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.mcpServers["dev-loop-wiki"].command' "$MCP_JSON")" = "bash" ]
  [[ "$(jq -r '.mcpServers["dev-loop-wiki"].args[0]' "$MCP_JSON")" == '${CLAUDE_PLUGIN_ROOT}'*"/scripts/wiki-mcp-launch.sh" ]]
  [ "$(jq -r '.mcpServers["dev-loop-wiki"].args[1]' "$MCP_JSON")" = "serve" ]
  # exactly one server is registered here
  [ "$(jq -r '.mcpServers | length' "$MCP_JSON")" = "1" ]
  # every relayed env var carries a default, so an unset var cannot become the
  # literal string "${VAR}" inside the server process
  run jq -e '.mcpServers["dev-loop-wiki"].env | to_entries | all(.value | test(":-"))' "$MCP_JSON"
  [ "$status" -eq 0 ]

  # negative control: a copy with one default stripped fails that assertion
  jq '.mcpServers["dev-loop-wiki"].env.DEV_LOOP_WIKI_INDEX = "${DEV_LOOP_WIKI_INDEX}"' "$MCP_JSON" > "$BATS_TEST_TMPDIR/mcp.json"
  run jq -e '.mcpServers["dev-loop-wiki"].env | to_entries | all(.value | test(":-"))' "$BATS_TEST_TMPDIR/mcp.json"
  [ "$status" -ne 0 ]
}

@test "boundary: the launcher path in .mcp.json exists in the repo" {
  rel=$(jq -r '.mcpServers["dev-loop-wiki"].args[0]' "$MCP_JSON" | sed 's|^${CLAUDE_PLUGIN_ROOT}/||')
  [ -f "${BATS_TEST_DIRNAME}/../$rel" ]
  # negative control: a path the manifest does not name is not asserted to exist
  [ ! -f "${BATS_TEST_DIRNAME}/../scripts/wiki-mcp-launch-nope.sh" ]
}

# --- mcp adapter (real stdio handshake) ---

MCP_INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"bats","version":"1"}}}'
MCP_READY='{"jsonrpc":"2.0","method":"notifications/initialized"}'

mcp_available() {
  command -v uv >/dev/null 2>&1 || return 1
  uv run --offline --with 'mcp>=2,<3' python -c 'import mcp' >/dev/null 2>&1
}

# Drive one stdio session: every argument is a JSON-RPC line sent after the
# handshake. stdin is held open briefly because tools/call answers come back
# asynchronously and a closed stdin shuts the server down mid-flight.
mcp_session() {
  local adapter="$1"; shift
  { printf '%s\n' "$MCP_INIT" "$MCP_READY" "$@"; sleep 4; } \
    | uv run --offline --with 'sqlite-vec>=0.1.6,<0.2' --with 'mcp>=2,<3' python "$adapter" 2>/dev/null
}

@test "normal: tools/list exposes exactly wiki_search and wiki_page" {
  mcp_available || skip "uv with a cached mcp wheel is required for the stdio handshake"
  build_index
  out=$(mcp_session "$ADAPTER" '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')
  [ -n "$out" ]
  [ "$(printf '%s' "$out" | jq -r 'select(.id==2) | .result.tools | length')" = "2" ]
  [ "$(printf '%s' "$out" | jq -r 'select(.id==2) | [.result.tools[].name] | sort | join(",")')" = "wiki_page,wiki_search" ]

  # negative control: a copy carrying a third tool reports three
  scripts_dir=$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd -P)
  {
    sed "s|^_HERE = .*|_HERE = pathlib.Path('$scripts_dir')|" "$ADAPTER" \
      | sed '/^if __name__ == "__main__":/,$d'
    cat <<'PYEOF'
@server.tool()
def wiki_extra(x: str) -> str:
    """A third tool, present only to prove the count assertion can fail."""
    return x


print("dev-loop-wiki: serving stdio", file=sys.stderr)
server.run(transport="stdio")
PYEOF
  } > "$BATS_TEST_TMPDIR/three.py"
  out=$(mcp_session "$BATS_TEST_TMPDIR/three.py" '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')
  [ "$(printf '%s' "$out" | jq -r 'select(.id==2) | .result.tools | length')" = "3" ]
}

@test "normal: wiki_search over stdio returns the documented rows" {
  mcp_available || skip "uv with a cached mcp wheel is required for the stdio handshake"
  build_index
  out=$(mcp_session "$ADAPTER" '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"wiki_search","arguments":{"query":"rotating api keys for a service account","k":2}}}')
  frame=$(printf '%s' "$out" | jq -c 'select(.id==3)')
  [ -n "$frame" ]
  [ "$(printf '%s' "$frame" | jq -r '.result.isError // false')" = "false" ]
  [ "$(printf '%s' "$frame" | jq -r '.result.structuredContent.result[0].page_id')" = "alpha-cat-one" ]
  [ "$(printf '%s' "$frame" | jq -r '.result.structuredContent.result[0] | keys | join(",")')" = "confidence,last_verified,page_id,path,score,section,snippet" ]
  [ "$(printf '%s' "$frame" | jq -r '.result.structuredContent.result | length')" = "2" ]
  # negative control: no row carries a full page body
  [ "$(printf '%s' "$frame" | jq -r 'any(.result.structuredContent.result[]; .snippet | test("## Sources"))')" = "false" ]
}

@test "boundary: wiki_search with no index is an empty result, not an error" {
  mcp_available || skip "uv with a cached mcp wheel is required for the stdio handshake"
  make_wiki
  [ ! -f "$IDX/wiki.db" ]
  out=$(mcp_session "$ADAPTER" '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"wiki_search","arguments":{"query":"anything","k":5}}}')
  frame=$(printf '%s' "$out" | jq -c 'select(.id==3)')
  [ -n "$frame" ]
  [ "$(printf '%s' "$frame" | jq -r '.result.isError // false')" = "false" ]
  [ "$(printf '%s' "$frame" | jq -r '.result.structuredContent.result | length')" = "0" ]
}

@test "error: wiki_page with an unknown id is an is_error result naming the id" {
  mcp_available || skip "uv with a cached mcp wheel is required for the stdio handshake"
  build_index
  out=$(mcp_session "$ADAPTER" \
    '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"wiki_page","arguments":{"page_id":"nope"}}}' \
    '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"wiki_page","arguments":{"page_id":"alpha-cat-one"}}}')

  bad=$(printf '%s' "$out" | jq -c 'select(.id==4)')
  [ "$(printf '%s' "$bad" | jq -r '.result.isError')" = "true" ]
  [[ "$(printf '%s' "$bad" | jq -r '.result.content[0].text')" == *"unknown page_id: nope"* ]]

  # negative control: a real page_id is not an error and returns the body
  good=$(printf '%s' "$out" | jq -c 'select(.id==5)')
  [ "$(printf '%s' "$good" | jq -r '.result.isError // false')" = "false" ]
  [[ "$(printf '%s' "$good" | jq -r '.result.content[0].text')" == *"## When this applies"* ]]
}

@test "boundary: the adapter writes nothing to stdout before the first protocol frame" {
  mcp_available || skip "uv with a cached mcp wheel is required for the stdio handshake"
  build_index
  run --separate-stderr uv run --offline --with 'sqlite-vec>=0.1.6,<0.2' --with 'mcp>=2,<3' python "$ADAPTER" </dev/null
  [ -z "$output" ]
  [[ "$stderr" == *"serving stdio"* ]]
}

@test "always: the adapter loads the indexer by path and imports no legacy mcp module" {
  run grep -c 'spec_from_file_location("wiki_index"' "$ADAPTER"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  # the 2.x entry point, not the older fastmcp one
  run grep -c 'from mcp.server.mcpserver import MCPServer' "$ADAPTER"
  [ "$output" = "1" ]
  run grep -c 'mcp.server.fastmcp' "$ADAPTER"
  [ "$output" = "0" ]
  # negative control: a reworded copy on the old API is detected
  sed 's/from mcp.server.mcpserver import MCPServer/from mcp.server.fastmcp import FastMCP/' "$ADAPTER" > "$BATS_TEST_TMPDIR/legacy.py"
  run grep -c 'mcp.server.fastmcp' "$BATS_TEST_TMPDIR/legacy.py"
  [ "$output" = "1" ]
}

@test "always: the indexer imports no third-party module at import time" {
  # Load a copy, so neither the assertion nor the bytecode it might leave
  # depends on the shared checkout or on what else ran first.
  cp "$SCRIPT" "$BATS_TEST_TMPDIR/wiki-index.py"
  run python3 -c "
import importlib.util, pathlib, sys
sys.dont_write_bytecode = True
before = set(sys.modules)
spec = importlib.util.spec_from_file_location('wiki_index', '$BATS_TEST_TMPDIR/wiki-index.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
added = {m.split('.')[0] for m in set(sys.modules) - before}
third = added & {'fastembed', 'sqlite_vec', 'mcp', 'numpy', 'onnxruntime'}
print((','.join(sorted(third)) or 'none') + ' ' + str(pathlib.Path('$BATS_TEST_TMPDIR/__pycache__').exists()))
"
  [ "$status" -eq 0 ]
  [ "$output" = "none False" ]
  # negative control: those module names are the ones that would be reported
  run python3 -c "
import sys
added = {'fastembed', 'json'}
third = added & {'fastembed', 'sqlite_vec', 'mcp', 'numpy', 'onnxruntime'}
print(','.join(sorted(third)) or 'none')
"
  [ "$output" = "fastembed" ]
}

# --- retrieval eval set ---

CASES="${BATS_TEST_DIRNAME}/fixtures/wiki-retrieval-cases.json"
REAL_WIKI_REL="../wiki"

@test "always: the eval set holds 15 cases whose expected pages exist" {
  [ "$(jq -r 'length' "$CASES")" = "15" ]
  [ "$(jq -r '[.[].expected_page_id] | unique | length' "$CASES")" = "15" ]

  # every case names a real page whose frontmatter id is the expectation
  local i path want got
  for i in $(seq 0 14); do
    path=$(jq -r ".[$i].path" "$CASES")
    want=$(jq -r ".[$i].expected_page_id" "$CASES")
    [ -f "${BATS_TEST_DIRNAME}/../$path" ]
    got=$(sed -n 's/^id: *//p' "${BATS_TEST_DIRNAME}/../$path" | head -1)
    [ "$got" = "$want" ]
  done

  # at least one case per wiki domain, so a regression in one area shows up
  [ "$(jq -r '[.[].path | split("/")[1]] | unique | length' "$CASES")" = "10" ]

  # negative control: a page id that does not exist is not in the set
  run jq -e '.[] | select(.expected_page_id == "no-such-page-id")' "$CASES"
  [ "$status" -ne 0 ]
}

@test "always: test-hash self-retrieval over the real wiki finds every expected page" {
  local real_wiki="${BATS_TEST_DIRNAME}/$REAL_WIKI_REL"
  export DEV_LOOP_WIKI_ROOT="$real_wiki"
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ "$(jq -r '.pages | length' "$IDX/manifest.json")" -gt 200 ]

  # Query each expected page with its own trigger sentence: an index that
  # cannot retrieve a page by its own words is broken regardless of the model.
  local i path want first
  : > "$BATS_TEST_TMPDIR/self.json"
  {
    printf '['
    for i in $(seq 0 14); do
      path=$(jq -r ".[$i].path" "$CASES")
      want=$(jq -r ".[$i].expected_page_id" "$CASES")
      first=$(awk '/^## When this applies/{f=1;next} f && /^## /{exit} f && NF {printf "%s ", $0; got=1; next} got {exit}' "${BATS_TEST_DIRNAME}/../$path")
      [ -n "$first" ]
      [ "$i" -gt 0 ] && printf ','
      jq -nc --arg q "$first" --arg p "$want" '{query: $q, expected_page_id: $p}'
    done
    printf ']'
  } > "$BATS_TEST_TMPDIR/self.json"

  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/self.json" --k 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"hits 15 total 15"* ]]

  # negative control: rotate the expectations by one — the same ranking must
  # then miss most of them, proving the eval reads the ranking and not the file
  jq -c '[ . as $c | range(length) | {query: $c[.].query, expected_page_id: $c[(. + 1) % ($c | length)].expected_page_id} ]' "$BATS_TEST_TMPDIR/self.json" > "$BATS_TEST_TMPDIR/rotated.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/rotated.json" --k 5
  [ "$status" -eq 0 ]
  hits=$(printf '%s' "$output" | awk '{print $4}')
  [ "$hits" -le 3 ]
}

@test "real model: Recall@5 over the eval set is at least 0.8" {
  local real_idx="${DEV_LOOP_WIKI_EVAL_INDEX_DIR:-$HOME_REAL/.dev-loop/wiki-index}"
  local model="BAAI/bge-small-en-v1.5"

  command -v uv >/dev/null 2>&1 \
    || skip "no uv, so the $model index cannot be queried"
  [ -f "$real_idx/wiki.db" ] \
    || skip "no $model index at $real_idx (run hooks/wiki-index.sh once to build it)"
  [ "$(sqlite3 "$real_idx/wiki.db" "select value from meta where key='model'")" = "$model" ] \
    || skip "the index at $real_idx was not built with $model"
  compgen -G "$real_idx/models/*bge-small-en-v1.5*" > /dev/null \
    || skip "the $model weights are not cached under $real_idx/models"

  run env DEV_LOOP_WIKI_INDEX_DIR="$real_idx" \
      DEV_LOOP_WIKI_ROOT="${BATS_TEST_DIRNAME}/$REAL_WIKI_REL" \
      DEV_LOOP_WIKI_EMBED_MODEL="$model" \
      uv run --offline --with 'sqlite-vec>=0.1.6,<0.2' --with 'fastembed>=0.7,<1' \
      python "$SCRIPT" eval --cases "$CASES" --k 5
  [ "$status" -eq 0 ]
  echo "# measured: $output" >&3

  hits=$(printf '%s' "$output" | awk '{print $4}')
  total=$(printf '%s' "$output" | awk '{print $6}')
  [ "$total" -eq 15 ]
  [ "$hits" -ge 12 ]

  # negative control: rotated expectations must score strictly worse, so a
  # threshold met by an indiscriminate ranking cannot pass this test
  jq -c '[ . as $c | range(length) | {query: $c[.].query, expected_page_id: $c[(. + 1) % ($c | length)].expected_page_id} ]' "$CASES" > "$BATS_TEST_TMPDIR/rot15.json"
  run env DEV_LOOP_WIKI_INDEX_DIR="$real_idx" \
      DEV_LOOP_WIKI_ROOT="${BATS_TEST_DIRNAME}/$REAL_WIKI_REL" \
      DEV_LOOP_WIKI_EMBED_MODEL="$model" \
      uv run --offline --with 'sqlite-vec>=0.1.6,<0.2' --with 'fastembed>=0.7,<1' \
      python "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/rot15.json" --k 5
  [ "$status" -eq 0 ]
  rotated_hits=$(printf '%s' "$output" | awk '{print $4}')
  [ "$rotated_hits" -lt "$hits" ]
}

@test "boundary: loading the indexer by path leaves no __pycache__ in the plugin" {
  cp "$SCRIPT" "$BATS_TEST_TMPDIR/wiki-index.py"

  run python3 -c "
import sys, importlib.util, pathlib
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('wiki_index', '$BATS_TEST_TMPDIR/wiki-index.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print(pathlib.Path('$BATS_TEST_TMPDIR/__pycache__').exists())
"
  [ "$status" -eq 0 ]
  [ "$output" = "False" ]

  # negative control: the same load without the guard does create the directory
  run python3 -c "
import importlib.util, pathlib
spec = importlib.util.spec_from_file_location('wiki_index', '$BATS_TEST_TMPDIR/wiki-index.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print(pathlib.Path('$BATS_TEST_TMPDIR/__pycache__').exists())
"
  [ "$output" = "True" ]

  # and the adapter sets that guard before it loads the indexer
  guard=$(grep -n 'sys.dont_write_bytecode = True' "$ADAPTER" | cut -d: -f1)
  load=$(grep -n 'spec.loader.exec_module' "$ADAPTER" | cut -d: -f1)
  [ -n "$guard" ]
  [ "$guard" -lt "$load" ]
}

@test "error: an unavailable embedding backend degrades search to an empty list" {
  build_index
  # Point the stored index at the real model while running under a python3 that
  # has no fastembed: this is the "broken model download" fail-open path.
  run python3 -c "import fastembed"
  [ "$status" -ne 0 ]
  sqlite3 "$IDX/wiki.db" "update meta set value='BAAI/bge-small-en-v1.5' where key='model'"

  run python3 "$SCRIPT" search --query "rotating api keys" --k 5 --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]

  # eval degrades the same way rather than crashing
  printf '%s\n' '[{"query": "rotating api keys", "expected_page_id": "alpha-cat-one"}]' > "$BATS_TEST_TMPDIR/c.json"
  run python3 "$SCRIPT" eval --cases "$BATS_TEST_TMPDIR/c.json" --k 5
  [ "$status" -eq 0 ]
  [ "$output" = "recall@5 0.00 hits 0 total 1" ]

  # negative control: restoring the model the index was built with brings the
  # same query back, so the empty result came from the backend, not the data
  sqlite3 "$IDX/wiki.db" "update meta set value='test-hash' where key='model'"
  run python3 "$SCRIPT" search --query "rotating api keys" --k 5 --json
  [ "$status" -eq 0 ]
  [ "$output" != "[]" ]
}
