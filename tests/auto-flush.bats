#!/usr/bin/env bats
# Tests for hooks/auto-flush.sh — the Stop hook that either (opt-in) flushes
# the insight queue into a reviewed PR, or (default) emits a notice.
#
# Reviewer finding fixed here (round 2): scoping git by *subcommand*
# (`Bash(git -C <repo>:*)`) still let a prompt-injected nested session run
# arbitrary code (`-c alias.x='!sh -c evil' x`, `fetch --upload-pack=`,
# `log --output=<path>`, `rebase --exec`, etc.) or edit `.git/hooks/*`
# through the allowed Edit path. So the nested session gets NO git tool and
# no `gh pr create` at all — this script does every git/gh-write step
# itself, with fixed arguments, before and after the spawn.
#
# Every test points HOME at a fake dir under BATS_TEST_TMPDIR so no test ever
# touches the real ~/.dev-loop, and stubs `claude`/`gh` on PATH (executables
# live under the repo's gitignored .claude/tmp — never $TMPDIR/private/var,
# where creating + chmod +x-ing a file is forbidden by policy; mirrors
# tests/launch-session.bats / tests/orca-wait.bats). A local bare "origin"
# plus a pre-seeded clone at $HOME/.dev-loop/repo stand in for the real
# choiyounggi/dev-loop repo, so the hook's real git fetch/checkout/reset/
# push run against a local remote — never the network.

REPO_TMP() { printf '%s' "${BATS_TEST_DIRNAME}/../.claude/tmp"; }

setup() {
  AF="${BATS_TEST_DIRNAME}/../hooks/auto-flush.sh"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.dev-loop/queue"
  BIN="$(REPO_TMP)/auto-flush-bin-${BATS_TEST_NUMBER}"
  mkdir -p "$BIN"

  # Stub `claude`: records its full argv (one line), then runs
  # $STUB_CLAUDE_ACTION if a test set one — simulating the nested session's
  # file edits (wiki pages, the result file, or a hostile .git/hooks write)
  # so the trusted post-processing below can be exercised without a real
  # claude session.
  cat > "$BIN/claude" <<'STUBEOF'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_CLAUDE_LOG"
[ -n "$STUB_CLAUDE_ACTION" ] && eval "$STUB_CLAUDE_ACTION"
exit 0
STUBEOF
  chmod +x "$BIN/claude"

  # Stub `gh`: records its full argv (one line) so tests can assert the
  # exact `gh pr create` call, and answers `gh api user -q .login`.
  cat > "$BIN/gh" <<'STUBEOF'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_GH_LOG"
case "$1 $2" in
  "api user") printf 'testlogin\n' ;;
esac
exit 0
STUBEOF
  chmod +x "$BIN/gh"

  STUB_CLAUDE_LOG="$BATS_TEST_TMPDIR/claude-argv.log"
  STUB_GH_LOG="$BATS_TEST_TMPDIR/gh-argv.log"
  export HOME STUB_CLAUDE_LOG STUB_GH_LOG STUB_CLAUDE_ACTION
  PATH="$BIN:$PATH"
  export PATH

  # --- local git fixture -----------------------------------------------
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  git init --bare -q "$ORIGIN"
  SEED="$BATS_TEST_TMPDIR/seed"
  git init -q "$SEED"
  git -C "$SEED" config user.email "seed@test.local"
  git -C "$SEED" config user.name "seed"
  mkdir -p "$SEED/wiki"
  echo seed > "$SEED/README.md"
  git -C "$SEED" add -A
  git -C "$SEED" commit -q -m seed
  git -C "$SEED" branch -M main
  git -C "$SEED" remote add origin "$ORIGIN"
  git -C "$SEED" push -q origin main
  git clone -q "$ORIGIN" "$HOME/.dev-loop/repo"
  git -C "$HOME/.dev-loop/repo" checkout -q main
  REPO="$HOME/.dev-loop/repo"
  export REPO ORIGIN
}

teardown() {
  rm -rf "$(REPO_TMP)/auto-flush-bin-${BATS_TEST_NUMBER}"
}

