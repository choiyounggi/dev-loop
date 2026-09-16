#!/usr/bin/env bats
# Tests for hooks/worker-blocked-signal.sh (StopFailure, Notification,
# UserPromptSubmit hooks) and its hooks.json registration.
# Written before the implementation (D7) — see .orchestration/plans/t1-blocked-hook/.

setup() {
  HOOK="${BATS_TEST_DIRNAME}/../hooks/worker-blocked-signal.sh"
  HOOKS_JSON="${BATS_TEST_DIRNAME}/../hooks/hooks.json"
  WS="${BATS_TEST_TMPDIR}/ws"
  mkdir -p "$WS/.orchestration/status"
  WS=$(cd "$WS" && pwd -P)
  jq -n --arg wt "$WS" '{task:"t1",phase:"implementing",worktree:$wt,session:"lo-1-run"}' \
    > "$WS/.orchestration/status/t1.json"

  FAKE_TMUX="${BATS_TEST_TMPDIR}/fake-tmux"
  cat > "$FAKE_TMUX" <<'EOF'
#!/usr/bin/env bash
# Stub: answers `display-message -p '#S'` with $FAKE_TMUX_SESSION.
if [ "$1" = "display-message" ]; then
  printf '%s\n' "${FAKE_TMUX_SESSION:-}"
  exit 0
fi
exit 1
EOF
  chmod +x "$FAKE_TMUX"
}

_fire() { # <json> [session]
  printf '%s' "$1" | env TMUX=/fake-socket BLOCKED_SIGNAL_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="${2:-lo-1-run}" bash "$HOOK"
}

_notif() { # <type> <message>
  jq -n --arg t "$1" --arg m "$2" --arg cwd "$WS" \
    '{hook_event_name:"Notification",cwd:$cwd,notification_type:$t,message:$m}'
}

_blocked_file() { printf '%s' "$WS/.orchestration/blocked/t1.json"; }

# ------------------------------------------------------------------ R1 --

@test "R1 normal: StopFailure in the managed worker writes a BlockedRecord" {
  payload=$(jq -n --arg cwd "$WS" --arg err "rate_limit" \
    --arg det "You've hit your session limit · resets 3:45pm" \
    '{hook_event_name:"StopFailure",cwd:$cwd,error:$err,error_details:$det}')
  run _fire "$payload"
  [ "$status" -eq 0 ]
  f=$(_blocked_file)
  [ -f "$f" ]
  [ "$(jq -r '.event' "$f")" = "StopFailure" ]
  [ "$(jq -r '.reason' "$f")" = "rate_limit" ]
  [ "$(jq -r '.taskId' "$f")" = "t1" ]
  [ "$(jq -r '.session' "$f")" = "lo-1-run" ]
  [ "$(jq -r '.worktree' "$f")" = "$WS" ]
  [ "$(jq -r '.detail' "$f")" = "You've hit your session limit · resets 3:45pm" ]
  ts=$(jq -r '.ts' "$f")
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
  [ "$(jq '. | keys | length' "$f")" -eq 7 ]
}

@test "R1 boundary: StopFailure without an error field falls back to reason=unknown" {
  payload=$(jq -n --arg cwd "$WS" '{hook_event_name:"StopFailure",cwd:$cwd}')
  run _fire "$payload"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.reason' "$(_blocked_file)")" = "unknown" ]
}

# ------------------------------------------------------------------ R2 --

@test "R2 normal: Notification idle_prompt writes a BlockedRecord" {
  payload=$(_notif idle_prompt "Claude is waiting for your input")
  run _fire "$payload"
  [ "$status" -eq 0 ]
  f=$(_blocked_file)
  [ "$(jq -r '.event' "$f")" = "Notification" ]
  [ "$(jq -r '.reason' "$f")" = "idle_prompt" ]
  [ "$(jq -r '.detail' "$f")" = "Claude is waiting for your input" ]
}

@test "R2 normal: the other seven blocking notification types each write reason=type" {
  for t in permission_prompt elicitation_dialog elicitation_url_dialog agent_needs_input \
           worker_permission_prompt quota_auto_resume_stale quota_auto_resume_disabled; do
    rm -f "$(_blocked_file)"
    payload=$(_notif "$t" "msg for $t")
    run _fire "$payload"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.reason' "$(_blocked_file)")" = "$t" ]
  done
}

# ------------------------------------------------------------------ R3 --

@test "R3 boundary: non-blocking notification types write nothing" {
  for t in auth_success agent_completed push_notification computer_use_enter \
           computer_use_exit model_refusal_fallback; do
    rm -f "$(_blocked_file)"
    payload=$(_notif "$t" "msg")
    run _fire "$payload"
    [ "$status" -eq 0 ]
    [ ! -f "$(_blocked_file)" ]
  done
}

