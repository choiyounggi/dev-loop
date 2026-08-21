#!/usr/bin/env bats
# Tests for token-report.sh — per-session + total token usage report from
# Claude Code session transcript JSONL files (calls, output tokens, cache hit
# %, final/peak context), used at orchestration run teardown.

setup() {
  TR="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/token-report.sh"
  FIX="${BATS_TEST_DIRNAME}/fixtures/token-report"
  TAB="$(printf '\t')"
  # Isolate from ambient orchestration env (mirrors launch-session.bats).
  unset LO_CTX_WARN
}

# --- normal ------------------------------------------------------------

@test "prints 2 session rows + TOTAL with hand-computed sums" {
  run sh "$TR" "$FIX"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qE "^session-a${TAB}3${TAB}500${TAB}65\.0${TAB}2000${TAB}2000\$"
  printf '%s\n' "$output" | grep -qE "^session-b${TAB}2${TAB}200${TAB}50\.0${TAB}1000${TAB}1000\$"
  printf '%s\n' "$output" | grep -qE "^TOTAL${TAB}5${TAB}700${TAB}60\.0${TAB}2000${TAB}2000\$"
}

@test "skips a non-usage line and an invalid-JSON line without crashing (session-a has 5 lines, 3 usage)" {
  run sh "$TR" "$FIX/session-a.jsonl"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qE "^session-a${TAB}3${TAB}500${TAB}65\.0${TAB}2000${TAB}2000\$"
}

# --- error (exit 2) -----------------------------------------------------

@test "no args -> exit 2" {
  run sh "$TR"
  [ "$status" -eq 2 ]
}

@test "nonexistent source path -> exit 2" {
  run sh "$TR" "$FIX/does-not-exist.jsonl"
  [ "$status" -eq 2 ]
}

@test "--cwd given with no following value -> exit 2" {
  run sh "$TR" --cwd
  [ "$status" -eq 2 ]
}

@test "--cwd whose mapped directory does not exist -> exit 2, stderr names the attempted path" {
  fakehome="$BATS_TEST_TMPDIR/fakehome-missing"
  run env HOME="$fakehome" sh "$TR" --cwd "/Users/nope/project" .
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF -- "-Users-nope-project"
}

# --- error (exit 4) -----------------------------------------------------

@test "LO_CTX_WARN=abc (non-numeric) -> exit 4" {
  run env LO_CTX_WARN=abc sh "$TR" "$FIX"
  [ "$status" -eq 4 ]
}

@test "LO_CTX_WARN=0 -> exit 4 (boundary: not just non-numeric, <= 0 also refused)" {
  run env LO_CTX_WARN=0 sh "$TR" "$FIX"
  [ "$status" -eq 4 ]
}

# --- boundary ------------------------------------------------------------

@test "jsonl with zero usage lines -> zero row, exit 0 (boundary)" {
  run sh "$TR" "$FIX/edge/zero-usage.jsonl"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qE "^zero-usage${TAB}0${TAB}0${TAB}0\.0${TAB}0${TAB}0\$"
}

@test "empty file -> zero row, exit 0 (boundary)" {
  run sh "$TR" "$FIX/edge/empty.jsonl"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qE "^empty${TAB}0${TAB}0${TAB}0\.0${TAB}0${TAB}0\$"
}

@test "peak-context warning fires on stderr when LO_CTX_WARN is below the fixture's peak" {
  run env LO_CTX_WARN=1500 sh "$TR" "$FIX/session-a.jsonl"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "warn: session-a peak context 2000 >= 1500"
}

@test "no warning printed when LO_CTX_WARN is above the fixture's peak" {
  run env LO_CTX_WARN=3000 sh "$TR" "$FIX/session-a.jsonl"
  [ "$status" -eq 0 ]
  ! printf '%s\n' "$output" | grep -q "warn:"
}

@test "a relative source with no --cwd resolves against the caller's own cwd" {
  cd "$FIX"
  run sh "$TR" "session-a.jsonl"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qE "^session-a${TAB}3${TAB}500${TAB}65\.0${TAB}2000${TAB}2000\$"
}

@test "--cwd maps an absolute project path to ~/.claude/projects/<escaped> and resolves a relative source against it" {
  fakehome="$BATS_TEST_TMPDIR/fakehome-ok"
  projdir="$fakehome/.claude/projects/-Users-x-project"
  mkdir -p "$projdir"
  cp "$FIX/session-a.jsonl" "$projdir/lo-1.jsonl"
  run env HOME="$fakehome" sh "$TR" --cwd "/Users/x/project" .
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qE "^lo-1${TAB}3${TAB}500${TAB}65\.0${TAB}2000${TAB}2000\$"
}