# Seed N pending rows in one queue session file.
seed_pending() { # n
  local n="$1" i
  : > "$HOME/.dev-loop/queue/session.jsonl"
  for i in $(seq 1 "$n"); do
    printf '{"status":"pending"}\n' >> "$HOME/.dev-loop/queue/session.jsonl"
  done
}

run_hook() { # extra env already exported by caller
  run env HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
}

run_hook_opted_in() {
  run env DEV_LOOP_AUTOFLUSH=1 HOME="$HOME" PATH="$PATH" \
      STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" STUB_GH_LOG="$STUB_GH_LOG" \
      STUB_CLAUDE_ACTION="$STUB_CLAUDE_ACTION" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
}

# Waits for the backgrounded subshell's own lock release — the one signal
# that repo prep, the (stubbed) spawn, and the trusted post-processing have
# all finished, not just that claude was invoked.
wait_for_lock_release() {
  for _ in $(seq 1 75); do [ -d "$HOME/.dev-loop/.flush.lock" ] || return 0; sleep 0.2; done
  return 1
}

pushed_autoflush_branch() {
  git -C "$ORIGIN" for-each-ref --format='%(refname)' 'refs/heads/knowledge/autoflush-*' 2>/dev/null
}

# --- (a) default-off values never spawn -------------------------------------

@test "unset DEV_LOOP_AUTOFLUSH: no spawn, even with pending over threshold" {
  seed_pending 3
  run env -u DEV_LOOP_AUTOFLUSH HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  [ ! -f "$STUB_CLAUDE_LOG" ]
}

@test "DEV_LOOP_AUTOFLUSH=0: no spawn (old kill-switch value is now just 'off')" {
  seed_pending 3
  run env DEV_LOOP_AUTOFLUSH=0 HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  [ ! -f "$STUB_CLAUDE_LOG" ]
}

@test "DEV_LOOP_AUTOFLUSH=yes: anything other than exactly '1' is off, no spawn" {
  seed_pending 3
  run env DEV_LOOP_AUTOFLUSH=yes HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  [ ! -f "$STUB_CLAUDE_LOG" ]
}

# --- (b) DEV_LOOP_AUTOFLUSH=1 + enough pending: spawns, never bypasses ------

@test "DEV_LOOP_AUTOFLUSH=1 with enough pending: spawns with --allowedTools, no bypass" {
  seed_pending 3
  run_hook_opted_in
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$STUB_CLAUDE_LOG" ] && break; sleep 0.2; done
  [ -f "$STUB_CLAUDE_LOG" ]
  argv="$(cat "$STUB_CLAUDE_LOG")"
  [[ "$argv" == *"--allowedTools"* ]]
  [[ "$argv" != *"bypassPermissions"* ]]
  [[ "$argv" != *"dangerously-skip-permissions"* ]]
}

@test "DEV_LOOP_AUTOFLUSH=1: allowedTools has no git entry at all and no gh pr create" {
  seed_pending 3
  run_hook_opted_in
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$STUB_CLAUDE_LOG" ] && break; sleep 0.2; done
  [ -f "$STUB_CLAUDE_LOG" ]
  argv="$(cat "$STUB_CLAUDE_LOG")"
  # the nested session gets NO git at all — scoping by subcommand (e.g.
  # Bash(git -C <repo>:*)) still allows `-c alias.x=...`, `--upload-pack=`,
  # `--output=<path>`, `rebase --exec`, `submodule foreach`, `bisect run`
  [[ "$argv" != *"Bash(git"* ]]
  [[ "$argv" != *"gh pr create"* ]]
  [[ "$argv" != *"Bash(sh:*)"* ]]
  [[ "$argv" != *"Bash(node:*)"* ]]
  [[ "$argv" != *"Bash(gh api:*)"* ]]
  [[ "$argv" != *"Bash(mkdir"* ]]
  [[ "$argv" != *",Write,"* ]]
  [[ "$argv" != *",Edit,"* ]]
}