@test "R3 boundary: Notification with no notification_type field writes nothing" {
  payload=$(jq -n --arg cwd "$WS" --arg m "msg" '{hook_event_name:"Notification",cwd:$cwd,message:$m}')
  run _fire "$payload"
  [ "$status" -eq 0 ]
  [ ! -f "$(_blocked_file)" ]
}

# ------------------------------------------------------------------ R4 --

@test "R4 normal: UserPromptSubmit with no source field clears an existing BlockedRecord" {
  payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  _fire "$payload" >/dev/null
  [ -f "$(_blocked_file)" ]
  ups=$(jq -n --arg cwd "$WS" --arg p "x" '{hook_event_name:"UserPromptSubmit",cwd:$cwd,prompt:$p}')
  run _fire "$ups"
  [ "$status" -eq 0 ]
  [ ! -f "$(_blocked_file)" ]
}

@test "R4 normal: UserPromptSubmit clears for source=user, source=sdk, and source=system" {
  for src in user sdk system; do
    payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
    _fire "$payload" >/dev/null
    [ -f "$(_blocked_file)" ]
    ups=$(jq -n --arg cwd "$WS" --arg p "x" --arg src "$src" '{hook_event_name:"UserPromptSubmit",cwd:$cwd,prompt:$p,source:$src}')
    run _fire "$ups"
    [ "$status" -eq 0 ]
    [ ! -f "$(_blocked_file)" ]
  done
}

@test "R4 boundary: UserPromptSubmit does NOT clear for source loop_wakeup, schedule_wakeup, or poll_event" {
  for src in loop_wakeup schedule_wakeup poll_event; do
    payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
    _fire "$payload" >/dev/null
    [ -f "$(_blocked_file)" ]
    ups=$(jq -n --arg cwd "$WS" --arg p "x" --arg src "$src" '{hook_event_name:"UserPromptSubmit",cwd:$cwd,prompt:$p,source:$src}')
    run _fire "$ups"
    [ "$status" -eq 0 ]
    [ -f "$(_blocked_file)" ]
  done
}

@test "R4 normal: a quota_auto_resume_fired Notification clears an existing BlockedRecord" {
  payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  _fire "$payload" >/dev/null
  [ -f "$(_blocked_file)" ]
  fired=$(_notif quota_auto_resume_fired "Usage limit reset — Claude is continuing your task")
  run _fire "$fired"
  [ "$status" -eq 0 ]
  [ ! -f "$(_blocked_file)" ]
}

@test "R4 boundary: UserPromptSubmit with no existing record is a no-op" {
  ups=$(jq -n --arg cwd "$WS" --arg p "x" '{hook_event_name:"UserPromptSubmit",cwd:$cwd,prompt:$p}')
  run _fire "$ups"
  [ "$status" -eq 0 ]
  [ ! -d "$WS/.orchestration/blocked" ]
}

# ------------------------------------------------------------------ R5 --

@test "R5 boundary: cwd with no .orchestration/status above it writes nothing" {
  OTHER="${BATS_TEST_TMPDIR}/lonely"
  mkdir -p "$OTHER"
  OTHER=$(cd "$OTHER" && pwd -P)
  payload=$(jq -n --arg cwd "$OTHER" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  run _fire "$payload"
  [ "$status" -eq 0 ]
  [ ! -d "$OTHER/.orchestration" ]
}

@test "R5 boundary: a status record whose worktree differs from cwd writes nothing" {
  jq -n --arg wt "/nowhere/else" '{task:"t1",phase:"implementing",worktree:$wt,session:"lo-1-run"}' \
    > "$WS/.orchestration/status/t1.json"
  payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  run _fire "$payload"
  [ "$status" -eq 0 ]
  [ ! -f "$(_blocked_file)" ]
}

@test "R5 boundary: a mismatched current tmux session writes nothing" {
  payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  run _fire "$payload" "lo-9-run"
  [ "$status" -eq 0 ]
  [ ! -f "$(_blocked_file)" ]
}

@test "R5 boundary: TMUX unset while the record carries a session writes nothing" {
  unset TMUX
  payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  run env BLOCKED_SIGNAL_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="lo-1-run" bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  [ ! -f "$(_blocked_file)" ]
}

@test "R5 boundary: a status record without a session field writes with session empty" {
  jq -n --arg wt "$WS" '{task:"t1",phase:"implementing",worktree:$wt}' > "$WS/.orchestration/status/t1.json"
  payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  run _fire "$payload"
  [ "$status" -eq 0 ]
  f=$(_blocked_file)
  [ -f "$f" ]
  [ "$(jq -r '.session' "$f")" = "" ]
}

# ------------------------------------------------------------------ R6 --

@test "R6 error: malformed stdin JSON writes nothing" {
  run _fire "not json"
  [ "$status" -eq 0 ]
  [ ! -f "$(_blocked_file)" ]
}

@test "R6 error: an unwritable blocked dir leaves no tmp file behind" {
  mkdir -p "$WS/.orchestration/blocked"
  chmod 500 "$WS/.orchestration/blocked"
  payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  run _fire "$payload"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$WS/.orchestration/blocked")" ]
  chmod 700 "$WS/.orchestration/blocked"
}

