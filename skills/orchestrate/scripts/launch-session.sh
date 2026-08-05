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
#
# Submission pitfall: `send-keys` exiting 0 means "the keys reached the pane",
# NOT "the worker received the prompt". Measured 2026-08-05: of three sessions
# launched seconds apart, one had its prompt sit in the CLI's input box as
# "[Pasted text #1 +1 lines]" for 45 minutes while this script printed "ok"; a
# single extra Enter then ran it. So the prompt is not reported as delivered
# until the input box is observed empty again — see "confirm submission" below.
# Delivering a SUBSEQUENT prompt to an already-running session is not this
# script's job: scripts/session-send.sh owns that contract.
#
#   exit 0    launched and the prompt is confirmed submitted
#   exit 1    wrong argument count
#   exit 2    invalid permission mode
#   exit 4    the REPL never became ready (prints the last screen)
#   exit 5    the prompt was sent but submission could NOT be confirmed — the
#             session is alive and may hold an unsubmitted prompt (prints the
#             last screen). Distinct from 4: there the CLI never came up.
#   exit 127  tmux or claude not found
#
# env (also test hooks):
#   LO_RUN_ID          suffix making the session name unique per run
#   LO_DRY_RUN         print the resolved session name and exit
#   LO_TMUX            tmux binary (default: the one on PATH)
#   LO_CLAUDE          claude binary (default: the search below)
#   LO_READY_TIMEOUT / LO_READY_INTERVAL   REPL-ready budget (default 60 / 2);
#                      attempts = floor(timeout/interval), minimum 1
#   LO_READY_EXTRA / LO_TRUST_EXTRA        extra screen-match substrings
#   LO_SUBMIT_TIMEOUT / LO_SUBMIT_INTERVAL submission-confirm budget (default
#                      20 / 2); attempts = floor(timeout/interval), minimum 1
set -eu
# NOT named TMUX: that is tmux's OWN variable (the server socket). Assigning it
# here would overwrite the caller's exported value, and every tmux child would
# then try to connect to a binary path as a socket — measured as
# "error connecting to <path> (Socket operation on non-socket)", which breaks
# every launch whenever the coordinator itself runs inside tmux.
TMUX_BIN="${LO_TMUX:-$(command -v tmux 2>/dev/null || true)}"
[ -n "$TMUX_BIN" ] || { echo "launch-session: tmux not found" >&2; exit 127; }

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
CLAUDE="${LO_CLAUDE:-}"
if [ -z "$CLAUDE" ]; then
  for c in "$HOME"/.nvm/versions/node/*/bin/claude /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME"/.local/bin/claude; do
    [ -x "$c" ] && { CLAUDE="$c"; break; }
  done
  [ -n "$CLAUDE" ] || CLAUDE=$(command -v claude 2>/dev/null || true)
fi
[ -x "$CLAUDE" ] || { echo "launch-session: claude CLI not found" >&2; exit 127; }
claudedir=$(dirname "$CLAUDE")   # also where node lives for nvm installs

if "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
  # With a unique LO_RUN_ID name this should not happen across runs; surface it
  # loudly (stderr) instead of a silent skip so a real collision is visible.
  echo "launch-session: session '$session' already exists — reusing it (set LO_RUN_ID for a unique per-run name)" >&2
  echo "session=$session"
  exit 0
fi

"$TMUX_BIN" new-session -d -s "$session" -x 220 -y 50 -c "$wt"

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
"$TMUX_BIN" send-keys -t "$session" "$launchcmd" Enter

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
[ "$ready_timeout" -ge 1 ] 2>/dev/null || ready_timeout=60
[ "$ready_interval" -ge 1 ] 2>/dev/null || ready_interval=2
iters=$(( ready_timeout / ready_interval )); [ "$iters" -ge 1 ] || iters=1

ready=0; i=0; pane=""
while [ "$i" -lt "$iters" ]; do
  sleep "$ready_interval"
  pane=$("$TMUX_BIN" capture-pane -t "$session" -p 2>/dev/null || echo "")
  if [ -n "${LO_READY_EXTRA:-}" ] && printf '%s' "$pane" | grep -qF "$LO_READY_EXTRA"; then
    ready=1; break
  fi
  case "$pane" in
    *"bypass permissions on"*|*"shift+tab to cycle"*|*"for shortcuts"*|*"? for"*)
      ready=1; break ;;
    *"Yes, I accept"*|*"accept all responsibility"*)
      "$TMUX_BIN" send-keys -t "$session" Down; sleep 1; "$TMUX_BIN" send-keys -t "$session" Enter ;;
    *"Do you trust"*|*"trust the files"*|*"Enter to confirm"*)
      "$TMUX_BIN" send-keys -t "$session" Enter ;;
    *)
      if [ -n "${LO_TRUST_EXTRA:-}" ] && printf '%s' "$pane" | grep -qF "$LO_TRUST_EXTRA"; then
        "$TMUX_BIN" send-keys -t "$session" Enter
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
"$TMUX_BIN" send-keys -t "$session" -l "$prompt"
"$TMUX_BIN" send-keys -t "$session" Enter

# ---- confirm submission -----------------------------------------------------
# Both observed failure renderings leave the text sitting in the CLI's input box
# — once as the literal prompt, once collapsed to "[Pasted text #1 +1 lines]".
# So the check is on the BOX, not on the prompt: after a real submission the box
# is empty again. That is deliberately independent of the prompt's own text,
# which is what lets it catch the collapsed rendering (where the prompt is not
# on screen at all). The cause of the intermittency is not established, so this
# targets the symptom only.
#
# The box is the region between the last two horizontal rules of the pane. If
# the CLI's chrome changes shape and it cannot be located, fall back to looking
# for the prompt's own head in the bottom of the screen. Either way, "cannot
# tell" is reported as exit 5, never as success.
submit_timeout="${LO_SUBMIT_TIMEOUT:-20}"; submit_interval="${LO_SUBMIT_INTERVAL:-2}"
[ "$submit_timeout" -ge 1 ] 2>/dev/null || submit_timeout=20
[ "$submit_interval" -ge 1 ] 2>/dev/null || submit_interval=2
sub_iters=$(( submit_timeout / submit_interval )); [ "$sub_iters" -ge 1 ] || sub_iters=1

# first 40 chars of the prompt — the fallback fingerprint. 40 cannot wrap: the
# pane is created 220 columns wide above.
fingerprint=$(printf '%s' "$prompt" | cut -c1-40)

input_box() { # $1 = pane text -> the input-box region, or rc 1 if not locatable
  _rules=$(printf '%s\n' "$1" | grep -n '^[[:space:]]*─\{3,\}[[:space:]]*$' | cut -d: -f1)
  [ "$(printf '%s' "$_rules" | grep -c .)" -ge 2 ] || return 1
  _last=$(printf '%s\n' "$_rules" | tail -1)
  _prev=$(printf '%s\n' "$_rules" | tail -2 | head -1)
  [ "$_prev" -lt "$_last" ] || return 1
  printf '%s\n' "$1" | sed -n "$((_prev + 1)),$((_last - 1))p"
}

submitted=0; sent_extra=0; j=0
while [ "$j" -lt "$sub_iters" ]; do
  sleep "$submit_interval"
  pane=$("$TMUX_BIN" capture-pane -t "$session" -p 2>/dev/null || echo "")
  if [ -z "$pane" ]; then
    # nothing to read (pane gone, capture failed) — cannot confirm, never assume
    j=$((j + 1)); continue
  fi
  if box=$(input_box "$pane"); then
    # empty box = the prompt left the input line = submitted. Strip the prompt
    # marker itself; anything else non-blank means it is still sitting there.
    if printf '%s' "$box" | sed 's/❯//g' | grep -q '[^[:space:]]'; then
      still=1
    else
      still=0
    fi
  else
    # chrome not recognised: fall back to the prompt's own head near the bottom
    tail_pane=$(printf '%s\n' "$pane" | tail -15)
    if [ -n "$fingerprint" ] && printf '%s' "$tail_pane" | grep -qF "$fingerprint"; then
      still=1
    elif printf '%s' "$tail_pane" | grep -qF '[Pasted text'; then
      still=1
    else
      still=0
    fi
  fi
  [ "$still" -eq 0 ] && { submitted=1; break; }
  # The one remedy proven in the field: a further Enter submits it. Harmless when
  # the box is already empty, so it is safe to repeat within the budget.
  "$TMUX_BIN" send-keys -t "$session" Enter
  sent_extra=$((sent_extra + 1))
  j=$((j + 1))
done

if [ "$submitted" -ne 1 ]; then
  echo "launch-session: $session prompt NOT confirmed submitted after ${submit_timeout}s — the session is alive and may be holding the prompt unsubmitted in its input box; send one Enter to '$session' or relaunch (last screen below)" >&2
  echo "$pane" | tail -8 >&2
  exit 5
fi

if [ "$sent_extra" -gt 0 ]; then
  echo "ok: $session launched + prompt submitted (confirmed after $sent_extra extra Enter)"
else
  echo "ok: $session launched + prompt submitted (confirmed)"
fi
