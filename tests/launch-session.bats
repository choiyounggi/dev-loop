#!/usr/bin/env bats
# Tests for launch-session.sh argument/permission guards.
# (Full launch needs tmux + claude; those paths are covered by manual/integration
# runs. Here we cover the cheap, deterministic guards.)

setup() {
  LS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/launch-session.sh"
  # Isolate from ambient orchestration env. A worker session running this
  # suite inherits LO_RUN_ID/LO_STATUS_DIR/LO_TASK_ID and GROUNDWORK_* from
  # its own launch (issue #100) — `env VAR=val` in a test's `run` line MERGES
  # with, not replaces, the inherited environment, so these leak into
  # launch-session.sh (and the status-update.sh it calls) unless absent here.
  # Tests that need a value set it explicitly via `run env VAR=val ...`,
  # which overrides this unset for that one invocation.
  unset LO_RUN_ID LO_DRY_RUN LO_TMUX LO_CLAUDE \
        LO_READY_TIMEOUT LO_READY_INTERVAL LO_READY_EXTRA LO_TRUST_EXTRA LO_TRUST_KEYS \
        LO_SUBMIT_TIMEOUT LO_SUBMIT_INTERVAL LO_STATUS_DIR LO_TASK_ID \
        DEV_LOOP_WORKER_MODEL GROUNDWORK_ESCALATION_DIR GROUNDWORK_TASK_ID

  # A valid git work-tree root, for every test that needs the worktree guard
  # (issue #123) to pass through to the behavior under test. Dry-run-only tests
  # may keep a fake path instead — the worktree guard runs after the dry-run exit.
  WT="$BATS_TEST_TMPDIR/wt"; mkdir -p "$WT"; git -C "$WT" init -q
}

