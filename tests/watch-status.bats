#!/usr/bin/env bats
# Tests for watch-status.sh escalation surfacing (exit 5).

bats_require_minimum_version 1.5.0

setup() {
  WS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/watch-status.sh"
  ORCH="${BATS_TEST_TMPDIR}/.orchestration"
  mkdir -p "$ORCH/status" "$ORCH/escalations" "$ORCH/questions"
}

@test "exits 5 when an escalation is pending (wakes coordinator, no long wait)" {
  printf '{"task":"t1","phase":"implementing"}' > "$ORCH/status/t1.json"
  printf '{"taskId":"t1","rule":"git_force_push"}' > "$ORCH/escalations/e1.json"
  run bash "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 5 ]
  [[ "$output" == *"escalation pending"* ]]
  [[ "$output" == *"t1"* ]]
}

@test "escalation: triage line carries the record ts and the status phase/updatedAt (normal)" {
  printf '{"task":"t1","phase":"implementing","updatedAt":"2026-08-20T10:00:00Z"}' > "$ORCH/status/t1.json"
  printf '{"taskId":"t1","rule":"git_force_push","ts":"2026-08-20T09:55:00Z"}' > "$ORCH/escalations/e1.json"
  run bash "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 5 ]
  [[ "$output" == *"recorded 2026-08-20T09:55:00Z"* ]]
  [[ "$output" == *"phase=implementing @2026-08-20T10:00:00Z"* ]]
}

@test "escalation: a malformed record still exits 5 with the '?' fallback (error)" {
  printf '{not valid json' > "$ORCH/escalations/e1.json"
  run bash "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 5 ]
  [[ "$output" == *"escalation pending"* ]]
  [[ "$output" == *"?"* ]]
}

@test "escalation: a record whose taskId has no status file renders phase=? @? (boundary)" {
  printf '{"taskId":"tGhost","rule":"git_force_push","ts":"2026-08-20T09:55:00Z"}' > "$ORCH/escalations/e1.json"
  run bash "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 5 ]
  [[ "$output" == *"phase=? @?"* ]]
}

@test "no escalation: normal completion still exits 0" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run bash "$WS" "$ORCH/status" done 1 5 1
  [ "$status" -eq 0 ]
}

@test "empty escalations dir does not false-trigger exit 5" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run bash "$WS" "$ORCH/status" done 1 5 1
  [ "$status" -eq 0 ]
}

# ---- liveness (dead-worker detection) ----

@test "liveness: a non-terminal task with a dead tmux session aborts (exit 3)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=false bash "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 3 ]
  [[ "$output" == *"dead worker"* ]]
}

@test "liveness: a live session is not flagged and reaches the target (exit 0)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=true bash "$WS" "$ORCH/status" implementing 1 5 1
  [ "$status" -eq 0 ]
}

@test "liveness: a terminal phase is not liveness-checked even if session is dead" {
  printf '{"task":"t1","phase":"done","session":"lo-x"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=false bash "$WS" "$ORCH/status" done 1 5 1
  [ "$status" -eq 0 ]
}

@test "liveness: no session field → not checked (backward compat)" {
  printf '{"task":"t1","phase":"implementing"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=false bash "$WS" "$ORCH/status" implementing 1 5 1
  [ "$status" -eq 0 ]
}

@test "liveness: unresolvable tmux disables liveness (no false dead-worker abort)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  # tmux binary can't be resolved → skip liveness, do not flag everything dead
  run env WATCH_TMUX=/nonexistent/tmux bash "$WS" "$ORCH/status" implementing 1 3 1
  [ "$status" -eq 0 ]
}

# ---- per-phase deadlines (LO_PHASE_TIMEOUTS) --------------------------------
# One flat timeout gave a plan phase and a long implement phase the same budget.
# The budget is now keyed on the TARGET phase of this wait, and every run states
# which budget it is using and where that budget came from.
#
# These invoke the script with `sh`, not `bash`: it is `#!/bin/sh`, and `bash`
# would override the shebang and let a bashism pass here but fail under dash.
# (The eight tests above predate this and are left exactly as they were — note
# they all pass the 4th positional argument, which still wins.)

@test "per-phase: the target phase's entry supplies the budget" {
  printf '{"task":"t1","phase":"plan_ready"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=900,impl_done=3600" \
      sh "$WS" "$ORCH/status" plan_ready 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=900s target=plan_ready source=LO_PHASE_TIMEOUTS"* ]]
}

