#!/usr/bin/env bats
# Tests for launch-session.sh argument/permission guards.
# (Full launch needs tmux + claude; those paths are covered by manual/integration
# runs. Here we cover the cheap, deterministic guards.)

setup() {
  LS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/launch-session.sh"
}

@test "rejects an invalid permission mode (injection guard)" {
  run bash "$LS" sess "${BATS_TEST_TMPDIR}/wt" "bypassPermissions; rm -rf ~" "prompt"
  [ "$status" -eq 2 ]
}

@test "errors on wrong argument count" {
  run bash "$LS" sess
  [ "$status" -ne 0 ]
}

@test "LO_DRY_RUN prints the resolved session name and exits before tmux/claude" {
  run env LO_DRY_RUN=1 bash "$LS" lo-1 "${BATS_TEST_TMPDIR}/wt" bypassPermissions "prompt"
  [ "$status" -eq 0 ]
  [ "$output" = "session=lo-1" ]
}

@test "LO_RUN_ID makes the session name unique per run" {
  run env LO_RUN_ID=r1 LO_DRY_RUN=1 bash "$LS" lo-1 "${BATS_TEST_TMPDIR}/wt" bypassPermissions "prompt"
  [ "$status" -eq 0 ]
  [ "$output" = "session=lo-1-r1" ]
}

@test "invalid permission mode is still rejected in dry-run (no guard bypass)" {
  run env LO_DRY_RUN=1 bash "$LS" lo-1 "${BATS_TEST_TMPDIR}/wt" "bad; rm -rf ~" "prompt"
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# The tests below drive the real launch path by replacing only the two external
# binaries (tmux, claude) via the LO_TMUX / LO_CLAUDE hooks. Assertions are
# always on what launch-session.sh *did* — its exit code, its message, which
# keys it sent, how many times it polled — never on the stub's canned bytes.
#
# The script is `#!/bin/sh`; these invoke it with `sh`, not `bash`, or the
# shebang is overridden and a bashism would pass here while failing under dash
# in production. (The five tests above predate this file's stub harness and are
# left exactly as they were.)
#
# The executable stub lives under the repo's gitignored .claude/tmp — never
# $TMPDIR or /tmp, where creating and chmod +x-ing an executable is forbidden
# by policy. This mirrors tests/orca-wait.bats.
# ---------------------------------------------------------------------------

REPO_TMP() { printf '%s' "${BATS_TEST_DIRNAME}/../.claude/tmp"; }

mk_tmux_stub() { # -> path of an executable `tmux` test double
  mkdir -p "$(REPO_TMP)"
  local stub="$(REPO_TMP)/tmux-stub-${BATS_TEST_NUMBER}"
  cat > "$stub" <<'STUBEOF'
#!/bin/sh
# Test double for the `tmux` CLI. All state under $STUB_DIR:
#   env-log         one line per call: TMUX=<inherited value> ARGV=<args>
#   captures        counter of capture-pane calls
#   pane            pane text served by capture-pane (absent -> empty)
#   pane-<n>        pane text served on the nth capture-pane call (wins over `pane`)
#   keys            one line per send-keys call (its arguments)
#   has-session-rc  exit code for has-session (absent -> 1, "no such session")
set -u
d="${STUB_DIR:?}"
printf 'TMUX=%s ARGV=%s\n' "${TMUX-<unset>}" "$*" >> "$d/env-log"
case "${1:-}" in
  has-session)
    exit "$(cat "$d/has-session-rc" 2>/dev/null || echo 1)" ;;
  capture-pane)
    n=$(cat "$d/captures" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$d/captures"
    if [ -f "$d/pane-$n" ]; then cat "$d/pane-$n"
    elif [ -f "$d/pane" ]; then cat "$d/pane"; fi ;;
  send-keys)
    shift; printf '%s\n' "$*" >> "$d/keys" ;;
esac
exit 0
STUBEOF
  chmod +x "$stub"
  printf '%s' "$stub"
}

teardown() { rm -f "$(REPO_TMP)/tmux-stub-${BATS_TEST_NUMBER}"; }

# --- pane fixtures, transcribed from real `capture-pane` output of a live
# --- Claude CLI in tmux (measured 2026-08-05). The only edits are trimming
# --- blank filler lines and shortening the rules.
RULE='────────────────────────────────────────'

pane_ready_submitted() { # prompt accepted: the input box is empty
  printf '%s\n' \
    "✶ Transfiguring… (running stop hooks… 6/7 · 5s · ↓ 13 tokens)" \
    "                                        ● high · /effort" \
    "$RULE" \
    "❯ " \
    "$RULE" \
    "" \
    "  ⏵⏵ bypass permissions on (shift+tab to cycle) · ← for agents"
}

