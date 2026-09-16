#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Tests for scripts/graph-workspace.sh — enumerate the git repos under one or
# more workspace roots and report freshness + hook status.
#
# Contract under test (scripts/graph-workspace.sh header):
#   --list    one repo path per line, sorted                         exit 0
#   --status  one line per repo: <path>\t<freshness>\thooks: <hooks> exit=max(freshness rc)
#   both      no-repos (exit 0) | cannot-evaluate missing-root/usage (exit 4)
#
# `[[ ... ]]` mid-test-body does NOT reliably fail a bats test on macOS system
# bash (see wiki/testing/quality/tests-that-cannot-fail.md); substring checks
# go through the _has/_hasnt helpers, never bare `[[ ... ]]`.
#
# graphify is never executed: GRAPHIFY_BIN points at a logging shim so a run
# that reaches it at all is itself a failure of the "never runs graphify"
# invariant.

_has() { # $1=haystack $2=needle
  case "$1" in
    *"$2"*) return 0 ;;
    *) printf 'expected to find [%s] in [%s]\n' "$2" "$1" >&2; return 1 ;;
  esac
}
_hasnt() { # $1=haystack $2=needle
  case "$1" in
    *"$2"*) printf 'expected NOT to find [%s] in [%s]\n' "$2" "$1" >&2; return 1 ;;
    *) return 0 ;;
  esac
}

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/graph-workspace.sh"
  HOOKS="${BATS_TEST_DIRNAME}/../scripts/graph-hooks.sh"
  export GIT_CONFIG_GLOBAL=/dev/null

  STUB_ROOT="${BATS_TEST_DIRNAME}/../.claude/tmp/gw-$$-${BATS_TEST_NUMBER:-0}"
  mkdir -p "$STUB_ROOT/bin"
  SHIM_LOG="$STUB_ROOT/shim.log"
  : > "$SHIM_LOG"
  cat > "$STUB_ROOT/bin/graphify" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$SHIM_LOG"
exit 0
EOF
  chmod +x "$STUB_ROOT/bin/graphify"
  export SHIM_LOG
  export PATH="$STUB_ROOT/bin:$PATH"
  export GRAPHIFY_BIN=true
}

teardown() {
  [ -n "${WS_UNREADABLE:-}" ] && chmod 755 "$WS_UNREADABLE" 2>/dev/null
  [ -n "${STUB_ROOT:-}" ] && rm -rf "$STUB_ROOT"
  return 0
}

# A git repo whose only commit predates any graph.json the test writes.
make_repo() {
  git init -q "$1"
  git -C "$1" config user.email t@example.com
  git -C "$1" config user.name t
  printf 'a\n' > "$1/a.txt"
  git -C "$1" add -A
  GIT_AUTHOR_DATE='2020-01-01T00:00:00Z' GIT_COMMITTER_DATE='2020-01-01T00:00:00Z' \
    git -C "$1" commit -q -m init
}

make_graph() {
  mkdir -p "$1/graphify-out"
  printf '{"nodes":[{"id":"a"}]}\n' > "$1/graphify-out/graph.json"
}

abs() { ( cd "$1" && pwd -P ); }

# --- normal -------------------------------------------------------------

@test "normal: --status reports fresh, stale, and absent repos, sorted, hooks none" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  fresh="$ws/fresh"; make_repo "$fresh"; make_graph "$fresh"
  stale="$ws/stale"; make_repo "$stale"; make_graph "$stale"
  printf 'b\n' > "$stale/b.txt"; printf 'c\n' > "$stale/c.txt"
  git -C "$stale" add -A; git -C "$stale" commit -q -m later
  absent="$ws/absent"; make_repo "$absent"

  run "$SCRIPT" --status "$ws"
  [ "$status" -eq 3 ]
  fresh_abs=$(abs "$fresh"); stale_abs=$(abs "$stale"); absent_abs=$(abs "$absent")
  # sort order is lexical on the absolute path, independent of repo name
  sorted_paths=$(printf '%s\n%s\n%s\n' "$fresh_abs" "$stale_abs" "$absent_abs" | sort)
  [ "$(printf '%s\n' "$output" | cut -f1)" = "$sorted_paths" ]
  _has "$output" "$fresh_abs"$'\t'"fresh"$'\t'"hooks: none"
  _has "$output" "$stale_abs"$'\t'"stale 2"$'\t'"hooks: none"
  _has "$output" "$absent_abs"$'\t'"absent"$'\t'"hooks: none"
}

