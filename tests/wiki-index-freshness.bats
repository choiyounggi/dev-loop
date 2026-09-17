#!/usr/bin/env bats
# Tests for the freshness half of the bundled-wiki index: `--status` (the one
# token hooks/wiki-index.sh branches on), `--incremental`, the build lock, and
# the SessionStart hook itself. Stdlib python3 only; test-hash keeps it offline.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/wiki-index.py"
  HOOK="${BATS_TEST_DIRNAME}/../hooks/wiki-index.sh"
  # Absolute, so the stripped-PATH cases below can still start a shell.
  BASH_BIN=$(command -v bash)
  HOME_REAL="$HOME"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export DEV_LOOP_WIKI_INDEX_DIR="$BATS_TEST_TMPDIR/idx"
  export DEV_LOOP_WIKI_ROOT="$BATS_TEST_TMPDIR/wiki"
  export DEV_LOOP_WIKI_EMBED_MODEL=test-hash
  unset DEV_LOOP_WIKI_INDEX DEV_LOOP_WIKI_LOCK_TTL DEV_LOOP_WIKI_RUN_ID DEV_LOOP_WIKI_DEBUG
  IDX="$DEV_LOOP_WIKI_INDEX_DIR"
  WIKI="$DEV_LOOP_WIKI_ROOT"

  # A shim uv: the hook must detach its rebuild through the launcher, and the
  # log is how we observe which flag it chose without running a real build.
  SHIM="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$SHIM"
  SHIM_LOG="$BATS_TEST_TMPDIR/uv.log"
  cat > "$SHIM/uv" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$SHIM_LOG"
exit 0
EOF
  chmod +x "$SHIM/uv"
  export PATH="$SHIM:$PATH"
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

wait_for_file() {
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -e "$1" ] && return 0
    sleep 0.5
  done
  return 1
}

# --- --status ---

@test "normal: a just-built index reports fresh" {
  build_index
  run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
  # negative control: it is not claiming work is due
  [ "$output" != "full" ]
  [ "$output" != "incremental" ]
}

@test "normal: an absent manifest reports full" {
  build_index
  rm "$IDX/manifest.json"
  run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
}

@test "normal: an absent database reports full even with a manifest" {
  build_index
  rm "$IDX/wiki.db"
  run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
}

@test "normal: a plugin_version mismatch reports full" {
  build_index
  jq '.plugin_version = "0.0.0"' "$IDX/manifest.json" > "$IDX/m.tmp"
  mv "$IDX/m.tmp" "$IDX/manifest.json"
  run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
  # negative control: restoring the real version makes it fresh again
  jq --arg v "$(jq -r .version "${BATS_TEST_DIRNAME}/../.claude-plugin/plugin.json")" '.plugin_version = $v' "$IDX/manifest.json" > "$IDX/m.tmp"
  mv "$IDX/m.tmp" "$IDX/manifest.json"
  run python3 "$SCRIPT" --status
  [ "$output" = "fresh" ]
}

@test "normal: a model mismatch reports full" {
  build_index
  DEV_LOOP_WIKI_EMBED_MODEL=some-other-model run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
  # negative control: the model it was built with is still fresh
  run python3 "$SCRIPT" --status
  [ "$output" = "fresh" ]
}

@test "normal: an edited, an added, and a deleted page each report incremental" {
  build_index

  printf '%s\n' 'One more sentence.' >> "$WIKI/alpha/cat/two.md"
  run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "incremental" ]

  python3 "$SCRIPT" --build
  cp "$WIKI/alpha/cat/two.md" "$WIKI/alpha/cat/four.md"
  run python3 "$SCRIPT" --status
  [ "$output" = "incremental" ]

  python3 "$SCRIPT" --build
  rm "$WIKI/alpha/cat/four.md"
  run python3 "$SCRIPT" --status
  [ "$output" = "incremental" ]

  # negative control: rebuilding settles it back to fresh
  python3 "$SCRIPT" --build
  run python3 "$SCRIPT" --status
  [ "$output" = "fresh" ]
}