pane_ready_unsubmitted() { # THE BUG: prompt typed into the box, never submitted
  printf '%s\n' \
    "                                        ● high · /effort" \
    "$RULE" \
    "❯ ZZPROMPTHEAD you are the worker session for probe-task and this is a long" \
    "  one-line prompt that wrapped onto a second rendered line" \
    "$RULE" \
    "" \
    "  ⏵⏵ bypass permissions on (shift+tab to cycle)"
}

pane_ready_pasted() { # the exact field rendering: the CLI collapsed it to a paste
  printf '%s\n' \
    "                                        ● high · /effort" \
    "$RULE" \
    "❯ [Pasted text #1 +1 lines]" \
    "$RULE" \
    "" \
    "  ⏵⏵ bypass permissions on (shift+tab to cycle)"
}

pane_not_ready() { # matches none of the ready/trust patterns
  printf '%s\n' "Loading…" "NOTREADYMARKER"
}

# --- Task 01: launch-session.sh must not clobber tmux's own TMUX variable ---
# TMUX is tmux's server-socket variable. Assigning it exports the corruption to
# every child tmux, which then tries to connect to a binary path as a socket.
# Measured 2026-08-05: this breaks EVERY launch when the coordinator itself runs
# inside tmux ("error connecting to <path> (Socket operation on non-socket)").

@test "TMUX: the caller's tmux socket reaches the child untouched" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; echo 0 > "$sd/has-session-rc"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      TMUX=SENTINEL-SOCKET,111,0 sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "p"
  [ "$status" -eq 0 ]
  grep -q 'TMUX=SENTINEL-SOCKET,111,0' "$sd/env-log"
}

@test "TMUX: the tmux binary path is never assigned over the socket (regression)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; echo 0 > "$sd/has-session-rc"
  stub="$(mk_tmux_stub)"
  run env STUB_DIR="$sd" LO_TMUX="$stub" LO_CLAUDE=/bin/echo \
      TMUX=SENTINEL-SOCKET,111,0 sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "p"
  [ "$status" -eq 0 ]
  # the assertion that fails on the pre-fix script:
  ! grep -q "TMUX=$stub" "$sd/env-log"
}

@test "TMUX: a caller with no TMUX set still launches (boundary — masks the bug)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; echo 0 > "$sd/has-session-rc"
  run env -u TMUX STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "p"
  [ "$status" -eq 0 ]
  grep -q 'TMUX=<unset>' "$sd/env-log"
}

# --- Task 02: the readiness budget is honoured exactly, and reports ---

@test "LO_READY_TIMEOUT is honoured exactly: floor(timeout/interval) attempts" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_not_ready > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=3 LO_READY_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "p"
  [ "$status" -eq 4 ]
  [ "$(cat "$sd/captures")" = "3" ]
}

@test "a readiness timeout exits 4 and says the REPL was not ready (error contract)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_not_ready > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "p"
  [ "$status" -eq 4 ]
  [[ "$output" == *"REPL not ready"* ]]
}

@test "a readiness timeout reports the last screen, not just the failure" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_not_ready > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "p"
  [ "$status" -eq 4 ]
  [[ "$output" == *"NOTREADYMARKER"* ]]
}

@test "a sub-interval readiness budget still makes exactly one attempt (boundary)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_not_ready > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=1 LO_READY_INTERVAL=2 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "p"
  [ "$status" -eq 4 ]
  [ "$(cat "$sd/captures")" = "1" ]
}

# --- Task 05: submission confirmation (field finding, 2026-08-05) ---
# send-keys exit 0 means "keys reached the pane", NOT "the worker got the
# prompt". A prompt sat unsubmitted in the input box for 45 minutes while the
# launcher printed "ok". Confirm submission, or report a distinct outcome.

@test "a submitted prompt is confirmed and reported as submitted" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_submitted > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"submitted"* ]]
}

@test "a prompt left sitting in the input box is NOT reported as success (exit 5)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_unsubmitted > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "ZZPROMPTHEAD you are the worker"
  [ "$status" -eq 5 ]
  [[ "$output" != *"ok:"* ]]
  [[ "$output" == *"NOT confirmed submitted"* ]]
}

@test "the field's [Pasted text] rendering is caught too, though the prompt text is hidden" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_pasted > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "ZZPROMPTHEAD you are the worker"
  [ "$status" -eq 5 ]
  [[ "$output" == *"NOT confirmed submitted"* ]]
}