@test "rejects an invalid permission mode (injection guard)" {
  run bash "$LS" sess "$WT" "bypassPermissions; rm -rf ~" "prompt"
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

# --- Issue #123: session-name guard ----------------------------------------
# A zsh coordinator's word-splitting bug can hand this a space-containing
# session name; the name is interpolated into tmux commands and matched by
# safe-cleanup.sh's sweep, so it is allowlist-rejected before any tmux call.
# LO_DRY_RUN is used here because the guard runs before the dry-run exit
# (D2) — no tmux/claude stub is needed to prove it fires.

@test "rejects a session name containing a space (issue #123 zsh word-splitting incident)" {
  run env LO_DRY_RUN=1 sh "$LS" "lo-2 t2-lobby" "$WT" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "invalid session name"
}

@test "rejects an LO_RUN_ID suffix that would corrupt the final session name" {
  run env LO_DRY_RUN=1 LO_RUN_ID="r1 evil" sh "$LS" lo-1 "$WT" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "invalid session name"
}

@test "rejects an empty session name (boundary)" {
  run env LO_DRY_RUN=1 sh "$LS" "" "$WT" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "invalid session name"
}

# --- Issue #123: worktree-root guard ----------------------------------------
# The worktree argument must be a git work-tree ROOT. A coordinator bug can
# hand this the worktrees' shared parent directory instead of the task's own
# worktree; that and a non-root subdirectory of a real checkout both used to
# be handed straight to tmux `-c` with no error. The guard runs before any
# tmux/claude call, so no stub is needed — a real `tmux` on PATH is enough to
# pass the earlier binary-resolution check (unaffected by this guard's order).

@test "rejects a non-existent worktree path (boundary)" {
  run sh "$LS" lo-1 "$BATS_TEST_TMPDIR/does-not-exist" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "does not exist"
}

@test "rejects a plain non-git directory as the worktree (issue #123 shared-parent-dir incident)" {
  plain="$BATS_TEST_TMPDIR/plain"; mkdir -p "$plain"
  run sh "$LS" lo-1 "$plain" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "is not a git work-tree"
}

@test "rejects a subdirectory of a git repo that is not the work-tree root" {
  sub="$WT/sub"; mkdir -p "$sub"
  run sh "$LS" lo-1 "$sub" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "is not a git work-tree root"
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
#   keys-at         the same lines, each prefixed with the capture count so far
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
    shift; printf '%s\n' "$*" >> "$d/keys"
    printf '%s %s\n' "$(cat "$d/captures" 2>/dev/null || echo 0)" "$*" >> "$d/keys-at" ;;
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

pane_auto_mode_chooser() { # groundwork#41: option 1 is highlighted
  printf '%s\n' \
    " Make auto mode your default permission mode?" \
    "   ❯ 1. Yes, set auto mode as my default permission mode" \
    "     2. No, keep bypass permissions"
}

pane_folder_trust() { # dev-loop#276: "No, exit" is highlighted
  printf '%s\n' \
    "Quick safety check: Is this a project you created or one you trust? (Like your own code, a well-known open source project, or work from your team). If not, take a moment to review what's in this folder first." \
    " Claude Code'll be able to read, edit, and execute files here." \
    " Security guide" \
    " ❯ No, exit" \
    "   Yes, I trust this folder"
}

pane_bypass_warning() { # bypassPermissions warning: "1. No, exit" is highlighted
  printf '%s\n' \
    " WARNING: Claude Code running in Bypass Permissions mode" \
    " By proceeding, you accept all responsibility for actions taken while running in Bypass Permissions mode." \
    " ❯ 1. No, exit" \
    "   2. Yes, I accept"
}

# --- #296: CLI 2.1.309 renders folder-trust and the bypass warning unnumbered,
# --- cancel option first, cursor on it. These build that rendering and the
# --- capture shapes of issue #296 from the transcribed fixtures above.
pane_trust_at() { # <no|yes> [cancel label] — folder-trust, cursor on cancel or on Yes
  local n="   " y="   "
  if [ "$1" = no ]; then n=" ❯ "; else y=" ❯ "; fi
  pane_folder_trust | sed -n 1,3p
  printf '%s\n' "${n}${2:-No, exit}" "${y}Yes, I trust this folder"
}

pane_bypass_at() { # <no|yes> — unnumbered bypass warning, cursor on "No, exit" or on Yes
  local n="   " y="   "
  if [ "$1" = no ]; then n=" ❯ "; else y=" ❯ "; fi
  pane_bypass_warning | sed -n 1,2p
  printf '%s\n' "${n}No, exit" "${y}Yes, I accept"
}

pane_trust_reflowed() { # answered folder-trust after resize-window -x 150: title row re-wrapped, still visible
  pane_trust_at yes | awk 'NR == 1 { print substr($0, 1, 150); print substr($0, 151); next } { print }'
}

pane_trust_scrolled() { # <no|yes> — folder-trust after resize-window -x 100: title rows in history (Spike S3)
  printf '%s\n' "er first."
  pane_trust_at "$1" | sed 1d
}

pane_chooser_at() { # <yes|no> [mode name] — unnumbered auto-mode chooser (CLI 2.1.310), cursor on option 1 or on "No, keep"
  local y="   " n="   "
  if [ "$1" = yes ]; then y=" ❯ "; else n=" ❯ "; fi
  pane_auto_mode_chooser | sed -n 1p
  printf '%s\n' "  ${y}Yes, set auto mode as my default permission mode" "  ${n}No, keep ${2:-bypass permissions}"
}

frames() { # <n> — stdin becomes pane-<n> and pane-<n+1>: two identical consecutive captures
  tee "$sd/pane-$1" > "$sd/pane-$(($1 + 1))"
}

# --- Task 01: launch-session.sh must not clobber tmux's own TMUX variable ---
# TMUX is tmux's server-socket variable. Assigning it exports the corruption to
# every child tmux, which then tries to connect to a binary path as a socket.
# Measured 2026-08-05: this breaks EVERY launch when the coordinator itself runs
# inside tmux ("error connecting to <path> (Socket operation on non-socket)").

@test "TMUX: the caller's tmux socket reaches the child untouched" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; echo 0 > "$sd/has-session-rc"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      TMUX=SENTINEL-SOCKET,111,0 sh "$LS" lo-1 "$WT" bypassPermissions "p"
  [ "$status" -eq 0 ]
  grep -q 'TMUX=SENTINEL-SOCKET,111,0' "$sd/env-log"
}

@test "TMUX: the tmux binary path is never assigned over the socket (regression)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; echo 0 > "$sd/has-session-rc"
  stub="$(mk_tmux_stub)"
  run env STUB_DIR="$sd" LO_TMUX="$stub" LO_CLAUDE=/bin/echo \
      TMUX=SENTINEL-SOCKET,111,0 sh "$LS" lo-1 "$WT" bypassPermissions "p"
  [ "$status" -eq 0 ]
  # the assertion that fails on the pre-fix script:
  ! grep -q "TMUX=$stub" "$sd/env-log"
}

@test "TMUX: a caller with no TMUX set still launches (boundary — masks the bug)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; echo 0 > "$sd/has-session-rc"
  run env -u TMUX STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      sh "$LS" lo-1 "$WT" bypassPermissions "p"
  [ "$status" -eq 0 ]
  grep -q 'TMUX=<unset>' "$sd/env-log"
}

# --- Task 02: the readiness budget is honoured exactly, and reports ---

@test "LO_READY_TIMEOUT is honoured exactly: floor(timeout/interval) attempts" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_not_ready > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=3 LO_READY_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "p"
  [ "$status" -eq 4 ]
  [ "$(cat "$sd/captures")" = "3" ]
}

@test "a readiness timeout exits 4 and says the REPL was not ready (error contract)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_not_ready > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "p"
  [ "$status" -eq 4 ]
  [[ "$output" == *"REPL not ready"* ]]
}

