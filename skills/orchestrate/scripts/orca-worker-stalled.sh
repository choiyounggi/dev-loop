#!/bin/sh
# orca-worker-stalled.sh <worktree-path> — is an ALIVE worker actually moving?
#
# orca-worktree-alive.sh answers "is a terminal attached", which is not the same
# question. A worker can hold a live PTY and produce nothing for hours — a Claude
# CLI sitting on an interactive prompt (a usage-limit chooser, a trust screen, an
# auth re-login) is alive, its Orca Task still reads `dispatched`, its
# `worker`/`terminal` status still read `ready`/`running`, and orca-wait.sh just
# keeps checkpointing. Measured: three workers held that state for 75 minutes
# with byte-identical diffs, and nothing in the alive/dead split could see it.
# This script supplies the missing third state.
#
# Signal: `orca worktree ps --json` reports, per worktree, an `agents[]` array
# carrying each agent's own `state` and `updatedAt` (epoch ms). Silence in the
# AGENT's state longer than the threshold, while a terminal is still live, is a
# stall.
#
# Not `lastOutputAt` — measured and rejected. That field tracks terminal writes,
# and a TUI agent repaints its spinner continuously, so a worker wedged on an
# interactive prompt still reports output "0 seconds ago" (in practice a
# fraction of a second in the future, because the field is millisecond-precision
# while `date +%s` is not). It cannot distinguish work from a redraw.
#
#   exit 0  progressing — the agent moved within the threshold (or no live
#           terminal at all — that is orca-worktree-alive.sh’s question)
#   exit 1  STALLED — a live terminal whose agent has not moved for >= threshold
#   exit 2  cannot tell (orca down / query failed / worktree untracked / no
#           timestamp) — the caller MUST treat unknown as "not stalled", never
#           kill a worker on it
#
# env (also test hooks):
#   ORCA_STALL_MS            silence threshold in ms (default 600000 = 10 min)
#   ORCA_BIN                 orca executable (default: orca)
#   ORCA_WORKTREE_PS_JSON    canned `worktree ps` output (tests)
#   ORCA_STALL_NOW_MS        override "now" in epoch ms (tests)
set -u

ORCA="${ORCA_BIN:-orca}"
JQ=$(command -v jq) || exit 2
wt="${1:-}"
[ -n "$wt" ] || { echo "usage: orca-worker-stalled.sh <worktree-path>" >&2; exit 2; }

thr="${ORCA_STALL_MS:-600000}"
case "$thr" in ''|*[!0-9]*) exit 2 ;; esac
[ "$thr" -gt 0 ] || exit 2

now="${ORCA_STALL_NOW_MS:-}"
if [ -z "$now" ]; then
  # seconds -> ms. `date +%s` is POSIX; multiplying keeps us off GNU-only %N.
  now=$(date +%s 2>/dev/null) || exit 2
  case "$now" in ''|*[!0-9]*) exit 2 ;; esac
  now=$((now * 1000))
fi
case "$now" in ''|*[!0-9]*) exit 2 ;; esac

if [ -n "${ORCA_WORKTREE_PS_JSON:-}" ]; then
  ps="$ORCA_WORKTREE_PS_JSON"
else
  ps=$("$ORCA" worktree ps --json </dev/null 2>/dev/null) || exit 2
fi
[ -n "$ps" ] || exit 2

# Untracked worktree -> unknown, not "fine": it may simply be tmux-spawned, and
# claiming health for something we cannot see is the damaging direction.
present=$(printf '%s' "$ps" | "$JQ" -r --arg p "$wt" \
  '[.result.worktrees[]? | select(.path==$p)] | length' 2>/dev/null) || exit 2
case "$present" in ''|*[!0-9]*) exit 2 ;; esac
[ "$present" -ge 1 ] || exit 2

live=$(printf '%s' "$ps" | "$JQ" -r --arg p "$wt" \
  '[.result.worktrees[]? | select(.path==$p) | (.liveTerminalCount>0 or .hasAttachedPty==true)] | any' 2>/dev/null) || exit 2
# No live terminal is not a stall — that is the alive/dead question, and
# orca-worktree-alive.sh already answers it. Do not report both.
[ "$live" = "true" ] || exit 0

# Most recent agent activity on this worktree. No agents array at all means Orca
# is not tracking an agent here (a plain shell, or an older runtime) — unknown,
# not healthy.
last=$(printf '%s' "$ps" | "$JQ" -r --arg p "$wt" \
  '[.result.worktrees[]? | select(.path==$p) | .agents[]? | .updatedAt // empty] | max // empty' 2>/dev/null)
case "$last" in ''|*[!0-9]*) exit 2 ;; esac

# `now` is floor-to-second while `updatedAt` is millisecond-precision, so a
# genuinely fresh timestamp can read as up to a second in the future. Treat a
# small overshoot as zero silence; a large one is real clock skew and unknown.
if [ "$last" -gt "$now" ]; then
  [ $((last - now)) -le 5000 ] || exit 2
  silent=0
else
  silent=$((now - last))
fi

if [ "$silent" -ge "$thr" ]; then
  # The agent's own state is advisory context, not the verdict — print it when
  # Orca supplies it so the coordinator can tell "wedged on a prompt" from
  # "finished but never reported".
  st=$(printf '%s' "$ps" | "$JQ" -r --arg p "$wt" \
    '[.result.worktrees[]? | select(.path==$p) | (.agents[]? | .state) ] | join(",") // ""' 2>/dev/null || echo "")
  echo "[stalled] $wt — agent idle for $((silent / 1000))s (threshold $((thr / 1000))s)${st:+ — agent state: $st}"
  exit 1
fi
exit 0