@test "R6 error: an unknown hook_event_name writes nothing" {
  payload=$(jq -n --arg cwd "$WS" '{hook_event_name:"SessionStart",cwd:$cwd}')
  run _fire "$payload"
  [ "$status" -eq 0 ]
  [ ! -f "$(_blocked_file)" ]
}

# ------------------------------------------------------------------ D5 --

@test "D5 boundary: the record lands under cwd's own worktree, not the ancestor status dir" {
  P="${BATS_TEST_TMPDIR}/parent"
  mkdir -p "$P/.orchestration/status" "$P/.worktrees/w1"
  P=$(cd "$P" && pwd -P)
  W1="$P/.worktrees/w1"
  jq -n --arg wt "$W1" '{task:"t1",phase:"implementing",worktree:$wt}' > "$P/.orchestration/status/t1.json"
  payload=$(jq -n --arg cwd "$W1" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  run env TMUX=/fake-socket BLOCKED_SIGNAL_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="lo-1-run" bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  [ -f "$W1/.orchestration/blocked/t1.json" ]
  [ ! -d "$P/.orchestration/blocked" ]
}

# ------------------------------------------------------------------ D2 --

@test "D2 boundary: error_details over 300 chars is truncated to exactly 300" {
  long=$(printf 'x%.0s' $(seq 1 400))
  payload=$(jq -n --arg cwd "$WS" --arg err "x" --arg det "$long" \
    '{hook_event_name:"StopFailure",cwd:$cwd,error:$err,error_details:$det}')
  run _fire "$payload"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.detail | length' "$(_blocked_file)")" -eq 300 ]
}

@test "D2 normal: the last blocking event wins over a prior one" {
  payload=$(jq -n --arg cwd "$WS" --arg err "x" '{hook_event_name:"StopFailure",cwd:$cwd,error:$err}')
  _fire "$payload" >/dev/null
  payload2=$(_notif idle_prompt "x")
  run _fire "$payload2"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.reason' "$(_blocked_file)")" = "idle_prompt" ]
}

@test "D2 contract: the header documents the updatedAt staleness rule" {
  run grep -q "updatedAt" "$HOOK"
  [ "$status" -eq 0 ]
}

# ------------------------------------------------------------------ R7 --

@test "R7 normal: StopFailure is registered with no matcher and the right command" {
  run jq -e '.hooks.StopFailure[0] | has("matcher") | not' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  run jq -e '.hooks.StopFailure[0].hooks[0].command == "bash ${CLAUDE_PLUGIN_ROOT}/hooks/worker-blocked-signal.sh"' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
}

@test "R7 normal: Notification is registered with the nine-type matcher and the right command" {
  run jq -e '.hooks.Notification[0].matcher == "permission_prompt|idle_prompt|elicitation_dialog|elicitation_url_dialog|agent_needs_input|worker_permission_prompt|quota_auto_resume_stale|quota_auto_resume_disabled|quota_auto_resume_fired"' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  run jq -e '.hooks.Notification[0].hooks[0].command == "bash ${CLAUDE_PLUGIN_ROOT}/hooks/worker-blocked-signal.sh"' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
}

@test "R7 normal: UserPromptSubmit is registered with no matcher and the right command" {
  run jq -e '.hooks.UserPromptSubmit[0] | has("matcher") | not' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  run jq -e '.hooks.UserPromptSubmit[0].hooks[0].command == "bash ${CLAUDE_PLUGIN_ROOT}/hooks/worker-blocked-signal.sh"' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
}

@test "R7 boundary: the pre-existing Stop, PreToolUse, SessionStart entries are unchanged" {
  run jq -e '.hooks.Stop[0].hooks | length == 3' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  run jq -e '.hooks.PreToolUse[0].hooks | length == 2' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  run jq -e '.hooks.SessionStart[0].hooks | length == 3' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
}