@test "an unconfirmed submission reports the last screen so the pane is diagnosable" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_pasted > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 5 ]
  [[ "$output" == *"Pasted text"* ]]
}

@test "an unsubmitted prompt gets the known remedy — one more Enter — then confirms" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  # ready check consumes capture #1; the box is still full at #2, empty at #3.
  pane_ready_unsubmitted > "$sd/pane-1"
  pane_ready_unsubmitted > "$sd/pane-2"
  pane_ready_submitted   > "$sd/pane-3"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=6 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "ZZPROMPTHEAD you are the worker"
  [ "$status" -eq 0 ]
  # the initial Enter plus exactly one remedial Enter
  [ "$(grep -c '^-t lo-1 Enter$' "$sd/keys")" = "2" ]
}

@test "a pane that cannot be captured is never read as a successful submission" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  # ready screen for the readiness check, then nothing at all (session vanished)
  pane_ready_submitted > "$sd/pane-1"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 5 ]
}

@test "submission confirmation is bounded: it does not outlive LO_SUBMIT_TIMEOUT (boundary)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_unsubmitted > "$sd/pane"
  start=$(date +%s)
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=1 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR" bypassPermissions "ZZPROMPTHEAD hello"
  elapsed=$(( $(date +%s) - start ))
  [ "$status" -eq 5 ]
  [ "$elapsed" -lt 10 ]
}

# --- Task t3: status pre-seed at launch (pre-plan_ready blind-spot fix) ---
# A worker that dies during planning leaves no status file, so dead/stalled
# detection cannot see it. When BOTH LO_STATUS_DIR and LO_TASK_ID are set, a
# successful launch pre-seeds phase=pending via status-update.sh. With either
# var unset, behavior is byte-identical to before. A seeding failure warns on
# stderr and never changes the exit code.

@test "pre-seed: a successful launch writes phase=pending with the resolved session name" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_ready_submitted > "$sd/pane"
  st="$BATS_TEST_TMPDIR/status"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_RUN_ID=r7 LO_STATUS_DIR="$st" LO_TASK_ID=t3 \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR/wt" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 0 ]
  [ -f "$st/t3.json" ]
  [ "$(jq -r .phase "$st/t3.json")" = "pending" ]
  [ "$(jq -r .session "$st/t3.json")" = "lo-1-r7" ]
  [ "$(jq -r .worktree "$st/t3.json")" = "$BATS_TEST_TMPDIR/wt" ]
}

@test "pre-seed: with both vars unset no status file is written and stdout is unchanged (boundary)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_ready_submitted > "$sd/pane"
  st="$BATS_TEST_TMPDIR/status"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR/wt" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 0 ]
  [ "$output" = "ok: lo-1 launched + prompt submitted (confirmed)" ]
  [ ! -e "$st" ]
}

@test "pre-seed: LO_STATUS_DIR alone (LO_TASK_ID unset) writes nothing (boundary)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_ready_submitted > "$sd/pane"
  st="$BATS_TEST_TMPDIR/status"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_STATUS_DIR="$st" \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR/wt" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 0 ]
  [ "$output" = "ok: lo-1 launched + prompt submitted (confirmed)" ]
  [ ! -e "$st" ]
}

@test "pre-seed: a failing status-update warns on stderr but the launch still exits 0 (error tolerated)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_ready_submitted > "$sd/pane"
  # a status dir UNDER a regular file: status-update's mkdir -p fails deterministically
  touch "$BATS_TEST_TMPDIR/blocker"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_STATUS_DIR="$BATS_TEST_TMPDIR/blocker/sub" LO_TASK_ID=t3 \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR/wt" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 0 ]
  # grep, not [[ ]]: a false mid-test [[ ]] does not fail a test under this
  # bats/bash combination, which would make these assertions decoration
  printf '%s\n' "$output" | grep -qF "status pre-seed failed"
  printf '%s\n' "$output" | grep -qF "ok: lo-1 launched + prompt submitted (confirmed)"
}

@test "pre-seed: the session-already-exists reuse path also seeds the record" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; echo 0 > "$sd/has-session-rc"
  st="$BATS_TEST_TMPDIR/status"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_STATUS_DIR="$st" LO_TASK_ID=t3 \
      sh "$LS" lo-1 "$BATS_TEST_TMPDIR/wt" bypassPermissions "p"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "session=lo-1"
  [ "$(jq -r .phase "$st/t3.json")" = "pending" ]
  [ "$(jq -r .session "$st/t3.json")" = "lo-1" ]
  [ "$(jq -r .worktree "$st/t3.json")" = "$BATS_TEST_TMPDIR/wt" ]
}
