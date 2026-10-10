#!/usr/bin/env bats
# Tests for hooks/auto-flush.sh — the Stop hook that either (opt-in) flushes
# the insight queue into a reviewed PR, or (default) emits a notice.
#
# Reviewer finding fixed here: the hook used to start another session with
# bypassPermissions and open a PR under the user's GitHub login by DEFAULT.
# Now it is OFF unless DEV_LOOP_AUTOFLUSH is exactly "1", and even opted in it
# never bypasses permission checks.
#
# Every test points HOME at a fake dir under BATS_TEST_TMPDIR so no test ever
# touches the real ~/.dev-loop, and stubs `claude`/`gh` on PATH (executables
# live under the repo's gitignored .claude/tmp — never $TMPDIR/private/var,
# where creating + chmod +x-ing a file is forbidden by policy; mirrors
# tests/launch-session.bats / tests/orca-wait.bats).

REPO_TMP() { printf '%s' "${BATS_TEST_DIRNAME}/../.claude/tmp"; }

setup() {
  AF="${BATS_TEST_DIRNAME}/../hooks/auto-flush.sh"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.dev-loop/queue"
  BIN="$(REPO_TMP)/auto-flush-bin-${BATS_TEST_NUMBER}"
  mkdir -p "$BIN"

  # Stub `claude`: records its full argv (one line) and exits 0 without
  # actually launching anything.
  cat > "$BIN/claude" <<'STUBEOF'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_CLAUDE_LOG"
exit 0
STUBEOF
  chmod +x "$BIN/claude"

  # Stub `gh`: just needs to exist on PATH for the fail-safe check.
  cat > "$BIN/gh" <<'STUBEOF'
#!/bin/sh
exit 0
STUBEOF
  chmod +x "$BIN/gh"

  STUB_CLAUDE_LOG="$BATS_TEST_TMPDIR/claude-argv.log"
  export HOME STUB_CLAUDE_LOG
  PATH="$BIN:$PATH"
  export PATH
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
  run env DEV_LOOP_AUTOFLUSH=1 HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  # the detached spawn is backgrounded; give it a beat to write its argv log
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$STUB_CLAUDE_LOG" ] && break; sleep 0.2; done
  [ -f "$STUB_CLAUDE_LOG" ]
  argv="$(cat "$STUB_CLAUDE_LOG")"
  [[ "$argv" == *"--allowedTools"* ]]
  [[ "$argv" != *"bypassPermissions"* ]]
  [[ "$argv" != *"dangerously-skip-permissions"* ]]
}

@test "DEV_LOOP_AUTOFLUSH=1 with pending BELOW min: no spawn (threshold still applies)" {
  seed_pending 2
  run env DEV_LOOP_AUTOFLUSH=1 HOME="$HOME" PATH="$PATH" STUB_CLAUDE_LOG="$STUB_CLAUDE_LOG" \
      bash "$AF" <<< '{"cwd":"/tmp"}'
  [ "$status" -eq 0 ]
  sleep 0.3
  [ ! -f "$STUB_CLAUDE_LOG" ]
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
