#!/usr/bin/env bats
# Tests for scripts/graph-hooks.sh (install/uninstall/status of the
# marker-delimited dev-loop post-merge hook) and templates/graph-post-merge.sh
# (the hook body it installs).
#
# Contract under test (scripts/graph-hooks.sh header; ruling 2026-09-17,
# blackboard [t6-graph-scripts]: status on a broken dev-loop block is
# `cannot-evaluate broken-marker` exit 4, never `partial`):
#   verb        outcome                                          exit
#   install     `installed <path>` | `already-installed <path>`  0
#               | `cannot-evaluate <reason>`                     4
#   uninstall   `uninstalled <path>` | `not-installed`            0
#               | `cannot-evaluate <reason>`                     4
#   status      `ok` | `partial` | `none`                        0/2/3
#               | `cannot-evaluate <reason>`                     4
#
# `[[ ... ]]` mid-test-body does NOT fail a bats test on macOS system bash
# 3.2 (bash exempts the [[ keyword from the ERR trap there) — see
# wiki/testing/quality/tests-that-cannot-fail.md and tests/safe-cleanup.bats.
# Substring assertions therefore go through the _has/_hasnt helpers below
# (plain function calls, whose failure DOES abort the test), never bare
# `[[ ... ]]`.
#
# graphify is never executed except through the deliberately invoked hook
# body, whose only "graphify" is the PATH shim below (argv-logging +
# graph.json writer) — never the real CLI.

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

# Read a file's mtime as an epoch, the same GNU/BSD fallback chain as
# scripts/graph-freshness.sh.
_epoch() {
  date -r "$1" +%s 2>/dev/null || stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"
}

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/graph-hooks.sh"
  TEMPLATE="${BATS_TEST_DIRNAME}/../templates/graph-post-merge.sh"
  export GIT_CONFIG_GLOBAL=/dev/null

  # Executable test doubles live under the repo's gitignored .claude/tmp —
  # never $TMPDIR/BATS_TEST_TMPDIR, where creating and chmod +x-ing an
  # executable is forbidden by policy (mirrors tests/safe-cleanup.bats).
  STUB_ROOT="${BATS_TEST_DIRNAME}/../.claude/tmp/gh-$$-${BATS_TEST_NUMBER:-0}"
  mkdir -p "$STUB_ROOT/bin"
  SHIM_LOG="$STUB_ROOT/shim.log"
  : > "$SHIM_LOG"
  cat > "$STUB_ROOT/bin/graphify" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$SHIM_LOG"
if [ "$1" = update ]; then
  mkdir -p "$2/graphify-out"
  printf '{"nodes":[]}\n' > "$2/graphify-out/graph.json"
fi
exit 0
EOF
  chmod +x "$STUB_ROOT/bin/graphify"
  export SHIM_LOG
  export PATH="$STUB_ROOT/bin:$PATH"
}

teardown() {
  [ -n "${STUB_ROOT:-}" ] && rm -rf "$STUB_ROOT"
  return 0
}

make_repo() {
  git init -q "$1"
  git -C "$1" config user.email t@example.com
  git -C "$1" config user.name t
  printf 'a\n' > "$1/a.txt"
  git -C "$1" add -A
  git -C "$1" commit -q -m init
}

# fake a graphify-installed hook (post-commit / post-checkout) so status can
# see the graphify side of the "ok" contract without running graphify itself.
fake_graphify_hooks() {
  d="$1/.git/hooks"
  mkdir -p "$d"
  printf '#!/bin/sh\n# graphify-hook-start\nexit 0\n' > "$d/post-commit"
  chmod +x "$d/post-commit"
  printf '#!/bin/sh\n# graphify-checkout-hook-start\nexit 0\n' > "$d/post-checkout"
  chmod +x "$d/post-checkout"
}

run_hook_body() { ( cd "$1" && sh "$TEMPLATE" ); }

# --- normal -------------------------------------------------------------