@test "a readiness timeout reports the last screen, not just the failure" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_not_ready > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "p"
  [ "$status" -eq 4 ]
  [[ "$output" == *"NOTREADYMARKER"* ]]
}

@test "a sub-interval readiness budget still makes exactly one attempt (boundary)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_not_ready > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=1 LO_READY_INTERVAL=2 \
      sh "$LS" lo-1 "$WT" bypassPermissions "p"
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
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"submitted"* ]]
}

@test "a prompt left sitting in the input box is NOT reported as success (exit 5)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_unsubmitted > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD you are the worker"
  [ "$status" -eq 5 ]
  [[ "$output" != *"ok:"* ]]
  [[ "$output" == *"NOT confirmed submitted"* ]]
}

@test "the field's [Pasted text] rendering is caught too, though the prompt text is hidden" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_pasted > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD you are the worker"
  [ "$status" -eq 5 ]
  [[ "$output" == *"NOT confirmed submitted"* ]]
}

@test "an unconfirmed submission reports the last screen so the pane is diagnosable" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_pasted > "$sd/pane"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
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
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD you are the worker"
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
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 5 ]
}

@test "submission confirmation is bounded: it does not outlive LO_SUBMIT_TIMEOUT (boundary)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_unsubmitted > "$sd/pane"
  start=$(date +%s)
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=1 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
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
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 0 ]
  [ -f "$st/t3.json" ]
  [ "$(jq -r .phase "$st/t3.json")" = "pending" ]
  [ "$(jq -r .session "$st/t3.json")" = "lo-1-r7" ]
  [ "$(jq -r .worktree "$st/t3.json")" = "$WT" ]
}

@test "pre-seed: with both vars unset no status file is written and stdout is unchanged (boundary)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_ready_submitted > "$sd/pane"
  st="$BATS_TEST_TMPDIR/status"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
  [ "$status" -eq 0 ]
  [ "$output" = "ok: lo-1 launched + prompt submitted (confirmed)" ]
  [ ! -e "$st" ]
}

@test "pre-seed: LO_STATUS_DIR alone (LO_TASK_ID unset) is now rejected (contract updated by issue #123)" {
  st="$BATS_TEST_TMPDIR/status"
  run env LO_STATUS_DIR="$st" sh "$LS" lo-1 "$WT" bypassPermissions "hello"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "LO_STATUS_DIR and LO_TASK_ID must be set together"
  [ ! -e "$st" ]
}

@test "pre-seed: LO_TASK_ID alone (LO_STATUS_DIR unset) is rejected" {
  run env LO_TASK_ID=t9 sh "$LS" lo-1 "$WT" bypassPermissions "hello"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "LO_STATUS_DIR and LO_TASK_ID must be set together"
}

@test "pre-seed: LO_STATUS_DIR set with LO_TASK_ID as an empty string is rejected (issue #123 incident shape: set-but-empty counts as unset)" {
  st="$BATS_TEST_TMPDIR/status"
  run env LO_STATUS_DIR="$st" LO_TASK_ID="" sh "$LS" lo-1 "$WT" bypassPermissions "hello"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "LO_STATUS_DIR and LO_TASK_ID must be set together"
  [ ! -e "$st" ]
}

@test "pre-seed: a failing status-update warns on stderr but the launch still exits 0 (error tolerated)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"; pane_ready_submitted > "$sd/pane"
  # a status dir UNDER a regular file: status-update's mkdir -p fails deterministically
  touch "$BATS_TEST_TMPDIR/blocker"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_STATUS_DIR="$BATS_TEST_TMPDIR/blocker/sub" LO_TASK_ID=t3 \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
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
      sh "$LS" lo-1 "$WT" bypassPermissions "p"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "session=lo-1"
  [ "$(jq -r .phase "$st/t3.json")" = "pending" ]
  [ "$(jq -r .session "$st/t3.json")" = "lo-1" ]
  [ "$(jq -r .worktree "$st/t3.json")" = "$WT" ]
}

# --- DEV_LOOP_WORKER_MODEL --------------------------------------------------
# The worker may run a cheaper tier than the coordinator. Unset MUST stay
# byte-identical to the previous behavior (no --model at all), or every existing
# deployment silently changes model on upgrade.
# The unset case uses `env -u`: DEV_LOOP_WORKER_MODEL is a real user setting,
# so a developer with it exported would otherwise see this test pass vacuously
# (or fail) depending on their shell rather than on the code.

@test "MODEL: an invalid model is rejected before anything launches (injection guard)" {
  run env LO_DRY_RUN=1 DEV_LOOP_WORKER_MODEL='bad; rm -rf ~' \
      bash "$LS" lo-1 "${BATS_TEST_TMPDIR}/wt" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid model"* ]]
}

