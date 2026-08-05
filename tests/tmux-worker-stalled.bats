#!/usr/bin/env bats
# Tests for tmux-worker-stalled.sh — the third worker state the alive/dead split
# cannot express, for the tmux substrate. Mirrors tests/orca-worker-stalled.bats.
#
# Driven by a tmux test double plus a pinned clock, so no live CLI is involved.
# Silence is accumulated ACROSS invocations (tmux exposes no "content last
# changed" timestamp), so most tests call the script twice: once to record the
# first observation, once with the clock advanced.
#
# The script is `#!/bin/sh`; invoke it with `sh`, not `bash`, or the shebang is
# overridden and a bashism would pass every test here while failing under dash
# in production.
#
# The executable stub lives under the repo's gitignored .claude/tmp — never
# $TMPDIR or /tmp, where creating and chmod +x-ing an executable is forbidden by
# policy. Non-executable fixture data uses $BATS_TEST_TMPDIR.

setup() {
  WS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/tmux-worker-stalled.sh"
  SESS=lo-1
  SD="$BATS_TEST_TMPDIR/sd"; mkdir -p "$SD"
  STATE="$BATS_TEST_TMPDIR/state"; mkdir -p "$STATE"
  NOW=1700000000
}

REPO_TMP() { printf '%s' "${BATS_TEST_DIRNAME}/../.claude/tmp"; }

mk_tmux_stub() { # -> path of an executable `tmux` test double
  mkdir -p "$(REPO_TMP)"
  local stub="$(REPO_TMP)/stall-stub-${BATS_TEST_NUMBER}"
  cat > "$stub" <<'STUBEOF'
#!/bin/sh
# Test double for `tmux`. State under $STUB_DIR:
#   pane            text served by capture-pane (absent -> empty output)
#   capture-rc      exit code for capture-pane (absent -> 0)
#   has-session-rc  exit code for has-session (absent -> 0, "session exists")
#   activity        value served for #{window_activity} (absent -> 0)
set -u
d="${STUB_DIR:?}"
case "${1:-}" in
  has-session)  exit "$(cat "$d/has-session-rc" 2>/dev/null || echo 0)" ;;
  capture-pane)
    rc="$(cat "$d/capture-rc" 2>/dev/null || echo 0)"
    [ "$rc" = "0" ] || exit "$rc"
    [ -f "$d/pane" ] && cat "$d/pane"
    exit 0 ;;
  display-message) cat "$d/activity" 2>/dev/null || echo 0; exit 0 ;;
esac
exit 0
STUBEOF
  chmod +x "$stub"
  printf '%s' "$stub"
}

teardown() { rm -f "$(REPO_TMP)/stall-stub-${BATS_TEST_NUMBER}"; }

# run the detector once, with the clock pinned to $1
probe() { # $1 = now (epoch seconds); rest = extra env assignments
  local now="$1"; shift
  run env STUB_DIR="$SD" LO_STALL_TMUX="$STUB" LO_STALL_STATE_DIR="$STATE" \
      LO_STALL_NOW="$now" "$@" sh "$WS" "$SESS"
}

working_pane() { printf '%s\n' "✻ Thinking… (${1:-3}s · ↑ 1.2k tokens)" "❯ "; }
wedged_pane()  { printf '%s\n' "❯ [Pasted text #1 +1 lines]" "  ⏵⏵ bypass permissions on"; }

# --- normal + the control that proves the detector discriminates -------------

@test "a pane unchanged past the threshold is stalled (exit 1) and names the session" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW"; [ "$status" -eq 0 ]              # first observation
  probe "$((NOW + 900))"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[stalled]"* ]]
  [[ "$output" == *"$SESS"* ]]
  [[ "$output" == *"900s"* ]]
}

@test "CONTROL: same clock, same state — a pane that CHANGED is progressing (exit 0)" {
  # The opposite-verdict run. Without it, a detector that always returned 1
  # would pass the test above; this is what proves it discriminates.
  STUB="$(mk_tmux_stub)"; working_pane 3 > "$SD/pane"
  probe "$NOW"; [ "$status" -eq 0 ]
  working_pane 903 > "$SD/pane"                  # the elapsed counter ticked
  probe "$((NOW + 900))"
  [ "$status" -eq 0 ]
}

@test "REJECTED CANDIDATE: a fresh window_activity does not rescue an unchanged pane" {
  # Measured 2026-08-05: #{window_activity} tracked `now` identically for a pane
  # redrawing the SAME bytes and for a working pane, exactly as Orca's
  # lastOutputAt did. This test fails if the signal is ever reimplemented on it.
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW"; [ "$status" -eq 0 ]
  echo "$((NOW + 900))" > "$SD/activity"         # output "0 seconds ago"
  probe "$((NOW + 900))"
  [ "$status" -eq 1 ]
}