@test "normal: install on a fresh repo creates the hook, marker, and info/exclude line" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  run "$SCRIPT" install "$repo"
  [ "$status" -eq 0 ]
  hook="$(cd "$repo" && pwd -P)/.git/hooks/post-merge"
  [ "$output" = "installed $hook" ]
  [ -x "$hook" ]
  [ "$(grep -c '^# dev-loop-graph-merge-start$' "$hook")" -eq 1 ]
  [ "$(grep -c '^# dev-loop-graph-merge-end$' "$hook")" -eq 1 ]
  grep -qx 'graphify-out/' "$repo/.git/info/exclude"
  [ ! -f "$repo/.gitignore" ]
}

@test "normal: status after install is partial (graphify hooks absent)" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  "$SCRIPT" install "$repo" >/dev/null
  run "$SCRIPT" status "$repo"
  [ "$status" -eq 2 ]
  [ "$output" = "partial" ]
}

@test "normal: status is ok once graphify's own hooks are also present" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  "$SCRIPT" install "$repo" >/dev/null
  fake_graphify_hooks "$repo"
  run "$SCRIPT" status "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "normal: status is partial, not ok, when both graphify hooks are present but dev-loop's is not (onboarding order)" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  # graphify onboarded first (its own two hooks installed); dev-loop's own
  # post-merge block never installed -- this is the third leg of the `ok`
  # contract: all three markers, not just graphify's two, must be present.
  fake_graphify_hooks "$repo"
  run "$SCRIPT" status "$repo"
  [ "$status" -eq 2 ]
  [ "$output" = "partial" ]
}

@test "normal: status is partial, not ok, when post-commit exists but lacks graphify's marker" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  "$SCRIPT" install "$repo" >/dev/null
  d="$repo/.git/hooks"
  # post-checkout genuinely carries graphify's marker; post-commit EXISTS but
  # does not (a foreign/unrelated hook) -- this proves `ok` requires the
  # post-commit marker grep to actually match, not merely the file's existence.
  printf '#!/bin/sh\n# graphify-checkout-hook-start\nexit 0\n' > "$d/post-checkout"
  chmod +x "$d/post-checkout"
  printf '#!/bin/sh\necho unrelated\n' > "$d/post-commit"
  chmod +x "$d/post-commit"
  run "$SCRIPT" status "$repo"
  [ "$status" -eq 2 ]
  [ "$output" = "partial" ]
}

@test "normal: status is partial, not ok, when post-checkout exists but lacks graphify's marker" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  "$SCRIPT" install "$repo" >/dev/null
  d="$repo/.git/hooks"
  # symmetric to the post-commit case above: post-commit genuinely carries
  # graphify's marker; post-checkout EXISTS but does not.
  printf '#!/bin/sh\n# graphify-hook-start\nexit 0\n' > "$d/post-commit"
  chmod +x "$d/post-commit"
  printf '#!/bin/sh\necho unrelated\n' > "$d/post-checkout"
  chmod +x "$d/post-checkout"
  run "$SCRIPT" status "$repo"
  [ "$status" -eq 2 ]
  [ "$output" = "partial" ]
}

@test "normal: uninstall removes the hook and status returns to none" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  "$SCRIPT" install "$repo" >/dev/null
  hook="$(cd "$repo" && pwd -P)/.git/hooks/post-merge"
  run "$SCRIPT" uninstall "$repo"
  [ "$status" -eq 0 ]
  _has "$output" "uninstalled $hook"
  [ ! -f "$hook" ]
  run "$SCRIPT" status "$repo"
  [ "$status" -eq 3 ]
  [ "$output" = "none" ]
}

@test "normal: uninstall on a repo with no dev-loop hook is a no-op -- not-installed" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  run "$SCRIPT" uninstall "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "not-installed" ]
}

# --- error ----------------------------------------------------------------

@test "error: not a git directory -> cannot-evaluate not-git, exit 4" {
  plain="$BATS_TEST_TMPDIR/plain"; mkdir -p "$plain"
  run "$SCRIPT" status "$plain"
  [ "$status" -eq 4 ]
  [ "$output" = "cannot-evaluate not-git" ]
}