@test "boundary: a corrupted manifest reports full rather than failing" {
  build_index
  printf '{' > "$IDX/manifest.json"
  run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]

  # a manifest that is valid JSON but missing a required key is also full
  printf '%s\n' '{"model": "test-hash"}' > "$IDX/manifest.json"
  run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]

  # so is a JSON document that is not an object at all
  printf '%s\n' '[]' > "$IDX/manifest.json"
  run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
}

@test "boundary: the off switch reports disabled for 0, off, and false" {
  build_index
  for value in 0 off false OFF False; do
    DEV_LOOP_WIKI_INDEX="$value" run python3 "$SCRIPT" --status
    [ "$status" -eq 0 ]
    [ "$output" = "disabled" ]
  done
  # negative control: any other value leaves the feature on
  DEV_LOOP_WIKI_INDEX=1 run python3 "$SCRIPT" --status
  [ "$output" = "fresh" ]
  DEV_LOOP_WIKI_INDEX="" run python3 "$SCRIPT" --status
  [ "$output" = "fresh" ]
}

@test "boundary: a missing wiki root reports disabled" {
  DEV_LOOP_WIKI_ROOT="$BATS_TEST_TMPDIR/nope" run python3 "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [ "$output" = "disabled" ]
}

# --- lock ---

@test "error: a held lock refuses the build with exit 3 and leaves the index alone" {
  build_index
  before=$(shasum -a 256 "$IDX/wiki.db" | cut -d' ' -f1)

  mkdir "$IDX/.build.lock"
  printf 'other-run %s %s\n' "$$" "$(date +%s)" > "$IDX/.build.lock/owner"

  run python3 "$SCRIPT" --build
  [ "$status" -eq 3 ]
  [[ "$output" == *"held other-run"* ]]
  [ "$(shasum -a 256 "$IDX/wiki.db" | cut -d' ' -f1)" = "$before" ]

  # --incremental refuses the same way
  printf '%s\n' 'An edit that would need reindexing.' >> "$WIKI/alpha/cat/two.md"
  run python3 "$SCRIPT" --incremental
  [ "$status" -eq 3 ]

  # negative control: once the lock is gone the build runs
  rm -rf "$IDX/.build.lock"
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
}

@test "boundary: a lock past its TTL whose owner is dead is reclaimed" {
  build_index
  mkdir "$IDX/.build.lock"
  printf 'stale-run 999999 0\n' > "$IDX/.build.lock/owner"

  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  # the stale owner no longer holds it
  [ ! -e "$IDX/.build.lock" ]

  # negative control: a fresh lock owned by a live pid is NOT reclaimed
  mkdir "$IDX/.build.lock"
  printf 'live-run %s %s\n' "$$" "$(date +%s)" > "$IDX/.build.lock/owner"
  run python3 "$SCRIPT" --build
  [ "$status" -eq 3 ]
  rm -rf "$IDX/.build.lock"
}

@test "boundary: an expired lock whose owner is still alive is not stolen" {
  build_index
  mkdir "$IDX/.build.lock"
  # age far beyond the TTL, but the recorded pid is this live test process
  printf 'wrapper-run %s 0\n' "$$" > "$IDX/.build.lock/owner"
  DEV_LOOP_WIKI_LOCK_TTL=1 run python3 "$SCRIPT" --build
  [ "$status" -eq 3 ]
  [[ "$output" == *"held wrapper-run"* ]]
  rm -rf "$IDX/.build.lock"
}

@test "boundary: the same run id re-enters its own lock" {
  build_index
  mkdir "$IDX/.build.lock"
  printf 'my-run 999999 0\n' > "$IDX/.build.lock/owner"
  DEV_LOOP_WIKI_RUN_ID=my-run run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  # negative control: a different run id is refused against a live owner
  mkdir -p "$IDX/.build.lock"
  printf 'my-run %s %s\n' "$$" "$(date +%s)" > "$IDX/.build.lock/owner"
  DEV_LOOP_WIKI_RUN_ID=other-run run python3 "$SCRIPT" --build
  [ "$status" -eq 3 ]
  rm -rf "$IDX/.build.lock"
}