@test "MODEL: unset adds no --model flag (boundary — unchanged behavior)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  # capture #1 is the readiness check, #2 the submission confirm
  pane_ready_submitted > "$sd/pane-1"
  pane_ready_submitted > "$sd/pane-2"
  run env -u DEV_LOOP_WORKER_MODEL STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=4 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD p"
  [ "$status" -eq 0 ]
  ! grep -q -- '--model' "$sd/keys"
}

@test "MODEL: a set model reaches the launched claude command" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_submitted > "$sd/pane-1"
  pane_ready_submitted > "$sd/pane-2"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      DEV_LOOP_WORKER_MODEL=claude-sonnet-5 DEV_LOOP_WORKER_EFFORT=high \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=4 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD p"
  [ "$status" -eq 0 ]
  [[ "$(cat "$sd/keys")" == *"CLAUDE_CODE_EFFORT_LEVEL=high \"/bin/echo\" --permission-mode bypassPermissions --model 'claude-sonnet-5'"* ]]
}

@test "EFFORT: an invalid effort is rejected before anything launches (injection guard)" {
  run env LO_DRY_RUN=1 DEV_LOOP_WORKER_EFFORT='high; rm -rf ~' \
      bash "$LS" lo-1 "${BATS_TEST_TMPDIR}/wt" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid effort"* ]]
}

@test "EFFORT: unset adds no CLAUDE_CODE_EFFORT_LEVEL (boundary — unchanged behavior)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_submitted > "$sd/pane-1"
  pane_ready_submitted > "$sd/pane-2"
  run env -u DEV_LOOP_WORKER_EFFORT STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=4 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD p"
  [ "$status" -eq 0 ]
  [[ "$(cat "$sd/keys")" == *"--permission-mode bypassPermissions"* ]]
  [[ "$(cat "$sd/keys")" != *"CLAUDE_CODE_EFFORT_LEVEL"* ]]
}

# --- GROUNDWORK_GUARDRAILS_CONFIG (guardrails tighten-only contract) --------
# The guardrails plugin now only lets a repo config TIGHTEN rules, and only
# trusts GROUNDWORK_GUARDRAILS_CONFIG when it resolves OUTSIDE every project
# tree (any command in the worktree could rewrite an in-tree file). The
# loosened per-worker config must reach the worker as that external, trusted
# file ($HOME/.claude/groundwork/overrides/dev-loop-<id>.json — worker-guardrails.sh
# owns deriving <id>) via this env var, or an upgraded guardrails ignores the
# loosening and every sandboxed-off rule (rm_rf, git_discard, tmp writes)
# becomes an `ask` again inside the worker's own worktree.

@test "GUARDRAILS: exports GROUNDWORK_GUARDRAILS_CONFIG as the worktree's EXTERNAL (outside-the-worktree) guardrails path" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_ready_submitted > "$sd/pane-1"
  pane_ready_submitted > "$sd/pane-2"
  fakehome="$BATS_TEST_TMPDIR/fakehome"; mkdir -p "$fakehome"
  WG="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/worker-guardrails.sh"
  # write-mode must have already run (as it does in real use, via
  # setup-worktrees.sh, before the worker is launched) for the file the
  # export now checks to exist.
  HOME="$fakehome" sh "$WG" "$WT" >/dev/null
  run env HOME="$fakehome" STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=4 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD p"
  [ "$status" -eq 0 ]
  keys="$(cat "$sd/keys")"
  expected="$(HOME="$fakehome" sh "$WG" --path "$WT")"
  [[ "$keys" == *"GROUNDWORK_GUARDRAILS_CONFIG='$expected'"* ]]
  # outside every project tree, not inside the worktree
  [[ "$expected" != "$WT"* ]]
  [[ "$expected" == "$fakehome/.claude/groundwork/overrides/dev-loop-"*".json" ]]
}

@test "GUARDRAILS: does NOT export GROUNDWORK_GUARDRAILS_CONFIG when worker-guardrails.sh never wrote the file" {
  sd="$BATS_TEST_TMPDIR/sd2"; mkdir -p "$sd"
  pane_ready_submitted > "$sd/pane-1"
  pane_ready_submitted > "$sd/pane-2"
  fakehome="$BATS_TEST_TMPDIR/fakehome2"; mkdir -p "$fakehome"
  wt2="$BATS_TEST_TMPDIR/wt2"; mkdir -p "$wt2"; git -C "$wt2" init -q
  # No write-mode call here — only --path's computed name exists, no file.
  run env HOME="$fakehome" STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=4 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-2 "$wt2" bypassPermissions "ZZPROMPTHEAD p"
  [ "$status" -eq 0 ]
  keys="$(cat "$sd/keys")"
  [[ "$keys" != *"GROUNDWORK_GUARDRAILS_CONFIG"* ]]
}

