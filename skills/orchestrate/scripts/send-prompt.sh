#!/bin/sh
# send-prompt.sh — deliver a prompt to an ALREADY-RUNNING worker session, and
# report what actually happened.
#
# `tmux send-keys` succeeds as soon as the keys are written to the pane. That
# says nothing about whether the worker received the prompt: measured on this
# repo, a second prompt sent while a worker was mid-turn sat as
# "Press up to edit queued messages" for 55s while a Stop-hook chain drained,
# and tmux reported success immediately. This script turns that into a verdict.
#
# The launch path is NOT here — launch-session.sh owns the trust screen and the
# first injection. This script is for every prompt after that one.
#
# usage:
#   send-prompt.sh send  <session> <prompt>    deliver one prompt, classify it
#   send-prompt.sh wait  <session> [timeout]   block until the worker picks it up
#   send-prompt.sh state <session>             read-only: print one state token
#
# exit  send            wait                   state
#  0    delivered       picked-up              ready
#  1    usage error     usage error            usage error
#  2    invalid input (session name / prompt rejected) — injection guard
#  3    session gone    session gone           gone
#  4    queued          —                      busy
#  5    —               deadline expired       —
#  6    tmux command failed against a live session
#  7    unconfirmed     —                      —
# 127   tmux not found
#
# stdout is exactly one token — delivered|queued|unconfirmed|picked-up|timeout|
# ready|busy|gone. Branch on the exit code; stderr is advisory context only and
# must never be parsed.
#
# env:
#   LO_QUEUED_PATTERN   substring meaning "queued behind a busy turn"
#   LO_BUSY_PATTERN     substring meaning "mid-turn" (state only)
#   LO_PANE_TAIL_LINES  non-empty pane lines searched for those (default 6)
#   LO_CONFIRM_DELAY    seconds to settle before classifying a send (default 1)
#   LO_PICKUP_TIMEOUT   wait deadline in seconds (default 180)
#   LO_PICKUP_INTERVAL  wait poll interval in seconds (default 2)
set -eu

# NOT named TMUX: tmux exports TMUX="<socket>,<pid>,<session>" into every pane,
# so a script running inside a session inherits it as an EXPORTED variable.
# Assigning to it keeps it exported, and the tmux we then invoke reads the
# binary path as a socket path and dies with "Socket operation on non-socket".
TMUX_BIN=$(command -v tmux) || { echo "send-prompt: tmux not found" >&2; exit 127; }

# The queued/busy wording belongs to the Claude Code CLI, not to this repo, so a
# CLI release can rename it. Observed 2026-08-05. Override rather than guess:
# a stale pattern must fail loudly here, not silently downgrade a queued prompt
# into a reported "delivered".
queued_pat="${LO_QUEUED_PATTERN:-Press up to edit queued messages}"
busy_pat="${LO_BUSY_PATTERN:-esc to interrupt}"

# Every grep against these uses `-- "$pat"`. A pattern beginning with '-' is
# otherwise parsed as a grep flag ("unrecognized option"), which is the same
# defect the '--' before the send-keys payload guards against.

# Seconds to let the pane settle before classifying a send. Sanitised, because a
# junk value would otherwise reach `sleep` and abort the script under `set -e`
# with an exit code that means nothing to the caller.
confirm_delay="${LO_CONFIRM_DELAY:-1}"
case "$confirm_delay" in ''|*[!0-9]*) confirm_delay=1 ;; esac

usage() {
  cat >&2 <<'EOF'
usage: send-prompt.sh <subcommand> ...
  send  <session> <prompt>    deliver one prompt to a running session
  wait  <session> [timeout]   block until the worker picks the prompt up
  state <session>             print one state token (read-only)
EOF
  exit 1
}

# A tmux target without a leading '=' is PREFIX-matched: `-t lo-1` resolves to a
# session actually named `lo-1-r1`, so every target here is exact.
# The two target kinds are NOT interchangeable: has-session takes a session
# ("=name"), while capture-pane and send-keys take a PANE ("=name:" — exact
# session, its current window, active pane). "=name" alone fails a pane target
# with "can't find pane".
target_session() { printf '=%s' "$1"; }
target_pane() { printf '=%s:' "$1"; }

# Allowlist the session name. It is interpolated into a tmux command line, where
# a leading '-' would be parsed as a flag, so reject anything that is not a
# plain identifier instead of trying to escape it.
validate_session() {
  case "$1" in
    ''|-*|*[!A-Za-z0-9_-]*)
      echo "send-prompt: invalid session name '$1' (allowed: A-Z a-z 0-9 _ -, not leading '-')" >&2
      exit 2 ;;
  esac
}

# The prompt is free text (it carries a whole task brief), so it gets no
# allowlist — only an encoding check. Control characters are rejected: a newline
# would submit a partial prompt and leave the remainder as a stray command.
# LC_ALL=C keeps this to bytes 0x00-0x1F/0x7F, so UTF-8 text survives intact.
validate_prompt() {
  [ -n "$1" ] || { echo "send-prompt: empty prompt" >&2; exit 2; }
  stripped=$(printf '%s' "$1" | LC_ALL=C tr -d '[:cntrl:]')
  [ "$stripped" = "$1" ] || {
    echo "send-prompt: prompt contains a control character" >&2; exit 2; }
}

session_alive() { "$TMUX_BIN" has-session -t "$(target_session "$1")" 2>/dev/null; }