@test "per-phase: the SAME env string yields a different budget for a different target" {
  printf '{"task":"t1","phase":"impl_done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=900,impl_done=3600" \
      sh "$WS" "$ORCH/status" impl_done 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=3600s target=impl_done source=LO_PHASE_TIMEOUTS"* ]]
}

@test "per-phase: with no env at all the default budget is used and named" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=3600s target=done source=default"* ]]
}

@test "per-phase: an explicitly passed timeout argument wins over the env" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="done=900" sh "$WS" "$ORCH/status" done 1 42 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=42s target=done source=arg"* ]]
}

@test "per-phase: a target absent from the env falls back to the default (boundary)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=900" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=3600s target=done source=default"* ]]
}

@test "per-phase: an empty env value is treated as unset, not as an error (boundary)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"source=default"* ]]
}

@test "per-phase: a trailing comma is tolerated (boundary)" {
  printf '{"task":"t1","phase":"plan_ready"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=900," sh "$WS" "$ORCH/status" plan_ready 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=900s"* ]]
}

@test "per-phase: the env budget actually bounds the wait, and the TIMEOUT line names it" {
  printf '{"task":"t1","phase":"pending"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="done=1" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 2 ]
  [[ "$output" == *"TIMEOUT (1s, source=LO_PHASE_TIMEOUTS)"* ]]
}

@test "per-phase: a non-numeric budget is refused, never silently defaulted (error)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=abc" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 4 ]
  [[ "$output" == *"plan_ready=abc"* ]]
}

@test "per-phase: a typo'd phase name is refused, not silently ignored (error)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="notaphase=900" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 4 ]
  [[ "$output" == *"notaphase"* ]]
}

@test "per-phase: a zero budget is refused — it would time out instantly (boundary)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="done=0" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 4 ]
}

@test "per-phase: an entry with no '=' is refused (error)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 4 ]
}

# ---- question channel (exit 6) ----------------------------------------------
# A worker question (an ask-coordinator.sh record in questions/) wakes the
# coordinator with exit 6 within one poll interval. Precedence per iteration:
# escalation(5) -> question(6) -> failed/dead(3) -> all-reached(0).

@test "question: exits 6 with the task and question text (normal)" {
  printf '{"task":"t1","phase":"implementing"}' > "$ORCH/status/t1.json"
  printf '{"taskId":"t1","question":"Which DB?"}' > "$ORCH/questions/t1.json"
  run sh "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 6 ]
  [[ "$output" == *"question pending"* ]]
  [[ "$output" == *"t1"* ]]
  [[ "$output" == *"Which DB?"* ]]
}

@test "question: recurs on relaunch while the record remains (normal)" {
  printf '{"task":"t1","phase":"implementing"}' > "$ORCH/status/t1.json"
  printf '{"taskId":"t1","question":"Which DB?"}' > "$ORCH/questions/t1.json"
  run sh "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 6 ]
  run sh "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 6 ]
}

@test "question: escalation wins when both are pending (precedence)" {
  printf '{"task":"t1","phase":"implementing"}' > "$ORCH/status/t1.json"
  printf '{"taskId":"t1","question":"Which DB?"}' > "$ORCH/questions/t1.json"
  printf '{"taskId":"t1","rule":"git_force_push"}' > "$ORCH/escalations/e1.json"
  run sh "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 5 ]
  [[ "$output" == *"escalation pending"* ]]
}

@test "question: checked before a failed session (precedence)" {
  printf '{"task":"t1","phase":"failed"}' > "$ORCH/status/t1.json"
  printf '{"taskId":"t1","question":"Which DB?"}' > "$ORCH/questions/t1.json"
  run sh "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 6 ]
}

@test "question: empty questions dir does not false-trigger (boundary)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run sh "$WS" "$ORCH/status" done 1 5 1
  [ "$status" -eq 0 ]
}

@test "question: a malformed record still exits 6 with the '?' fallback (boundary)" {
  printf '{"task":"t1","phase":"implementing"}' > "$ORCH/status/t1.json"
  printf 'not-json' > "$ORCH/questions/t1.json"
  run sh "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 6 ]
  [[ "$output" == *"?"* ]]
}

# ---- stall detection (exit 7) -----------------------------------------------
# tmux-worker-stalled.sh reporting 1 for a live non-terminal session surfaces
# as exit 7. rc 0/2, a broken/missing script, missing tmux, and a missing
# session field are all NOT stalled. Precedence: failed(3) and all-reached(0)
# win over stall(7). Stubs are plain sh files (watch invokes them via `sh`, so
# they need no execute bit).