@test "error: a malformed owner file does not wedge the lock forever" {
  build_index
  mkdir "$IDX/.build.lock"
  printf 'garbage\n' > "$IDX/.build.lock/owner"
  run python3 "$SCRIPT" --build
  [ "$status" -eq 0 ]
  [ ! -e "$IDX/.build.lock" ]
}

# --- --incremental ---

@test "normal: --incremental re-embeds only the edited page" {
  build_index
  one_before=$(sqlite3 "$IDX/wiki.db" "select hex(embedding) from chunks where path='alpha/cat/one.md' and section='trigger'")
  two_sha_before=$(jq -r '.pages["alpha/cat/two.md"]' "$IDX/manifest.json")
  one_sha_before=$(jq -r '.pages["alpha/cat/one.md"]' "$IDX/manifest.json")
  [ -n "$one_before" ]

  printf '\n%s\n' 'Prefer a keyset cursor over a numeric offset.' >> "$WIKI/alpha/cat/two.md"
  run python3 "$SCRIPT" --incremental
  [ "$status" -eq 0 ]

  # the untouched page kept its exact vector
  [ "$(sqlite3 "$IDX/wiki.db" "select hex(embedding) from chunks where path='alpha/cat/one.md' and section='trigger'")" = "$one_before" ]
  # the edited page's manifest entry moved
  [ "$(jq -r '.pages["alpha/cat/two.md"]' "$IDX/manifest.json")" != "$two_sha_before" ]
  # negative control: the untouched page's manifest entry did not move
  [ "$(jq -r '.pages["alpha/cat/one.md"]' "$IDX/manifest.json")" = "$one_sha_before" ]
  # and the index is settled again
  run python3 "$SCRIPT" --status
  [ "$output" = "fresh" ]
}

@test "normal: --incremental indexes an added page without touching the others" {
  build_index
  before=$(sqlite3 "$IDX/wiki.db" "select count(*) from chunks where path='alpha/cat/one.md'")
  cp "$WIKI/alpha/cat/two.md" "$WIKI/alpha/cat/five.md"

  run python3 "$SCRIPT" --incremental
  [ "$status" -eq 0 ]
  [ "$(sqlite3 "$IDX/wiki.db" "select count(*) from chunks where path='alpha/cat/five.md'")" != "0" ]
  [ "$(sqlite3 "$IDX/wiki.db" "select count(*) from chunks where path='alpha/cat/one.md'")" = "$before" ]
  [ "$(jq -r '.pages | length' "$IDX/manifest.json")" = "4" ]
}

@test "boundary: --incremental with no index at all falls back to a full build" {
  make_wiki
  [ ! -f "$IDX/wiki.db" ]
  run python3 "$SCRIPT" --incremental
  [ "$status" -eq 0 ]
  [ -f "$IDX/wiki.db" ]
  [ "$(jq -r '.pages | length' "$IDX/manifest.json")" = "3" ]
}

@test "boundary: --incremental with nothing changed still succeeds and stays fresh" {
  build_index
  count_before=$(sqlite3 "$IDX/wiki.db" "select count(*) from chunks")
  run python3 "$SCRIPT" --incremental
  [ "$status" -eq 0 ]
  [ "$(sqlite3 "$IDX/wiki.db" "select count(*) from chunks")" = "$count_before" ]
  run python3 "$SCRIPT" --status
  [ "$output" = "fresh" ]
}

@test "error: --incremental with a missing wiki root exits 4" {
  build_index
  DEV_LOOP_WIKI_ROOT="$BATS_TEST_TMPDIR/nope" run python3 "$SCRIPT" --incremental
  [ "$status" -eq 4 ]
}

# --- SessionStart hook ---

@test "normal: with no index the hook spawns a full build and returns at once" {
  make_wiki
  start=$(date +%s)
  run bash "$HOOK"
  end=$(date +%s)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ $((end - start)) -le 3 ]

  wait_for_file "$SHIM_LOG"
  line=$(tail -1 "$SHIM_LOG")
  [[ "$line" == *"wiki-index.py --build"* ]]
  # negative control: it did not choose the incremental flag
  [[ "$line" != *"--incremental"* ]]
}