# The last non-empty lines of the pane. A TUI paints its queued/busy indicator
# at the bottom and repaints it away when the queue drains; scrollback further
# up never clears, so searching the whole pane would latch on stale text.
#
# Returns non-zero when the capture itself fails. That must NOT collapse into an
# empty string: "no marker found" and "could not look" are different answers,
# and silently returning the former is how a stale verdict gets reported as fact.
pane_tail() {
  raw=$(capture_pane "$1") || return 1
  printf '%s\n' "$raw" | grep -v '^[[:space:]]*$' \
    | tail -n "${LO_PANE_TAIL_LINES:-6}" || true
}

capture_pane() { "$TMUX_BIN" capture-pane -t "$(target_pane "$1")" -p 2>/dev/null; }

# Advisory context for a human reading the log — never part of stdout.
note_pane() {
  last=$(pane_tail "$1" | tail -n 1)
  [ -n "$last" ] && echo "send-prompt[$1]: $last" >&2 || true
}

cmd_state() {
  [ $# -eq 1 ] || usage
  validate_session "$1"
  if ! session_alive "$1"; then
    echo "gone"; exit 3
  fi
  pane=$(pane_tail "$1") || {
    echo "send-prompt: capture-pane failed for live session '$1'" >&2; exit 6; }
  if printf '%s' "$pane" | grep -qF -- "$queued_pat" 2>/dev/null \
    || printf '%s' "$pane" | grep -qF -- "$busy_pat" 2>/dev/null; then
    note_pane "$1"
    echo "busy"; exit 4
  fi
  echo "ready"; exit 0
}

cmd_send() {
  [ $# -eq 2 ] || usage
  validate_session "$1"
  validate_prompt "$2"
  if ! session_alive "$1"; then
    echo "gone"; exit 3
  fi

  before=$(pane_tail "$1") || {
    echo "send-prompt: capture-pane failed for live session '$1'" >&2; exit 6; }

  # The payload goes after '--'. Without it tmux parses a prompt that begins with
  # '-' as its own flag ("unknown flag -n") and the prompt is never delivered.
  # The prompt never reaches a shell: it is one argv element to tmux, so shell
  # metacharacters in it are inert.
  failed=0
  "$TMUX_BIN" send-keys -t "$(target_pane "$1")" -l -- "$2" || failed=1
  [ "$failed" -eq 1 ] || "$TMUX_BIN" send-keys -t "$(target_pane "$1")" Enter || failed=1
  if [ "$failed" -eq 1 ]; then
    # A send can fail because the worker died mid-call. Re-ask rather than
    # reporting a generic error for what is really a gone session.
    session_alive "$1" || { echo "gone"; exit 3; }
    echo "send-prompt: send-keys failed for live session '$1'" >&2
    exit 6
  fi

  sleep "$confirm_delay"
  after=$(pane_tail "$1") || {
    echo "send-prompt: capture-pane failed for live session '$1'" >&2; exit 6; }

  # Order is load-bearing, do not reorder. A busy pane still ECHOES the typed
  # characters, so the pane changes even when the prompt was only queued —
  # measured. Testing "did the pane change" first therefore reports a false
  # "delivered" for exactly the case this script exists to catch.
  if printf '%s' "$after" | grep -qF -- "$queued_pat" 2>/dev/null; then
    note_pane "$1"
    echo "queued"; exit 4
  fi
  if [ "$after" != "$before" ]; then
    echo "delivered"; exit 0
  fi
  # Keys were written, but nothing observable happened. Report the uncertainty
  # instead of defaulting to success.
  note_pane "$1"
  echo "unconfirmed"; exit 7
}

# Bounded wait for the worker to actually pick a queued prompt up.
#
# The deadline is counted in poll iterations, not clock arithmetic: `timeout(1)`
# is absent from stock macOS and `date -d` is GNU-only, so either would work on
# CI's ubuntu runner and fail on its macos one.
#
# Default 180s: the field case took 55s to pick up, behind a Stop-hook chain
# that ran 116s. 180s is that worst observation plus headroom, not a guess.
cmd_wait() {
  [ $# -ge 1 ] && [ $# -le 2 ] || usage
  validate_session "$1"

  timeout="${2:-${LO_PICKUP_TIMEOUT:-180}}"
  case "$timeout" in ''|*[!0-9]*) usage ;; esac
  [ "$timeout" -ge 1 ] || usage

  interval="${LO_PICKUP_INTERVAL:-2}"
  case "$interval" in ''|*[!0-9]*) interval=2 ;; esac
  [ "$interval" -ge 1 ] || interval=2

  # Floor UP to one iteration: a deadline shorter than a single interval must
  # still look once, or an idle worker is reported as a false timeout.
  iters=$(( timeout / interval ))
  [ "$iters" -ge 1 ] || iters=1

  i=0
  while [ "$i" -lt "$iters" ]; do
    session_alive "$1" || { echo "gone"; exit 3; }
    pane=$(pane_tail "$1") || {
      echo "send-prompt: capture-pane failed for live session '$1'" >&2; exit 6; }
    if ! printf '%s' "$pane" | grep -qF -- "$queued_pat" 2>/dev/null; then
      echo "picked-up"; exit 0
    fi
    sleep "$interval"
    i=$((i+1))
  done

  # Still queued at the deadline. This is NOT "lost" — it is "still working",
  # and it gets its own code so a coordinator can tell the two apart.
  note_pane "$1"
  echo "timeout"; exit 5
}

[ $# -ge 1 ] || usage
sub="$1"; shift
case "$sub" in
  send)  cmd_send "$@" ;;
  wait)  cmd_wait "$@" ;;
  state) cmd_state "$@" ;;
  *) usage ;;
esac
