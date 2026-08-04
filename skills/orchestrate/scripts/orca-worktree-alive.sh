#!/bin/sh
# orca-worktree-alive.sh <worktree-path> — the Orca-native liveness signal for an
# orca-spawned worker. Uses `orca worktree ps --json` (verified fields
# liveTerminalCount / hasAttachedPty). For orca-spawned workers this replaces the
# tmux `has-session` check in watch-status.
#
#   exit 0  a live agent terminal is attached to the worktree
#   exit 1  the worktree is tracked but has no live terminal (dead worker)
#   exit 2  cannot tell (orca down / query failed / bad input) — caller MUST treat
#           "unknown" as "do not flag dead", never as dead
# env: ORCA_BIN (default orca), ORCA_WORKTREE_PS_JSON (canned ps output, tests)
set -u

ORCA="${ORCA_BIN:-orca}"
JQ=$(command -v jq) || exit 2
wt="${1:?usage: orca-worktree-alive.sh <worktree-path>}"

if [ -n "${ORCA_WORKTREE_PS_JSON:-}" ]; then
  ps="$ORCA_WORKTREE_PS_JSON"
else
  ps=$("$ORCA" worktree ps --json 2>/dev/null) || exit 2
fi
[ -n "$ps" ] || exit 2

# is the worktree present at all? (absent → unknown, not "dead": it may simply be
# tmux-spawned and not Orca-managed)
present=$(printf '%s' "$ps" | "$JQ" -r --arg p "$wt" \
  '[.result.worktrees[]? | select(.path==$p)] | length' 2>/dev/null) || exit 2
case "$present" in ''|*[!0-9]*) exit 2 ;; esac
[ "$present" -ge 1 ] || exit 2

alive=$(printf '%s' "$ps" | "$JQ" -r --arg p "$wt" \
  '[.result.worktrees[]? | select(.path==$p) | (.liveTerminalCount>0 or .hasAttachedPty==true)] | any' 2>/dev/null) || exit 2
[ "$alive" = "true" ] && exit 0
exit 1