@test "normal: with an edited page the hook spawns an incremental run" {
  build_index
  printf '%s\n' 'An edit that makes the index stale.' >> "$WIKI/alpha/cat/two.md"
  run bash "$HOOK"
  [ "$status" -eq 0 ]

  wait_for_file "$SHIM_LOG"
  line=$(tail -1 "$SHIM_LOG")
  [[ "$line" == *"wiki-index.py --incremental"* ]]
  # negative control: not a full rebuild
  [[ "$line" != *"--build"* ]]
}

@test "normal: with a fresh index the hook spawns nothing" {
  build_index
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  sleep 1
  [ ! -f "$SHIM_LOG" ]
  # negative control: making it stale does produce a spawn
  printf '%s\n' 'now stale' >> "$WIKI/alpha/cat/two.md"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  wait_for_file "$SHIM_LOG"
  [ -f "$SHIM_LOG" ]
}

@test "boundary: the off switch stops the hook before it spawns anything" {
  make_wiki
  for value in 0 off false; do
    DEV_LOOP_WIKI_INDEX="$value" run bash "$HOOK"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  sleep 1
  [ ! -f "$SHIM_LOG" ]
  # negative control: left on, the same state spawns a build
  DEV_LOOP_WIKI_INDEX=1 run bash "$HOOK"
  [ "$status" -eq 0 ]
  wait_for_file "$SHIM_LOG"
  [ -f "$SHIM_LOG" ]
}

@test "boundary: the hook skips the dev-loop flush checkout" {
  make_wiki
  CLAUDE_PROJECT_DIR="$HOME/.dev-loop/repo/dev-loop" run bash "$HOOK"
  [ "$status" -eq 0 ]
  sleep 1
  [ ! -f "$SHIM_LOG" ]
  # negative control: any other project dir is not skipped
  CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/some-project" run bash "$HOOK"
  [ "$status" -eq 0 ]
  wait_for_file "$SHIM_LOG"
  [ -f "$SHIM_LOG" ]
}

@test "error: without uv the hook exits 0 and spawns nothing" {
  make_wiki
  BARE="$BATS_TEST_TMPDIR/bare"
  mkdir -p "$BARE"
  ln -sf "$(command -v python3)" "$BARE/python3"
  PATH="$BARE" run "$BASH_BIN" "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  sleep 1
  [ ! -f "$SHIM_LOG" ]
}

@test "error: without python3 the hook exits 0 and spawns nothing" {
  make_wiki
  BARE="$BATS_TEST_TMPDIR/bare2"
  mkdir -p "$BARE"
  cp "$SHIM/uv" "$BARE/uv"
  PATH="$BARE" run "$BASH_BIN" "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  sleep 1
  [ ! -f "$SHIM_LOG" ]
}

@test "error: a status command that fails leaves the hook silent and exiting 0" {
  make_wiki
  BARE="$BATS_TEST_TMPDIR/bare3"
  mkdir -p "$BARE"
  # A python3 that fails outright, ahead of the real one: the hook must treat
  # an unreadable status as "nothing to do", not spawn a build on a guess.
  printf '%s\n%s\n' '#!/bin/sh' 'exit 9' > "$BARE/python3"
  chmod +x "$BARE/python3"
  PATH="$BARE:$PATH" run "$BASH_BIN" "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  sleep 1
  [ ! -f "$SHIM_LOG" ]

  # negative control: the real python3 on the same PATH does spawn a build
  run "$BASH_BIN" "$HOOK"
  [ "$status" -eq 0 ]
  wait_for_file "$SHIM_LOG"
  [ -f "$SHIM_LOG" ]
}

@test "boundary: the hook creates the index dir and its build log" {
  make_wiki
  rm -rf "$IDX"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  wait_for_file "$IDX/build.log"
  [ -f "$IDX/build.log" ]
}