@test "error: unknown verb -> cannot-evaluate usage, exit 4" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  run "$SCRIPT" bogus "$repo"
  [ "$status" -eq 4 ]
  _has "$output" "cannot-evaluate usage"
}

@test "error: missing operand -> cannot-evaluate usage, exit 4" {
  run "$SCRIPT" install
  [ "$status" -eq 4 ]
  _has "$output" "cannot-evaluate usage"
}

@test "error: core.hooksPath override refuses every verb, writes nothing" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  override="$BATS_TEST_TMPDIR/global-hooks"
  git -C "$repo" config core.hooksPath "$override"
  for verb in install status uninstall; do
    run "$SCRIPT" "$verb" "$repo"
    [ "$status" -eq 4 ]
    _has "$output" "cannot-evaluate hooks-path-override"
  done
  [ ! -f "$repo/.git/hooks/post-merge" ]
  [ ! -d "$override" ] || [ ! -f "$override/post-merge" ]
}

@test "error: hook body with graphify absent from PATH -> exit 0, empty stdout" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  mkdir -p "$repo/graphify-out"; printf '{"nodes":[]}\n' > "$repo/graphify-out/graph.json"
  run env PATH="/usr/bin:/bin" bash -c 'cd "$1" && sh "$2"' _ "$repo" "$TEMPLATE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "error: broken marker (start without end) blocks install, file untouched" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  hook="$repo/.git/hooks/post-merge"
  printf '#!/bin/sh\n# dev-loop-graph-merge-start\necho oops\n' > "$hook"
  chmod +x "$hook"
  before=$(cat "$hook")
  run "$SCRIPT" install "$repo"
  [ "$status" -eq 4 ]
  [ "$output" = "cannot-evaluate broken-marker" ]
  after=$(cat "$hook")
  [ "$before" = "$after" ]
}

@test "error: broken marker (start without end) blocks uninstall, file untouched" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  hook="$repo/.git/hooks/post-merge"
  printf '#!/bin/sh\n# dev-loop-graph-merge-start\necho oops\n' > "$hook"
  chmod +x "$hook"
  before=$(cat "$hook")
  run "$SCRIPT" uninstall "$repo"
  [ "$status" -eq 4 ]
  [ "$output" = "cannot-evaluate broken-marker" ]
  after=$(cat "$hook")
  [ "$before" = "$after" ]
}

@test "error: broken marker blocks status too -- cannot-evaluate, never partial" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  hook="$repo/.git/hooks/post-merge"
  printf '#!/bin/sh\n# dev-loop-graph-merge-start\necho oops\n' > "$hook"
  chmod +x "$hook"
  fake_graphify_hooks "$repo"
  run "$SCRIPT" status "$repo"
  [ "$status" -eq 4 ]
  [ "$output" = "cannot-evaluate broken-marker" ]
}

# --- boundary ---------------------------------------------------------------

@test "boundary: install appends after foreign content, keeps it first and executable" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  hook="$(cd "$repo" && pwd -P)/.git/hooks/post-merge"
  printf '#!/bin/sh\necho hi\n' > "$hook"
  chmod +x "$hook"
  run "$SCRIPT" install "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "installed $hook" ]
  [ -x "$hook" ]
  first_foreign_line=$(sed -n '2p' "$hook")
  [ "$first_foreign_line" = "echo hi" ]
  [ "$(grep -c '^# dev-loop-graph-merge-start$' "$hook")" -eq 1 ]
}

@test "boundary: uninstall restores a foreign-only file with no markers left" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  hook="$repo/.git/hooks/post-merge"
  printf '#!/bin/sh\necho hi\n' > "$hook"
  chmod +x "$hook"
  "$SCRIPT" install "$repo" >/dev/null
  run "$SCRIPT" uninstall "$repo"
  [ "$status" -eq 0 ]
  [ -f "$hook" ]
  [ "$(grep -c '^# dev-loop-graph-merge-start$' "$hook")" -eq 0 ]
  _has "$(cat "$hook")" "echo hi"
}