@test "stall: a stalled live worker exits 7 with task and session (normal)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=true WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  [[ "$output" == *"worker stalled"* ]]
  [[ "$output" == *"t1"* ]]
  [[ "$output" == *"lo-x"* ]]
}

@test "stall: unknown (rc 2) is not stalled — the wait continues to timeout (boundary)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 2\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=true WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 2 ]
  [[ "$output" != *"worker stalled"* ]]
}

@test "stall: a missing stall script disables the check, never aborts (boundary)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=true WATCH_STALL_SCRIPT=/nonexistent/stall.sh \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 2 ]
}

@test "stall: a status record with no session field is not checked (boundary)" {
  printf '{"task":"t1","phase":"implementing"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=true WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 2 ]
}

@test "stall: unresolvable tmux disables the stall check too (boundary)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=/nonexistent/tmux WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 2 ]
}

@test "stall: a crashing stall script (rc 127) never aborts the watch loop (error)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 127\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=true WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 2 ]
  [[ "$output" != *"worker stalled"* ]]
}

@test "stall: all-reached wins over a stalled pane (precedence)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=true WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" implementing 1 2 1
  [ "$status" -eq 0 ]
}

@test "stall: a dead session is a failed worker (3), never a stall (precedence)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=false WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 3 ]
  [[ "$output" == *"dead worker"* ]]
}

# Substring assertions below use grep, not `[[ "$output" == *"..."* ]]`: BATS
# executes test bodies via eval in its own parent bash process (not a fresh
# `bash -c`), and on this machine's bash 3.2.57 that context's `[[ ]]` glob
# matching has been observed to report a false MATCH for a substring that is
# genuinely absent from $output (verified 2026-08-14: `[[ "$output" ==
# *"(usage limit)"* ]]` passed against output containing no such text, while
# `grep -qF` on the same value correctly failed). This is the same
# bash-version/platform pitfall PR #94 hit — the tools_guidance note "prefer
# grep for pattern matching" exists for exactly this reason.
assert_output_has() { printf '%s\n' "$output" | grep -qF -- "$1"; }
refute_output_has() { ! printf '%s\n' "$output" | grep -qF -- "$1"; }

# ---- reached-target skip (issue #88) -----------------------------------------
# A task whose phase already satisfies the watch target must never be
# stall-checked — its silence is exactly what the session prompt ordered
# ("signal and wait"), not a wedged worker. This is a pure boolean gate
# (r < target_rank) with no error path by construction, so per
# testing-quality-minimum-case-set's edge-case allowance the trio below is
# normal (above target) + two boundaries (exactly at target; the differential
# dead-worker gate) + one contrast case proving the gate does not over-fire.


# The two tests below need a SECOND task that never reaches target, so the
# "all reached" exit-0 branch (which runs before the stall check on every
# poll) can't short-circuit the result and mask whether the stall-skip gate
# actually fired. The stub branches per-session ($1) so only t1 reports
# stalled — t2 is deliberately never-reaching and never-stalled filler.

@test "reached-target: a task ABOVE the target with a stalled pane exits 0, not 7 (normal)" {
  printf '{"task":"t1","phase":"impl_done","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf '{"task":"t2","phase":"pending","session":"lo-y"}' > "$ORCH/status/t2.json"
  printf 'case "$1" in lo-x) exit 1 ;; *) exit 0 ;; esac\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=true WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" implementing 2 2 1
  [ "$status" -eq 2 ]
  refute_output_has "worker stalled"
}

@test "reached-target: a task EXACTLY AT the target with a stalled pane exits 0, not 7 (boundary)" {
  printf '{"task":"t1","phase":"impl_done","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf '{"task":"t2","phase":"implementing","session":"lo-y"}' > "$ORCH/status/t2.json"
  printf 'case "$1" in lo-x) exit 1 ;; *) exit 0 ;; esac\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=true WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 2 2 1
  [ "$status" -eq 2 ]
  refute_output_has "worker stalled"
}

@test "reached-target: a task ONE RANK BELOW the target is still stall-checked (contrast)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=true WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "worker stalled"
}

@test "reached-target: a task AT target whose session VANISHED still reports dead worker (differential gate, boundary)" {
  printf '{"task":"t1","phase":"impl_done","session":"lo-x"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=false sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 3 ]
  assert_output_has "dead worker"
}

# ---- stall reason surfacing (issue #89) --------------------------------------
# When a genuine stall IS reported, enrich the bare message with the
# machine-readable reason read from the pane SCROLLBACK (capture-pane -S,
# not the visible region). fake_tmux's capture-pane only returns the full
# fixture (with the limit line near the top) when the invocation includes
# "-S -1000"; without it, only the last 24 lines come back — so a test that
# omits -S would fail here exactly the way it would against real tmux.

