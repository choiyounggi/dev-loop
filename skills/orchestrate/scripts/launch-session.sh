#!/bin/sh
# launch-session.sh — start a claude session inside a tmux window, pass the
# trust / permission screen, then inject a one-line prompt.
#
# usage: launch-session.sh <session> <worktree> <perm-mode> <prompt-oneliner>
#   <session>   tmux session name (e.g. lo-1)
#   <worktree>  absolute path to the task worktree
#   <perm-mode> claude --permission-mode value (e.g. bypassPermissions)
#   <prompt>    one-line prompt to inject (no newlines)
#
# Trust pitfall: on a fresh worktree, claude's first launch shows a trust /
# permission screen that swallows a start-arg prompt. So we pass the screen,
# confirm the REPL is ready, then send-keys the prompt separately. The screen
# wording is version-dependent (design §8.11) — patterns are kept in one place.
set -eu
TMUX=$(command -v tmux) || { echo "launch-session: tmux not found" >&2; exit 127; }

[ $# -eq 4 ] || { echo "usage: launch-session.sh <session> <worktree> <perm> <prompt>" >&2; exit 1; }
session="$1"; wt="$2"; perm="$3"; prompt="$4"

# Make the session name unique per orchestration run so a stale session from a
# previous run cannot collide (and get silently skipped below). The orchestrator
# sets LO_RUN_ID once per run and reuses the resulting name for later send-keys.
[ -n "${LO_RUN_ID:-}" ] && session="${session}-${LO_RUN_ID}"

# whitelist the permission mode — it is interpolated into a shell command sent to
# the pane, so reject anything unexpected (injection guard).
case "$perm" in
  bypassPermissions|acceptEdits|plan|default) : ;;
  *) echo "launch-session: invalid permission mode '$perm'" >&2; exit 2 ;;
esac

# Resolve-only mode: print the effective session name and exit before touching
# tmux/claude. Lets the orchestrator (and tests) learn the exact name.
if [ -n "${LO_DRY_RUN:-}" ]; then echo "session=$session"; exit 0; fi

# locate the claude binary (avoid nvm lazy wrappers / shell functions)
CLAUDE=""
for c in "$HOME"/.nvm/versions/node/*/bin/claude /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME"/.local/bin/claude; do
  [ -x "$c" ] && { CLAUDE="$c"; break; }
done
[ -n "$CLAUDE" ] || CLAUDE=$(command -v claude 2>/dev/null || true)
[ -x "$CLAUDE" ] || { echo "launch-session: claude CLI not found" >&2; exit 127; }
claudedir=$(dirname "$CLAUDE")   # also where node lives for nvm installs

if "$TMUX" has-session -t "$session" 2>/dev/null; then
  # With a unique LO_RUN_ID name this should not happen across runs; surface it
  # loudly (stderr) instead of a silent skip so a real collision is visible.
  echo "launch-session: session '$session' already exists — reusing it (set LO_RUN_ID for a unique per-run name)" >&2
  echo "session=$session"
  exit 0
fi

"$TMUX" new-session -d -s "$session" -x 220 -y 50 -c "$wt"

# Route guardrails `ask` decisions in this (headless) worker to the coordinator
# instead of blocking it. The escalation dir is the main repo's; task id = session.
esc=$(sh "$(dirname "$0")/escalation-dir.sh" "$wt" 2>/dev/null || echo "")
launchcmd="export PATH=\"$claudedir:\$PATH\""
if [ -n "$esc" ]; then
  # single-quote the values in the pane-side command so a path/name with shell
  # metacharacters can't break or inject into the launched command
  launchcmd="$launchcmd && export GROUNDWORK_ESCALATION_DIR='$esc' && export GROUNDWORK_TASK_ID='$session'"
fi
launchcmd="$launchcmd && \"$CLAUDE\" --permission-mode $perm"
"$TMUX" send-keys -t "$session" "$launchcmd" Enter

# Pass trust screen + permission warning, wait for REPL ready (~60s).
# NOTE: the bypassPermissions warning defaults to "1. No, exit" — pressing Enter
# would quit claude. We must Down->Enter to pick "Yes, I accept". The ready/accept
# patterns are matched before the generic trust patterns.
# Wording is version-dependent, so the wait budget and the match patterns are
# tunable via env — adapt to a new CLI without editing this file:
#   LO_READY_TIMEOUT / LO_READY_INTERVAL  (seconds; default 60 / 2)
#   LO_READY_EXTRA   an extra substring that means "REPL is ready"
#   LO_TRUST_EXTRA   an extra substring of a trust prompt to confirm with Enter
ready_timeout="${LO_READY_TIMEOUT:-60}"; ready_interval="${LO_READY_INTERVAL:-2}"
[ "$ready_interval" -ge 1 ] 2>/dev/null || ready_interval=2
iters=$(( ready_timeout / ready_interval )); [ "$iters" -ge 1 ] || iters=1

ready=0; i=0; pane=""
while [ "$i" -lt "$iters" ]; do
  sleep "$ready_interval"
  pane=$("$TMUX" capture-pane -t "$session" -p 2>/dev/null || echo "")
  if [ -n "${LO_READY_EXTRA:-}" ] && printf '%s' "$pane" | grep -qF "$LO_READY_EXTRA"; then
    ready=1; break
  fi
  case "$pane" in
    *"bypass permissions on"*|*"shift+tab to cycle"*|*"for shortcuts"*|*"? for"*)
      ready=1; break ;;
    *"Yes, I accept"*|*"accept all responsibility"*)
      "$TMUX" send-keys -t "$session" Down; sleep 1; "$TMUX" send-keys -t "$session" Enter ;;
    *"Do you trust"*|*"trust the files"*|*"Enter to confirm"*)
      "$TMUX" send-keys -t "$session" Enter ;;
    *)
      if [ -n "${LO_TRUST_EXTRA:-}" ] && printf '%s' "$pane" | grep -qF "$LO_TRUST_EXTRA"; then
        "$TMUX" send-keys -t "$session" Enter
      fi ;;
  esac
  i=$((i+1))
done

if [ "$ready" -ne 1 ]; then
  echo "launch-session: $session REPL not ready — manual check (last screen below)" >&2
  echo "$pane" | tail -8 >&2
  exit 4
fi

# inject the one-line prompt (literal) then submit
"$TMUX" send-keys -t "$session" -l "$prompt"
"$TMUX" send-keys -t "$session" Enter
echo "ok: $session launched + prompt injected"