@test "DEV_LOOP_AUTOFLUSH=1: allowedTools/disallowedTools have the exact entries" {
  seed_pending 3
  run_hook_opted_in
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$STUB_CLAUDE_LOG" ] && break; sleep 0.2; done
  [ -f "$STUB_CLAUDE_LOG" ]
  argv="$(cat "$STUB_CLAUDE_LOG")"
  [[ "$argv" == *"Bash(gh api user:*)"* ]]
  [[ "$argv" == *"Bash(gh pr list --repo choiyounggi/dev-loop:*)"* ]]
  [[ "$argv" == *"Bash(export DEV_LOOP_FLUSH_RUN_ID=*)"* ]]
  [[ "$argv" == *"scripts/flush-lock.sh:*)"* ]]
  [[ "$argv" == *"hooks/queue-claim.js:*)"* ]]
  [[ "$argv" == *"Edit(//"*".dev-loop/**)"* ]]
  [[ "$argv" == *"--disallowedTools"* ]]
  # the deny carve-out for the checkout's own .git dir, path-scoped the same
  # filesystem-root-absolute (//) way as the allow rule.
  [[ "$argv" == *"Edit(//"*"/.dev-loop/repo/.git/**)"* ]]
}

@test "DEV_LOOP_AUTOFLUSH=1 with pending BELOW min: no spawn (threshold still applies)" {
  seed_pending 2
  run env DEV_LOOP_AUTOFLUSH=1 HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  sleep 0.3
  [ ! -f "$STUB_CLAUDE_LOG" ]
}

# --- (b2) the trusted script does the git/gh-write steps itself -------------

@test "nested session writes wiki files + a valid result file: commits, pushes, opens the PR with exact args" {
  seed_pending 3
  DEVLOOP="$HOME/.dev-loop"
  STUB_CLAUDE_ACTION="mkdir -p '$REPO/wiki/x' '$REPO/.dev-loop'; echo page > '$REPO/wiki/x/p.md'; echo report > '$REPO/.dev-loop/INGEST_REPORT.md'; printf '{\"title\":\"t1\",\"body_file\":\"%s\"}' '$REPO/.dev-loop/INGEST_REPORT.md' > '$DEVLOOP/autoflush-result.json'"
  export STUB_CLAUDE_ACTION
  run_hook_opted_in
  wait_for_lock_release
  prcall="$(grep 'pr create' "$STUB_GH_LOG" || true)"
  [ -n "$prcall" ]
  [[ "$prcall" == *"--repo choiyounggi/dev-loop"* ]]
  [[ "$prcall" == *"--title t1"* ]]
  # the script passes the realpath it validated, not the raw result-file value
  [[ "$prcall" == *"--body-file $(realpath "$REPO/.dev-loop/INGEST_REPORT.md")"* ]]
  [[ "$prcall" == *"--label dev-loop:knowledge"* ]]
  [[ "$prcall" == *"--head knowledge/autoflush-"* ]]
  git -C "$REPO" log -1 --format=%s | grep -q "knowledge: ingest"
  [ -n "$(pushed_autoflush_branch)" ]
}

@test "nested session writes nothing: no commit, no push, no PR" {
  seed_pending 3
  run_hook_opted_in
  wait_for_lock_release
  [ -z "$(grep 'pr create' "$STUB_GH_LOG" 2>/dev/null || true)" ]
  [ -z "$(pushed_autoflush_branch)" ]
}

@test "malformed result JSON: no commit, no push, no PR" {
  seed_pending 3
  DEVLOOP="$HOME/.dev-loop"
  STUB_CLAUDE_ACTION="echo page > '$REPO/wiki/x.md'; printf 'not json' > '$DEVLOOP/autoflush-result.json'"
  export STUB_CLAUDE_ACTION
  run_hook_opted_in
  wait_for_lock_release
  [ -z "$(grep 'pr create' "$STUB_GH_LOG" 2>/dev/null || true)" ]
  [ -z "$(pushed_autoflush_branch)" ]
}