# --- CONTAMINATION GUARD (issue #100 comment): a leaked real LO_STATUS_DIR
# once let this suite overwrite a live run's status file. This test plants
# real-looking decoy dirs as the ambient LO_STATUS_DIR/GROUNDWORK_ESCALATION_DIR
# a worker session would have exported, re-runs the one boundary test that
# does NOT itself pass LO_STATUS_DIR/LO_TASK_ID (so it depends entirely on
# setup()'s unset for isolation) as a NESTED bats process — the only way to
# put those vars in place *before* that test's own setup() runs — and proves
# both that its outcome is unchanged AND that the decoys gained zero files.
#
# Negative control (verified 2026-08-14, not left in code): with the setup()
# unset block removed, this test fails — decoy_status gains a zzz.json file,
# reproducing the exact live contamination (t90.json overwritten in i8790).
@test "CONTAMINATION GUARD: ambient LO_STATUS_DIR/GROUNDWORK_ESCALATION_DIR from a worker session write nothing into a real-looking decoy dir" {
  decoy_status="$BATS_TEST_TMPDIR/decoy-status"; mkdir -p "$decoy_status"
  decoy_esc="$BATS_TEST_TMPDIR/decoy-escalations"; mkdir -p "$decoy_esc"
  run env LO_RUN_ID=zzz LO_STATUS_DIR="$decoy_status" LO_TASK_ID=zzz \
      GROUNDWORK_ESCALATION_DIR="$decoy_esc" GROUNDWORK_TASK_ID=zzz \
      bats --filter 'pre-seed: with both vars unset no status file is written' \
      "$BATS_TEST_DIRNAME/launch-session.bats"
  [ "$status" -eq 0 ]
  # grep, not [[ ]]: a false mid-test [[ ]] does not fail a test under this
  # bats/bash combination, which would make these assertions decoration.
  printf '%s\n' "$output" | grep -qF '1..1'
  printf '%s\n' "$output" | grep -qE '^ok 1 '
  [ -z "$(ls -A "$decoy_status" 2>/dev/null)" ]
  [ -z "$(ls -A "$decoy_esc" 2>/dev/null)" ]
}

# --- first-launch screens: auto-mode chooser (groundwork#41) and the
# --- folder-trust screen with "No, exit" highlighted (dev-loop#276).
# keys line 1 is always the launch command; a "bare Enter" is the exact line
# "-t lo-1 Enter". The prompt's own submit adds one bare Enter after "-l".

run_screens() { # <ready-timeout> -> runs the launcher against $sd
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT="$1" LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
}

@test "screens: auto-mode chooser is answered with key 2, never a bare Enter (groundwork#41)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_auto_mode_chooser | frames 1; pane_ready_submitted > "$sd/pane"
  run_screens 4
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 2" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
  [ "$(grep -c '^-t lo-1 Enter$' "$sd/keys")" = "1" ]
}

@test "screens: folder-trust screen gets Down while the cursor is on 'No, exit', then Enter on 'Yes, I trust this folder' (dev-loop#276, #296 R2)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_folder_trust | frames 1; pane_trust_at yes | frames 3; pane_ready_submitted > "$sd/pane"
  run_screens 6
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Down" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 4p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "screens: chooser with an 'Enter to confirm' footer still gets key 2, not the generic Enter (precedence)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_auto_mode_chooser; printf '%s\n' " Enter to confirm · Esc to cancel"; } | frames 1
  pane_ready_submitted > "$sd/pane"
  run_screens 4
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 2" ]
  [ "$(grep -c '^-t lo-1 Enter$' "$sd/keys")" = "1" ]
}

@test "screens: folder-trust with an 'Enter to confirm' footer still gets Down then Enter (precedence)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_folder_trust; printf '%s\n' " Enter to confirm · Esc to cancel"; } | frames 1
  { pane_trust_at yes; printf '%s\n' " Enter to confirm · Esc to cancel"; } | frames 3
  pane_ready_submitted > "$sd/pane"
  run_screens 6
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Down" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 Enter" ]
}

@test "screens: a chooser that never clears exits 4 after one key 2 and no bare Enter (error, #296 R15)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_auto_mode_chooser > "$sd/pane"
  run_screens 4
  [ "$status" -eq 4 ]
  printf '%s\n' "$output" | grep -qF 'REPL not ready'
  [ "$(grep -c '^-t lo-1 2$' "$sd/keys")" = "1" ]
  [ "$(grep -c '^-t lo-1 Enter$' "$sd/keys")" = "0" ]
  [ "$(grep -c -- ' -l ' "$sd/keys")" = "0" ]
}

@test "screens: a partial chooser render with only the option-2 line and no title gets no key (boundary, #296 R8)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  printf '%s\n' "     2. No, keep bypass permissions" | frames 1
  pane_ready_submitted > "$sd/pane"
  run_screens 4
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
  [ "$(grep -c '^-t lo-1 2$' "$sd/keys")" = "0" ]
}