@test "normal: --list prints only the repo paths, sorted, exit 0" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  r1="$ws/z"; make_repo "$r1"
  r2="$ws/a"; make_repo "$r2"
  run "$SCRIPT" --list "$ws"
  [ "$status" -eq 0 ]
  expected=$(printf '%s\n%s\n' "$(abs "$r2")" "$(abs "$r1")" | sort)
  [ "$output" = "$expected" ]
}

@test "normal: a repo with the dev-loop hook installed reports hooks: partial" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  r="$ws/r"; make_repo "$r"
  "$HOOKS" install "$r" >/dev/null
  run "$SCRIPT" --status "$ws"
  [ "$status" -eq 3 ]
  _has "$output" "hooks: partial"
}

# --- error ----------------------------------------------------------------

@test "error: --status on a missing root -> cannot-evaluate missing-root, exit 4" {
  run "$SCRIPT" --status "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 4 ]
  _has "$output" "cannot-evaluate missing-root"
}

@test "error: no verb -> cannot-evaluate usage, exit 4" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  run "$SCRIPT" "$ws"
  [ "$status" -eq 4 ]
  _has "$output" "cannot-evaluate usage"
}

@test "error: --list and --status together are rejected as usage" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  run "$SCRIPT" --list --status "$ws"
  [ "$status" -eq 4 ]
  _has "$output" "cannot-evaluate usage"
}

@test "error: --depth 0 and --depth x are rejected as usage errors" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  run "$SCRIPT" --list --depth 0 "$ws"
  [ "$status" -eq 4 ]
  _has "$output" "cannot-evaluate usage"
  run "$SCRIPT" --list --depth x "$ws"
  [ "$status" -eq 4 ]
  _has "$output" "cannot-evaluate usage"
}

@test "error: GRAPHIFY_BIN not resolving surfaces cannot-evaluate no-cli, exit 4" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  r="$ws/r"; make_repo "$r"; make_graph "$r"
  GRAPHIFY_BIN=/nonexistent-graphify-xyz run "$SCRIPT" --status "$ws"
  [ "$status" -eq 4 ]
  _has "$output" "cannot-evaluate no-cli"
}

# --- boundary ---------------------------------------------------------------

@test "boundary: an empty workspace yields no-repos, exit 0" {
  ws="$BATS_TEST_TMPDIR/empty"; mkdir -p "$ws"
  run "$SCRIPT" --list "$ws"
  [ "$status" -eq 0 ]
  [ "$output" = "no-repos" ]
}

@test "boundary: a worktree (.git file) and a bare clone are not repos -> no-repos" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  origin="$BATS_TEST_TMPDIR/origin"; make_repo "$origin"
  git -C "$origin" worktree add -q -b wtbranch "$ws/wt" >/dev/null 2>&1
  git clone -q --bare "$origin" "$ws/bare.git" >/dev/null 2>&1
  run "$SCRIPT" --list "$ws"
  [ "$status" -eq 0 ]
  [ "$output" = "no-repos" ]
}

@test "boundary: a symlink to a repo outside the workspace is not listed" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  outside="$BATS_TEST_TMPDIR/outside"; make_repo "$outside"
  ln -s "$outside" "$ws/link"
  run "$SCRIPT" --list "$ws"
  [ "$status" -eq 0 ]
  [ "$output" = "no-repos" ]
}