@test "body_file outside ~/.dev-loop: no commit, no push, no PR" {
  seed_pending 3
  DEVLOOP="$HOME/.dev-loop"
  EVIL="$BATS_TEST_TMPDIR/evil-report.md"
  STUB_CLAUDE_ACTION="echo page > '$REPO/wiki/x.md'; echo evil > '$EVIL'; printf '{\"title\":\"t\",\"body_file\":\"%s\"}' '$EVIL' > '$DEVLOOP/autoflush-result.json'"
  export STUB_CLAUDE_ACTION
  run_hook_opted_in
  wait_for_lock_release
  [ -z "$(grep 'pr create' "$STUB_GH_LOG" 2>/dev/null || true)" ]
  [ -z "$(pushed_autoflush_branch)" ]
}

@test "nested session tampers with .git/hooks: aborts without committing" {
  seed_pending 3
  DEVLOOP="$HOME/.dev-loop"
  STUB_CLAUDE_ACTION="echo page > '$REPO/wiki/x.md'; echo evil > '$REPO/.git/hooks/pre-commit'; mkdir -p '$REPO/.dev-loop'; echo report > '$REPO/.dev-loop/INGEST_REPORT.md'; printf '{\"title\":\"t\",\"body_file\":\"%s\"}' '$REPO/.dev-loop/INGEST_REPORT.md' > '$DEVLOOP/autoflush-result.json'"
  export STUB_CLAUDE_ACTION
  run_hook_opted_in
  wait_for_lock_release
  [ -z "$(grep 'pr create' "$STUB_GH_LOG" 2>/dev/null || true)" ]
  [ -z "$(pushed_autoflush_branch)" ]
  grep -qi "hooks" "$DEVLOOP/autoflush.log"
}

@test "nested session writes .git/info/attributes: aborts without committing" {
  seed_pending 3
  DEVLOOP="$HOME/.dev-loop"
  STUB_CLAUDE_ACTION="echo page > '$REPO/wiki/x.md'; mkdir -p '$REPO/.git/info'; echo '* filter=evil' > '$REPO/.git/info/attributes'; mkdir -p '$REPO/.dev-loop'; echo report > '$REPO/.dev-loop/INGEST_REPORT.md'; printf '{\"title\":\"t\",\"body_file\":\"%s\"}' '$REPO/.dev-loop/INGEST_REPORT.md' > '$DEVLOOP/autoflush-result.json'"
  export STUB_CLAUDE_ACTION
  run_hook_opted_in
  wait_for_lock_release
  [ -z "$(grep 'pr create' "$STUB_GH_LOG" 2>/dev/null || true)" ]
  [ -z "$(pushed_autoflush_branch)" ]
  grep -qi "hooks" "$DEVLOOP/autoflush.log"
}

# --- (c) default-off notice: emitted once per rate-limit window, never blocks -

@test "default off + pending >= min: emits one systemMessage notice naming the count" {
  seed_pending 5
  run env -u DEV_LOOP_AUTOFLUSH HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"systemMessage"'* ]]
  [[ "$output" == *"5 insight"* ]]
  [[ "$output" == *"/dev-loop:knowledge-flush"* ]]
  # never blocks the Stop: no "decision":"block" in the output
  [[ "$output" != *'"decision"'* ]]
}

@test "default off: a second Stop inside the rate-limit window emits no second notice" {
  seed_pending 5
  run env -u DEV_LOOP_AUTOFLUSH HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"systemMessage"'* ]]

  run env -u DEV_LOOP_AUTOFLUSH HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- (d) default-off + pending below min: silent ----------------------------

@test "default off + pending below min: silent (no notice, no spawn)" {
  seed_pending 2
  run env -u DEV_LOOP_AUTOFLUSH HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$STUB_CLAUDE_LOG" ]
}

@test "default off + zero pending (empty queue dir): silent (boundary)" {
  rm -f "$HOME/.dev-loop/queue/session.jsonl"
  run env -u DEV_LOOP_AUTOFLUSH HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$STUB_CLAUDE_LOG" ]
}