fake_tmux() {
  path="$1"; outfile="${2:-/dev/null}"; caprc="${3:-0}"; hsrc="${4:-0}"
  cat > "$path" <<SCRIPT
#!/bin/sh
case "\$1" in
  has-session) exit $hsrc ;;
  capture-pane)
    printf '%s\n' "\$*" >> "\${FAKE_TMUX_LOG:-/dev/null}"
    [ "$caprc" = "0" ] || exit $caprc
    case " \$* " in
      *" -S -1000 "*) cat "$outfile" 2>/dev/null ;;
      *) tail -n 24 "$outfile" 2>/dev/null ;;
    esac
    exit 0
    ;;
  *) exit 0 ;;
esac
SCRIPT
  chmod +x "$path"
}

@test "limit: scrollback-only reset line is surfaced with the reset time (normal, scrollback proof)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf "You've hit your session limit \xc2\xb7 resets 2:50pm Asia/Seoul\n" > "$pane"
  i=2; while [ "$i" -le 50 ]; do printf 'filler line %d\n' "$i" >> "$pane"; i=$((i+1)); done
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  log="$BATS_TEST_TMPDIR/tmux.log"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" FAKE_TMUX_LOG="$log" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "usage limit"
  assert_output_has "resets 2:50pm Asia/Seoul"
  grep -q -- "-S -1000" "$log"
}

# review r1/F1: the script is `#!/bin/sh` and invoked via `sh` on ubuntu CI,
# where /bin/sh is dash — dash's printf does not implement `\xNN` hex escapes
# (verified 2026-08-14: `dash -c "printf 'A\xc2\xb7B\n'"` prints the literal
# 9-byte text `A\xc2\xb7B`, not the middle-dot character), so classify_stall's
# annotations must use octal escapes (`\302\267`, `\342\200\224`), which dash
# and macOS sh both decode correctly. These two tests invoke dash directly —
# not the generic `sh` this suite otherwise uses — because on THIS machine
# /bin/sh is bash-in-POSIX-mode and already decodes `\xNN` fine, so a test
# run via plain `sh` cannot locally reproduce (or guard) the dash-specific
# regression; only an explicit dash invocation can prove it red/green here.

@test "portability: the usage-limit annotation is dash-decodable, not raw \\xNN (regression, F1)" {
  command -v dash >/dev/null 2>&1 || skip "dash not available on this runner"
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf "You've hit your session limit \xc2\xb7 resets 2:50pm Asia/Seoul\n" > "$pane"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      dash "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "usage limit"
  refute_output_has '\xc2'
  refute_output_has '\xb7'
}

@test "portability: the chooser annotation is dash-decodable, not raw \\xNN (regression, F1)" {
  command -v dash >/dev/null 2>&1 || skip "dash not available on this runner"
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf 'Enter to confirm \xc2\xb7 Esc to cancel\n' > "$pane"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      dash "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "chooser pending"
  refute_output_has '\xe2'
  refute_output_has '\x80'
  refute_output_has '\x94'
}

@test "limit: a limit line with no 'resets' tail annotates bare usage-limit (boundary)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf "You've hit your weekly limit\n" > "$pane"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "(usage limit)"
  refute_output_has "resets"
}

@test "limit: a failing capture-pane never aborts the watch — bare stall, still exit 7 (error)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "/dev/null" 1
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "worker stalled"
  refute_output_has "usage limit"
}

@test "chooser: an interactive chooser within the last 30 lines is reported as chooser pending (normal)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf 'Enter to confirm \xc2\xb7 Esc to cancel\n' > "$pane"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "chooser pending"
}

@test "chooser: a confirm hint outside the last 30 lines is stale, not classified as chooser (boundary)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf 'Enter to confirm \xc2\xb7 Esc to cancel\n' > "$pane"
  i=2; while [ "$i" -le 50 ]; do printf 'filler line %d\n' "$i" >> "$pane"; i=$((i+1)); done
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "worker stalled"
  refute_output_has "chooser pending"
}

@test "chooser: usage-limit wins over chooser when both patterns match (precedence)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf "You've hit your session limit \xc2\xb7 resets 2:50pm Asia/Seoul\n" > "$pane"
  printf 'Enter to confirm \xc2\xb7 Esc to cancel\n' >> "$pane"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "usage limit"
  refute_output_has "chooser pending"
}