@test "boundary: --depth 1 hides a repo whose .git sits at depth 2" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  r="$ws/r"; make_repo "$r"
  run "$SCRIPT" --list --depth 1 "$ws"
  [ "$status" -eq 0 ]
  [ "$output" = "no-repos" ]
  run "$SCRIPT" --list --depth 2 "$ws"
  [ "$status" -eq 0 ]
  [ "$output" = "$(abs "$r")" ]
}

@test "boundary: --exclude drops a matching path component" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws/node_modules"
  kept="$ws/kept"; make_repo "$kept"
  dropped="$ws/node_modules/pkg"; make_repo "$dropped"
  # without --exclude, --depth 3 reaches both repos (proves the fixture is
  # actually within reach, so the exclude assertion below tests match_excluded
  # and not just the depth limit hiding the nested repo)
  run "$SCRIPT" --list --depth 3 "$ws"
  [ "$status" -eq 0 ]
  expected_both=$(printf '%s\n%s\n' "$(abs "$kept")" "$(abs "$dropped")" | sort)
  [ "$output" = "$expected_both" ]

  run "$SCRIPT" --list --depth 3 --exclude node_modules "$ws"
  [ "$status" -eq 0 ]
  [ "$output" = "$(abs "$kept")" ]
}

@test "boundary: an unreadable directory is skipped with one stderr line, exit reflects readable repos" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  [ "$(id -u)" -ne 0 ] || skip "cannot deny read access as root"
  ok="$ws/ok"; make_repo "$ok"; make_graph "$ok"
  WS_UNREADABLE="$ws/locked"; mkdir -p "$WS_UNREADABLE/inner"
  git init -q "$WS_UNREADABLE/inner" >/dev/null
  chmod 000 "$WS_UNREADABLE"
  run --separate-stderr "$SCRIPT" --status "$ws"
  chmod 755 "$WS_UNREADABLE"
  [ "$status" -eq 0 ]
  _has "$output" "$(abs "$ok")"$'\t'"fresh"
  err_lines=$(printf '%s\n' "$stderr" | grep -c '^skip: unreadable ')
  [ "$err_lines" -eq 1 ]
}

@test "boundary: two roots given are unioned and sorted" {
  ws1="$BATS_TEST_TMPDIR/ws1"; mkdir -p "$ws1"
  ws2="$BATS_TEST_TMPDIR/ws2"; mkdir -p "$ws2"
  r1="$ws1/r1"; make_repo "$r1"
  r2="$ws2/r2"; make_repo "$r2"
  run "$SCRIPT" --list "$ws1" "$ws2"
  [ "$status" -eq 0 ]
  expected=$(printf '%s\n%s\n' "$(abs "$r1")" "$(abs "$r2")" | sort)
  [ "$output" = "$expected" ]
}

@test "boundary: a root that is itself a git repo is listed (not just its subdirectories)" {
  r="$BATS_TEST_TMPDIR/r"; make_repo "$r"
  run "$SCRIPT" --list "$r"
  [ "$status" -eq 0 ]
  [ "$output" = "$(abs "$r")" ]
}

@test "boundary: the same repo reached via two overlapping roots is listed once" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  r="$ws/r"; make_repo "$r"
  run "$SCRIPT" --list "$ws" "$r"
  [ "$status" -eq 0 ]
  [ "$output" = "$(abs "$r")" ]
}

# --- state --------------------------------------------------------------

@test "state: --status prints exactly one line per repo and nothing else" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  a="$ws/a"; make_repo "$a"; make_graph "$a"
  b="$ws/b"; make_repo "$b"
  run "$SCRIPT" --status "$ws"
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 2 ]
}

@test "state: graphify is never executed across the suite" {
  ws="$BATS_TEST_TMPDIR/ws"; mkdir -p "$ws"
  a="$ws/a"; make_repo "$a"; make_graph "$a"
  "$SCRIPT" --status "$ws" >/dev/null
  "$SCRIPT" --list "$ws" >/dev/null
  [ ! -s "$SHIM_LOG" ]
}