@test "boundary: install twice is idempotent -- already-installed, one marker pair" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  hook="$(cd "$repo" && pwd -P)/.git/hooks/post-merge"
  "$SCRIPT" install "$repo" >/dev/null
  run "$SCRIPT" install "$repo"
  [ "$status" -eq 0 ]
  _has "$output" "already-installed $hook"
  [ "$(grep -c '^# dev-loop-graph-merge-start$' "$hook")" -eq 1 ]
  [ "$(grep -c '^# dev-loop-graph-merge-end$' "$hook")" -eq 1 ]
  [ "$(grep -cx 'graphify-out/' "$repo/.git/info/exclude")" -eq 1 ]
}

@test "boundary: hook body with graph.json absent never runs graphify" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  # ORIG_HEAD points at a real ancestor with a genuinely non-empty diff to
  # HEAD, so this case isolates the graph.json-absent guard: without it, the
  # ORIG_HEAD guard alone would not also block the run to graphify.
  git -C "$repo" update-ref ORIG_HEAD "$(git -C "$repo" rev-parse HEAD)"
  printf 'b\n' > "$repo/b.txt"; git -C "$repo" add -A; git -C "$repo" commit -q -m later
  run run_hook_body "$repo"
  [ "$status" -eq 0 ]
  [ ! -s "$SHIM_LOG" ]
}

@test "boundary: hook body with zero changed files (ORIG_HEAD = HEAD) never runs graphify" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  mkdir -p "$repo/graphify-out"; printf '{"nodes":[]}\n' > "$repo/graphify-out/graph.json"
  git -C "$repo" update-ref ORIG_HEAD "$(git -C "$repo" rev-parse HEAD)"
  run run_hook_body "$repo"
  [ "$status" -eq 0 ]
  [ ! -s "$SHIM_LOG" ]
}

# --- integration (the reason the issue exists) -------------------------------

@test "integration: a fast-forward git pull in a hooked clone rebuilds the graph" {
  origin="$BATS_TEST_TMPDIR/origin"; make_repo "$origin"
  clone="$BATS_TEST_TMPDIR/clone"
  git clone -q "$origin" "$clone"
  "$SCRIPT" install "$clone" >/dev/null

  mkdir -p "$clone/graphify-out"
  printf '{"nodes":[]}\n' > "$clone/graphify-out/graph.json"
  touch -t 202001010000 "$clone/graphify-out/graph.json"
  before_epoch=$(_epoch "$clone/graphify-out/graph.json")

  printf 'b\n' > "$origin/b.txt"
  git -C "$origin" add -A
  git -C "$origin" commit -q -m later

  run git -C "$clone" pull -q
  [ "$status" -eq 0 ]

  clone_abs=$(cd "$clone" && pwd -P)
  _has "$(cat "$SHIM_LOG")" "update $clone_abs"
  after_epoch=$(_epoch "$clone/graphify-out/graph.json")
  [ "$after_epoch" -gt "$before_epoch" ]
}

# --- state --------------------------------------------------------------

@test "state: install/uninstall/status never invoke graphify" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  "$SCRIPT" install "$repo" >/dev/null
  "$SCRIPT" status "$repo" >/dev/null || true
  "$SCRIPT" uninstall "$repo" >/dev/null
  [ ! -s "$SHIM_LOG" ]
}

@test "state: stdout carries exactly one line on every verb outcome" {
  repo="$BATS_TEST_TMPDIR/r"; make_repo "$repo"
  out=$("$SCRIPT" install "$repo")
  [ -n "$out" ]
  [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -eq 1 ]
  out=$("$SCRIPT" status "$repo" || true)
  [ -n "$out" ]
  [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -eq 1 ]
  out=$("$SCRIPT" uninstall "$repo")
  [ -n "$out" ]
  [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -eq 1 ]
  out=$("$SCRIPT" bogus "$repo" 2>/dev/null || true)
  [ -n "$out" ]
  [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -eq 1 ]
}
