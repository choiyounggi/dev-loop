#!/bin/sh
# orca-spawn.sh — launch a Claude worker inside an Orca-managed worktree: the
# Orca-substrate equivalent of launch-session.sh. Orca resolves the trust/TUI
# screen (`terminal wait --for tui-idle`) instead of the fragile pattern-match,
# and tracks the session natively (see orca-worktree-alive.sh for liveness).
#
# Gate on scripts/orca-detect.sh (exit 0) before using this; else use the tmux
# launch-session.sh path.
#
# usage: orca-spawn.sh <orca-worktree-id> <perm-mode> <prompt>
#   <orca-worktree-id>  "<repoId>::<path>" from `orca worktree create/list --json`
# env:
#   ORCA_BIN                     orca executable (default: orca)
#   GROUNDWORK_ESCALATION_DIR    exported into the worker so an `ask` escalates
#   GROUNDWORK_TASK_ID           worker task label
#   LO_READY_TIMEOUT             seconds to wait for TUI readiness (default 60)
#   ORCA_SPAWN_DRYRUN=1          print the orca commands instead of running them
#   ORCA_SPAWN_CREATE_JSON       canned `terminal create --json` (tests)
# On success prints `handle=<terminal-handle>` — the agent handle to send to.
set -u

ORCA="${ORCA_BIN:-orca}"
JQ=$(command -v jq) || { echo "orca-spawn: jq not found" >&2; exit 127; }

wtid="${1:?usage: orca-spawn.sh <orca-worktree-id> <perm-mode> <prompt>}"
perm="${2:?usage: orca-spawn.sh <orca-worktree-id> <perm-mode> <prompt>}"
prompt="${3:?usage: orca-spawn.sh <orca-worktree-id> <perm-mode> <prompt>}"

# whitelist the permission mode — it is interpolated into the worker command.
case "$perm" in
  bypassPermissions|acceptEdits|plan|default) : ;;
  *) echo "orca-spawn: invalid permission mode '$perm'" >&2; exit 2 ;;
esac

rt="${LO_READY_TIMEOUT:-60}"; [ "$rt" -ge 1 ] 2>/dev/null || rt=60
timeout_ms=$(( rt * 1000 ))

# Worker command: carry the guardrails escalation env so a headless worker
# escalates instead of blocking on an `ask`. Values are single-quoted with
# embedded single quotes escaped (`'\''`) so a path with any metacharacter —
# including a quote — cannot break out of the command.
esc_sq() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }
env_prefix=""
if [ -n "${GROUNDWORK_ESCALATION_DIR:-}" ]; then
  env_prefix="export GROUNDWORK_ESCALATION_DIR='$(esc_sq "$GROUNDWORK_ESCALATION_DIR")' && export GROUNDWORK_TASK_ID='$(esc_sq "${GROUNDWORK_TASK_ID:-}")' && "
fi
worker_cmd="${env_prefix}claude --permission-mode ${perm}"

print_cmd() { printf 'orca'; for a in "$@"; do printf ' [%s]' "$a"; done; printf '\n'; }
orca_run() {  # $1 = fatal flag (1 = return non-zero on failure); rest = orca args
  _fatal="$1"; shift
  if [ -n "${ORCA_SPAWN_DRYRUN:-}" ]; then print_cmd "$@"; return 0; fi
  "$ORCA" "$@" >/dev/null 2>&1 && return 0
  if [ "$_fatal" = 1 ]; then echo "orca-spawn: '$1 $2' failed" >&2; return 1; fi
  echo "orca-spawn: warning: '$1 $2' failed (continuing)" >&2; return 0
}

# 1) create the Claude terminal in the worktree
if [ -n "${ORCA_SPAWN_CREATE_JSON:-}" ]; then
  create_out="$ORCA_SPAWN_CREATE_JSON"
  [ -n "${ORCA_SPAWN_DRYRUN:-}" ] && print_cmd terminal create --worktree "id:$wtid" --command "$worker_cmd" --json
elif [ -n "${ORCA_SPAWN_DRYRUN:-}" ]; then
  print_cmd terminal create --worktree "id:$wtid" --command "$worker_cmd" --json
  create_out=""
else
  create_out=$("$ORCA" terminal create --worktree "id:$wtid" --command "$worker_cmd" --json 2>/dev/null)
fi

# resolve the agent handle. `terminal create` returns .result.terminal.handle
# (verified live); .result.startupTerminal.handle is the `worktree create --agent`
# form; .handle is a generic fallback; else re-list the worktree's terminals.
if [ -n "$create_out" ]; then
  handle=$(printf '%s' "$create_out" | "$JQ" -r '.result.terminal.handle // .result.startupTerminal.handle // .result.handle // empty' 2>/dev/null)
  if [ -z "$handle" ] && [ -z "${ORCA_SPAWN_DRYRUN:-}" ]; then
    handle=$("$ORCA" terminal list --worktree "id:$wtid" --json 2>/dev/null \
      | "$JQ" -r '.result.terminals[0].handle // empty' 2>/dev/null)
  fi
  [ -n "$handle" ] || { echo "orca-spawn: no terminal handle from create" >&2; exit 3; }
else
  handle="term_DRYRUN"
fi

# 2) wait for the agent CLI to be ready (replaces the trust-screen pattern match).
#    A timeout here is a warning, not fatal — the terminal still exists.
orca_run 0 terminal wait --terminal "$handle" --for tui-idle --timeout-ms "$timeout_ms" --json
# 3) send the prompt — if this fails the worker received nothing, so fail hard.
orca_run 1 terminal send --terminal "$handle" --text "$prompt" --enter --json \
  || { echo "orca-spawn: failed to deliver the prompt to $handle" >&2; exit 4; }

echo "handle=$handle"