@test "screens: a numbered bypass-permissions warning gets the digit of 'Yes, I accept' alone, no Enter after it (#296 R1)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_bypass_warning | frames 1; pane_ready_submitted > "$sd/pane"
  run_screens 4
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 2" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
  [ "$(grep -c '^-t lo-1 Enter$' "$sd/keys")" = "1" ]
}

@test "screens: a ready REPL whose scrollback still shows the chooser is ready, no key 2 sent (unchanged)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_auto_mode_chooser; pane_ready_submitted; } > "$sd/pane"
  run_screens 4
  [ "$status" -eq 0 ]
  [ "$(grep -c '^-t lo-1 2$' "$sd/keys")" = "0" ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

# --- LO_TRUST_KEYS (#290) ---------------------------------------------------
# LO_TRUST_EXTRA names an extra trust screen; LO_TRUST_KEYS names the keys sent
# when it matches (unset, empty or blank = Enter). Every token is checked
# against send-prompt.sh's `keys` allowlist before the dry-run exit and before
# any tmux call.

pane_trust_extra() { # an unknown screen carrying the LO_TRUST_EXTRA marker
  printf '%s\n' "Loading…" "CUSTOMTRUSTMARK"
}

run_trust() { # [env args...] -> runs the launcher against $sd with LO_TRUST_EXTRA set
  run env "$@" STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=4 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      LO_TRUST_EXTRA=CUSTOMTRUSTMARK \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
}

@test "LO_TRUST_KEYS: an LO_TRUST_EXTRA screen gets the listed keys in order, one call each (#290 K1)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_trust_extra > "$sd/pane-1"; pane_ready_submitted > "$sd/pane"
  run_trust LO_TRUST_KEYS="Down Enter"
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Down" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 4p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "LO_TRUST_KEYS: unset sends Enter, the previous behavior (boundary) (#290 K2)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_trust_extra > "$sd/pane-1"; pane_ready_submitted > "$sd/pane"
  run_trust -u LO_TRUST_KEYS
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "LO_TRUST_KEYS: an empty value sends Enter like unset (boundary) (#290 K3)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_trust_extra > "$sd/pane-1"; pane_ready_submitted > "$sd/pane"
  run_trust LO_TRUST_KEYS=
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "LO_TRUST_KEYS: a whitespace-only value sends Enter like unset (boundary) (#290 K4)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_trust_extra > "$sd/pane-1"; pane_ready_submitted > "$sd/pane"
  run_trust LO_TRUST_KEYS="   "
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "LO_TRUST_KEYS: every allowlisted key passes validation (#290 K5)" {
  run env LO_DRY_RUN=1 LO_TRUST_KEYS="Up Down Left Right Enter Escape Tab Space 0 1 2 3 4 5 6 7 8 9 y n" \
      sh "$LS" lo-1 "$WT" bypassPermissions "prompt"
  [ "$status" -eq 0 ]
  [ "$output" = "session=lo-1" ]
}

@test "LO_TRUST_KEYS: a bad key after a good one is refused at exit 2, even in dry-run (error) (#290 K6)" {
  run env LO_DRY_RUN=1 LO_TRUST_KEYS="Enter Backspace" sh "$LS" lo-1 "$WT" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"LO_TRUST_KEYS key 'Backspace' not in allowlist"* ]]
}

@test "LO_TRUST_KEYS: an invalid key is refused before any tmux call (error) (#290 K7)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  run env STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=2 LO_READY_INTERVAL=1 LO_TRUST_KEYS="Down;" \
      sh "$LS" lo-1 "$WT" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"LO_TRUST_KEYS key 'Down;' not in allowlist"* ]]
  [ ! -e "$sd/env-log" ]
}

@test "LO_TRUST_KEYS: a glob token is checked as itself, not expanded to file names (error) (#290 K8)" {
  gd="$BATS_TEST_TMPDIR/globdir"; mkdir -p "$gd"; : > "$gd/Enter"
  cd "$gd"
  run env LO_DRY_RUN=1 LO_TRUST_KEYS='*' sh "$LS" lo-1 "$WT" bypassPermissions "prompt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"LO_TRUST_KEYS key '*' not in allowlist"* ]]
}

# --- #296: first-launch screens chosen by number or by the cursor line ------
# Every actionable frame is written twice (frames), because the launcher acts
# only on two identical consecutive captures. keys-at prefixes each key with
# the number of captures taken when it was sent.