@test "a worker busy in Stop hooks is progressing, not stalled (hook latency)" {
  # Measured 2026-08-05: a worker running its Stop-hook chain renders
  # "running stop hooks… 6/7 · 1m 36s" with a ticking counter, so the pane keeps
  # changing. Hook latency must never read as a stall.
  STUB="$(mk_tmux_stub)"
  printf '%s\n' "✢ Finagling… (running stop hooks… 6/7 · 1m 36s · ↓ 629 tokens)" "❯ " > "$SD/pane"
  probe "$NOW"; [ "$status" -eq 0 ]
  printf '%s\n' "✢ Finagling… (running stop hooks… 7/7 · 1m 55s · ↓ 629 tokens)" "❯ " > "$SD/pane"
  probe "$((NOW + 900))"
  [ "$status" -eq 0 ]
}

# --- boundaries -------------------------------------------------------------

@test "exactly at the threshold counts as stalled (boundary)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW"; [ "$status" -eq 0 ]
  probe "$((NOW + 600))"
  [ "$status" -eq 1 ]
}

@test "one second under the threshold is not stalled (boundary)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW"; [ "$status" -eq 0 ]
  probe "$((NOW + 599))"
  [ "$status" -eq 0 ]
}

@test "the first observation is never a stall, and records state (boundary)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW"
  [ "$status" -eq 0 ]
  [ -f "$STATE/$SESS.stall" ]
}

@test "LO_STALL_SEC overrides the threshold" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW" LO_STALL_SEC=30; [ "$status" -eq 0 ]
  probe "$((NOW + 30))" LO_STALL_SEC=30
  [ "$status" -eq 1 ]
}

@test "a small backwards clock step is precision, not skew — still progressing (boundary)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW"; [ "$status" -eq 0 ]
  probe "$((NOW - 3))"
  [ "$status" -eq 0 ]
}

# --- unknown: every one of these must be 2, never 1 -------------------------
# Killing a working agent is the damaging direction, so "cannot tell" is never
# allowed to read as "stalled".

@test "a large backwards clock step is real skew, not a stall (exit 2)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW"; [ "$status" -eq 0 ]
  probe "$((NOW - 60))"
  [ "$status" -eq 2 ]
}

@test "a missing session argument is a usage error (exit 2)" {
  STUB="$(mk_tmux_stub)"
  run env STUB_DIR="$SD" LO_STALL_TMUX="$STUB" LO_STALL_STATE_DIR="$STATE" sh "$WS"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage"* ]]
}

@test "a non-numeric threshold is refused rather than silently defaulted (exit 2)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW" LO_STALL_SEC=abc
  [ "$status" -eq 2 ]
}

@test "a zero threshold is refused (boundary — it would flag every worker)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  probe "$NOW" LO_STALL_SEC=0
  [ "$status" -eq 2 ]
}

@test "an unresolvable tmux binary is unknown, never stalled (exit 2)" {
  STUB=/nonexistent/tmux; wedged_pane > "$SD/pane"
  probe "$NOW"
  [ "$status" -eq 2 ]
}

@test "a failing capture-pane is unknown, not stalled (exit 2)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"; echo 1 > "$SD/capture-rc"
  probe "$NOW"
  [ "$status" -eq 2 ]
}

@test "an empty pane capture is unknown, not stalled (boundary, exit 2)" {
  STUB="$(mk_tmux_stub)"   # no pane file -> capture-pane prints nothing
  probe "$NOW"
  [ "$status" -eq 2 ]
}

@test "a malformed state file is unknown, and self-heals for the next poll (exit 2)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  printf 'garbage-with-no-timestamp\n' > "$STATE/$SESS.stall"
  probe "$NOW"
  [ "$status" -eq 2 ]
  # rewritten as a fresh observation, so the NEXT poll can decide
  probe "$((NOW + 900))"
  [ "$status" -eq 1 ]
}

@test "a state file with a non-numeric timestamp is unknown, not stalled (exit 2)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  printf 'deadbeef notanumber\n' > "$STATE/$SESS.stall"
  probe "$NOW"
  [ "$status" -eq 2 ]
}

@test "an unwritable state dir is unknown, not stalled (exit 2)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  STATE="$BATS_TEST_TMPDIR/ro"; mkdir -p "$STATE"; chmod 500 "$STATE"
  probe "$NOW"
  chmod 700 "$STATE"
  [ "$status" -eq 2 ]
}

@test "a session name that could escape the state dir is refused (exit 2)" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"
  run env STUB_DIR="$SD" LO_STALL_TMUX="$STUB" LO_STALL_STATE_DIR="$STATE" \
      LO_STALL_NOW="$NOW" sh "$WS" "../../etc/passwd"
  [ "$status" -eq 2 ]
}

# --- the alive/dead question belongs to watch-status.sh, not here -----------

@test "a session that is gone is NOT reported as a stall — that is watch-status.sh's question" {
  STUB="$(mk_tmux_stub)"; wedged_pane > "$SD/pane"; echo 1 > "$SD/has-session-rc"
  probe "$NOW"
  [ "$status" -eq 0 ]
}