@test "LO_LIMIT_EXTRA: a custom substring is additionally classified as usage-limit (normal)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf 'CUSTOM_QUOTA_HIT\n' > "$pane"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" LO_LIMIT_EXTRA="CUSTOM_QUOTA_HIT" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "usage limit"
}

@test "LO_LIMIT_EXTRA: unset means default pattern only — no accidental off switch (boundary)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf 'CUSTOM_QUOTA_HIT\n' > "$pane"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "worker stalled"
  refute_output_has "usage limit"
}

@test "LO_LIMIT_EXTRA: a value absent from the pane falls through cleanly, no crash (error)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  pane="$BATS_TEST_TMPDIR/pane.txt"
  printf 'nothing interesting here\n' > "$pane"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "$pane"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" LO_LIMIT_EXTRA="NEVER_APPEARS" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "worker stalled"
  refute_output_has "usage limit"
}

@test "degradation: an empty pane capture never aborts the watch — bare stall (normal)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  fake_tmux "$BATS_TEST_TMPDIR/fake-tmux" "/dev/null"
  run env WATCH_TMUX="$BATS_TEST_TMPDIR/fake-tmux" \
      WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 7 ]
  assert_output_has "worker stalled"
}

@test "degradation: WATCH_TMUX unresolvable disables classification the same as it disables the stall check (boundary)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  printf 'exit 1\n' > "$BATS_TEST_TMPDIR/stall_stub.sh"
  run env WATCH_TMUX=/nonexistent/tmux WATCH_STALL_SCRIPT="$BATS_TEST_TMPDIR/stall_stub.sh" \
      sh "$WS" "$ORCH/status" impl_done 1 2 1
  [ "$status" -eq 2 ]
  refute_output_has "worker stalled"
}

# ---- collector integration (LO_GRAPH + LO_WORKTREES_ROOT, issue #167) -------
# Workers write status worker-locally now; watch pulls those records into the
# canonical dir via collect-status.sh once per poll iteration, but only when
# BOTH envs are set. Either env unset must be byte-identical to old behavior:
# a worker-local-only record is invisible and the wait times out as before.

@test "collector: both envs set — a worker-local record is collected and the target is reached" {
  GRAPH="$BATS_TEST_TMPDIR/graph.json"
  printf '{"tasks":[{"id":"t1","deps":[]}]}' > "$GRAPH"
  WROOT="$BATS_TEST_TMPDIR/worktrees"
  mkdir -p "$WROOT/wt1/.orchestration/status"
  printf '{"task":"t1","phase":"impl_done","updatedAt":"2026-01-01T00:05:00Z"}' \
    > "$WROOT/wt1/.orchestration/status/t1.json"
  run env LO_GRAPH="$GRAPH" LO_WORKTREES_ROOT="$WROOT" \
      sh "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 0 ]
  [ -f "$ORCH/status/t1.json" ]
  [ "$(jq -r '.phase' "$ORCH/status/t1.json")" = "impl_done" ]
}

@test "collector: envs unset — a worker-local-only record is NOT seen (old behavior)" {
  WROOT="$BATS_TEST_TMPDIR/worktrees"
  mkdir -p "$WROOT/wt1/.orchestration/status"
  printf '{"task":"t1","phase":"impl_done","updatedAt":"2026-01-01T00:05:00Z"}' \
    > "$WROOT/wt1/.orchestration/status/t1.json"
  run sh "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 2 ]
  assert_output_has "TIMEOUT"
  [ ! -e "$ORCH/status/t1.json" ]
}

@test "collector: only LO_GRAPH set (LO_WORKTREES_ROOT unset) — old behavior, no collector call" {
  GRAPH="$BATS_TEST_TMPDIR/graph.json"
  printf '{"tasks":[{"id":"t1","deps":[]}]}' > "$GRAPH"
  WROOT="$BATS_TEST_TMPDIR/worktrees"
  mkdir -p "$WROOT/wt1/.orchestration/status"
  printf '{"task":"t1","phase":"impl_done","updatedAt":"2026-01-01T00:05:00Z"}' \
    > "$WROOT/wt1/.orchestration/status/t1.json"
  run env LO_GRAPH="$GRAPH" sh "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 2 ]
  [ ! -e "$ORCH/status/t1.json" ]
}

@test "collector: a bad LO_GRAPH path warns on stderr and the watch still times out normally, not an abort (error)" {
  run --separate-stderr env LO_GRAPH="$BATS_TEST_TMPDIR/does-not-exist.json" \
      LO_WORKTREES_ROOT="$BATS_TEST_TMPDIR/worktrees" \
      sh "$WS" "$ORCH/status" done 1 5 1
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"collect failed"* ]]
}