@test "screens: a numbered bypass warning listing Yes first gets digit 1, read from the Yes line (#296 N1)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_bypass_warning | sed -n 1,2p; printf '%s\n' " ❯ 1. Yes, I accept" "   2. No, exit"; } | frames 1
  pane_ready_submitted > "$sd/pane"
  run_screens 4
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 1" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "screens: the folder-trust cancel label 'No, continue without these permissions' also gets Down, then Enter (#296 N2)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_trust_at no "No, continue without these permissions" | frames 1
  pane_trust_at yes "No, continue without these permissions" | frames 3
  pane_ready_submitted > "$sd/pane"
  run_screens 6
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Down" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 4p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "screens: a folder-trust screen whose cursor is already on Yes gets Enter and no Down (boundary) (#296 N3)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_trust_at yes | frames 1; pane_ready_submitted > "$sd/pane"
  run_screens 4
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
  [ "$(grep -c '^-t lo-1 Down$' "$sd/keys")" = "0" ]
}

@test "screens: a cursor that stays on 'No, exit' after one Down gets no second Down and no Enter, exit 4 (error) (#296 N4)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_folder_trust > "$sd/pane"
  run_screens 5
  [ "$status" -eq 4 ]
  [ "$(grep -c '^-t lo-1 Down$' "$sd/keys")" = "1" ]
  [ "$(grep -c '^-t lo-1 Enter$' "$sd/keys")" = "0" ]
}

@test "screens: shape 3 — the just-answered bypass frame seen again gets no second Enter; the chooser after it gets 2 (#296 N5)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_bypass_at no | frames 1; pane_bypass_at yes | frames 3; pane_bypass_at yes | frames 5
  pane_auto_mode_chooser | frames 7; pane_ready_submitted > "$sd/pane"
  run_screens 10
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Down" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 4p "$sd/keys")" = "-t lo-1 2" ]
  [ "$(sed -n 5p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
  [ "$(grep -c '^-t lo-1 Enter$' "$sd/keys")" = "2" ]
}

@test "screens: shape 4 — an answered folder-trust frame re-wrapped or scrolled by a pane resize gets no second key (#296 N6)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_trust_at no | frames 1; pane_trust_at yes | frames 3
  pane_trust_reflowed | frames 5; pane_trust_scrolled yes | frames 7
  pane_ready_submitted > "$sd/pane"
  run_screens 10
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Down" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 4p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
  [ "$(grep -c '^-t lo-1 Enter$' "$sd/keys")" = "2" ]
}

@test "screens: shape 1 — a stale folder-trust frame with the cursor on Yes above the live bypass warning never decides the key (#296 N7)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_trust_at yes; pane_bypass_at no; } | frames 1
  { pane_trust_at yes; pane_bypass_at yes; } | frames 3
  pane_ready_submitted > "$sd/pane"
  run_screens 6
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Down" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 4p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "screens: shape 2 — a title-only bypass warning under a stale frame gets no key until its options are drawn (#296 N8)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_trust_at yes; pane_bypass_warning | sed -n 1p; } | frames 1
  { pane_trust_at yes; pane_bypass_at no; } | tee "$sd/pane" | frames 3
  run_screens 5
  [ "$status" -eq 4 ]
  [ "$(sed -n 2p "$sd/keys-at")" = "4 -t lo-1 Down" ]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "2" ]
}

@test "screens: shape 2 — a title-only bypass warning under a stale numbered folder-trust frame gets no key (#296 N9)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_folder_trust | sed -n 1,3p; printf '%s\n' " ❯ 1. No, exit" "   2. Yes, I trust this folder"; pane_bypass_warning | sed -n 1p; } > "$sd/pane"
  run_screens 3
  [ "$status" -eq 4 ]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "1" ]
}

@test "screens: torn capture — a bypass title drawn over the old frame's option rows is not acted on; the settled screen is (#296 N10)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_bypass_warning | sed -n 1,2p; printf '%s\n' " ❯ No, exit" "   Yes, I trust this folder"; } > "$sd/pane-1"
  pane_bypass_at no | tee "$sd/pane" | frames 2
  run_screens 4
  [ "$status" -eq 4 ]
  [ "$(sed -n 2p "$sd/keys-at")" = "3 -t lo-1 Down" ]
  [ "$(grep -c '^-t lo-1 Down$' "$sd/keys")" = "1" ]
}

@test "screens: a screen seen in one capture only gets no key (boundary) (#296 N11)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_folder_trust > "$sd/pane-1"; pane_ready_submitted > "$sd/pane"
  run_screens 4
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "screens: title scrolled off — an answered folder-trust whose title leaves and comes back gets one Enter only (#296 N12)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_trust_at no | frames 1; pane_trust_at yes | frames 3
  pane_trust_scrolled yes | frames 5; pane_trust_at yes | frames 7
  pane_ready_submitted > "$sd/pane"
  run_screens 10
  [ "$status" -eq 0 ]
  [ "$(sed '/ -l ZZPROMPTHEAD/,$d' "$sd/keys" | grep -c '^-t lo-1 Enter$')" = "1" ]
  [ "$(grep -c '^-t lo-1 Down$' "$sd/keys")" = "1" ]
}

