#!/bin/sh
# tmux-worker-stalled.sh <tmux-session> — is an ALIVE tmux worker actually moving?
#
# watch-status.sh answers "does the tmux session still exist", which is not the
# same question. A worker can hold a live session and produce nothing for hours —
# a Claude CLI sitting on an interactive prompt (a usage-limit chooser, a trust
# screen, an auth re-login, or a prompt that was typed but never submitted) is
# alive, `tmux has-session` succeeds, and watch-status.sh just keeps polling.
# Measured on the Orca side: three workers held that state for 75 minutes with
# byte-identical diffs. This script supplies the missing third state for tmux,
# mirroring orca-worker-stalled.sh.
#
# Signal: the hash of `capture-pane -p`. A pane whose rendered content is
# unchanged for longer than the threshold, while its session is still alive, is
# a stall. tmux exposes no "content last changed" timestamp, so the silence is
# accumulated across polls through a small state file (see below) rather than
# measured in one call — the caller is expected to poll (watch-status.sh's own
# cadence is 15s).
#
# NOT `#{window_activity}` — measured 2026-08-05 and rejected. It advances on any
# byte written to the pane, so a TUI that merely repaints keeps it fresh: a pane
# rewriting the SAME bytes every 0.5s and a pane doing real work both reported it
# tracking `now` exactly. That is the same trap Orca hit with `lastOutputAt`.
# `#{session_activity}` was rejected too — it never advanced for any pane.
#
#   exit 0  progressing — the pane changed within the threshold, this is the
#           first observation, or the session is gone (that is the alive/dead
#           question, and watch-status.sh already owns it)
#   exit 1  STALLED — a live session whose pane has not changed for >= threshold
#   exit 2  cannot tell (no tmux / capture failed / empty capture / no hasher /
#           unusable state dir / corrupt state / clock skew) — the caller MUST
#           treat unknown as "not stalled", never kill a worker on it
#
# A worker busy in its Stop hooks is NOT a stall: measured, that state renders a
# ticking counter ("running stop hooks… 6/7 · 1m 36s"), so the pane keeps
# changing and this reports progressing. Hook chains of ~2 minutes were measured;
# the 600s default leaves ample room above them.
#
# env (also test hooks):
#   LO_STALL_SEC        silence threshold in seconds (default 600 = 10 min,
#                       matching orca-worker-stalled.sh's ORCA_STALL_MS)
#   LO_STALL_TMUX       tmux executable (default: the one on PATH)
#   LO_STALL_STATE_DIR  where per-session state lives
#                       (default: ${XDG_STATE_HOME:-$HOME/.local/state}/dev-loop/stall)
#   LO_STALL_NOW        override "now" in epoch seconds (tests)
#
# state file: <state-dir>/<session>.stall, one line "<pane-hash> <first-seen-epoch>"
set -u

sess="${1:-}"
[ -n "$sess" ] || { echo "usage: tmux-worker-stalled.sh <tmux-session>" >&2; exit 2; }
# The session name becomes a filename below. Refuse anything that could escape
# the state dir rather than writing outside it.
case "$sess" in
  */*|.|..) echo "tmux-worker-stalled: invalid session name '$sess'" >&2; exit 2 ;;
esac

thr="${LO_STALL_SEC:-600}"
case "$thr" in ''|*[!0-9]*) exit 2 ;; esac
[ "$thr" -gt 0 ] || exit 2

now="${LO_STALL_NOW:-}"
if [ -z "$now" ]; then
  # `date +%s` is POSIX; `date +%N` is GNU-only, so this stays second-granular.
  now=$(date +%s 2>/dev/null) || exit 2
fi
case "$now" in ''|*[!0-9]*) exit 2 ;; esac

TMUX_BIN="${LO_STALL_TMUX:-$(command -v tmux 2>/dev/null || true)}"
[ -n "$TMUX_BIN" ] && [ -x "$TMUX_BIN" ] || exit 2

# A dead session is not a stall — watch-status.sh's liveness check owns that, and
# reporting it here too would double-count one failure as two.
"$TMUX_BIN" has-session -t "$sess" </dev/null 2>/dev/null || exit 0

pane=$("$TMUX_BIN" capture-pane -t "$sess" -p </dev/null 2>/dev/null) || exit 2
# An empty capture is "cannot read the pane", not "the pane is blank and calm".
[ -n "$pane" ] || exit 2

# md5sum is GNU, md5 is BSD; resolve once and refuse rather than ever comparing
# unhashed content, which would make every long pane compare unequal by accident.
hash=""
if command -v md5sum >/dev/null 2>&1; then
  hash=$(printf '%s' "$pane" | md5sum 2>/dev/null | cut -d' ' -f1)
elif command -v md5 >/dev/null 2>&1; then
  hash=$(printf '%s' "$pane" | md5 -q 2>/dev/null)
fi
case "$hash" in ''|*[!0-9a-fA-F]*) exit 2 ;; esac

state_dir="${LO_STALL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dev-loop/stall}"
mkdir -p "$state_dir" 2>/dev/null || exit 2
[ -w "$state_dir" ] || exit 2
state="$state_dir/$sess.stall"

record() { printf '%s %s\n' "$1" "$2" > "$state" 2>/dev/null || return 1; }

# First observation: record it and report progressing. A single sample carries no
# information about silence, so it can never be a stall.
[ -f "$state" ] || { record "$hash" "$now" || exit 2; exit 0; }

read -r prev_hash prev_ts _rest < "$state" 2>/dev/null || { record "$hash" "$now"; exit 2; }
# Corrupt state tells us nothing about how long the pane has been still. Report
# unknown, but re-seed it so the next poll has a usable baseline (self-healing).
if [ -z "${prev_hash:-}" ] || [ -z "${prev_ts:-}" ]; then record "$hash" "$now"; exit 2; fi
case "$prev_ts" in ''|*[!0-9]*) record "$hash" "$now"; exit 2 ;; esac

# The pane moved: reset the clock on the new content.
if [ "$prev_hash" != "$hash" ]; then
  record "$hash" "$now" || exit 2
  exit 0
fi

# Same content. `now` and the stored stamp are both floor-to-second, so a tiny
# backwards step is precision, not a real move; a large one means the clock was
# adjusted and the elapsed time is not trustworthy.
if [ "$prev_ts" -gt "$now" ]; then
  [ $((prev_ts - now)) -le 5 ] || exit 2
  silent=0
else
  silent=$((now - prev_ts))
fi

if [ "$silent" -ge "$thr" ]; then
  echo "[stalled] $sess — pane unchanged for ${silent}s (threshold ${thr}s)"
  exit 1
fi
exit 0