@test "screens: title scrolled off before any answer — option rows with no title get no key (#296 N13)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_trust_scrolled no > "$sd/pane"
  run_screens 3
  [ "$status" -eq 4 ]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "1" ]
}

@test "screens: a cursor on a label that is neither Yes nor No gets no key, exit 4 (error) (#296 N14)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_folder_trust | sed -n 1,2p; printf '%s\n' " ❯ Security guide" "   No, exit" "   Yes, I trust this folder"; } > "$sd/pane"
  run_screens 3
  [ "$status" -eq 4 ]
  [[ "$output" == *"REPL not ready"* ]]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "1" ]
}

@test "screens: a title-only folder-trust screen gets no key, exit 4 (boundary) (#296 N15)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_folder_trust | sed -n 1p > "$sd/pane"
  run_screens 3
  [ "$status" -eq 4 ]
  [[ "$output" == *"REPL not ready"* ]]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "1" ]
}

@test "screens: two cursor lines below one title get no key (boundary) (#296 N16)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_folder_trust | sed -n 1,3p; printf '%s\n' " ❯ No, exit" " ❯ Yes, I trust this folder"; } > "$sd/pane"
  run_screens 3
  [ "$status" -eq 4 ]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "1" ]
}

@test "screens: two numbered Yes lines below one title get no digit (boundary) (#296 N17)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_bypass_warning | sed -n 1,2p; printf '%s\n' " ❯ 1. Yes, I accept" "   2. Yes, I accept"; } > "$sd/pane"
  run_screens 3
  [ "$status" -eq 4 ]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "1" ]
}

@test "screens: an unnumbered auto-mode chooser (CLI 2.1.310) gets Down while the cursor is on 'Yes, set auto mode', then Enter on 'No, keep' (#296 N18)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_chooser_at yes | frames 1; pane_chooser_at no | frames 3; pane_ready_submitted > "$sd/pane"
  run_screens 6
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Down" ]
  [ "$(sed -n 3p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(sed -n 4p "$sd/keys")" = "-t lo-1 -l ZZPROMPTHEAD hello" ]
}

@test "screens: an unnumbered chooser already on 'No, keep' with another mode name gets Enter and no Down (boundary) (#296 N20)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_chooser_at no "accept edits" | frames 1; pane_ready_submitted > "$sd/pane"
  run_screens 4
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$sd/keys")" = "-t lo-1 Enter" ]
  [ "$(grep -c '^-t lo-1 Down$' "$sd/keys")" = "0" ]
}

@test "screens: an unnumbered chooser whose cursor stays on 'Yes, set auto mode' gets one Down and never Enter, exit 4 (error) (#296 N21)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  pane_chooser_at yes > "$sd/pane"
  run_screens 5
  [ "$status" -eq 4 ]
  [ "$(grep -c '^-t lo-1 Down$' "$sd/keys")" = "1" ]
  [ "$(grep -c '^-t lo-1 Enter$' "$sd/keys")" = "0" ]
}

@test "screens: chooser rows with the title scrolled off and an 'Enter to confirm' footer get no key, never the generic Enter (#296 N22)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_chooser_at yes "default" | sed 1d; printf '%s\n' " Enter to confirm · Esc to cancel"; } > "$sd/pane"
  run_screens 3
  [ "$status" -eq 4 ]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "1" ]
}

@test "screens: a title-less frame whose only cursor line is an empty REPL prompt gets no key (boundary) (#296 N23)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  { pane_trust_at no | sed -n 2,3p; printf '%s\n' "   No, exit" "   Yes, I trust this folder" "$RULE" "❯ " "$RULE"; } > "$sd/pane"
  run_screens 3
  [ "$status" -eq 4 ]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "1" ]
}

@test "screens: a failing awk sends no key and keeps exit 4, not awk's own status (error) (#296 N19)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  fb="$(REPO_TMP)/fakebin-${BATS_TEST_NUMBER}"; mkdir -p "$fb"
  printf '#!/bin/sh\nexit 2\n' > "$fb/awk"; chmod +x "$fb/awk"
  pane_folder_trust > "$sd/pane"
  run env PATH="$fb:$PATH" STUB_DIR="$sd" LO_TMUX="$(mk_tmux_stub)" LO_CLAUDE=/bin/echo \
      LO_READY_TIMEOUT=3 LO_READY_INTERVAL=1 LO_SUBMIT_TIMEOUT=2 LO_SUBMIT_INTERVAL=1 \
      sh "$LS" lo-1 "$WT" bypassPermissions "ZZPROMPTHEAD hello"
  rm -rf "$fb"
  [ "$status" -eq 4 ]
  [[ "$output" == *"REPL not ready"* ]]
  [ "$(wc -l < "$sd/keys" | tr -d ' ')" = "1" ]
}
