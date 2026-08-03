#!/bin/sh
# escalation-dir.sh <worktree> — print the guardrails escalation dir for a task
# worktree: its MAIN repo's .orchestration/escalations. A guardrails worker writes
# escalation records here (GROUNDWORK_ESCALATION_DIR); watch-status reads them.
#
# Prints nothing (exit 0) when the path is not a git worktree, so callers can
# treat "no dir" as "escalation not wired" and fall back cleanly.
set -eu

wt="${1:?usage: escalation-dir.sh <worktree>}"
GIT=$(command -v git) || exit 0

# --git-common-dir points at the MAIN repo's .git even from a linked worktree.
common=$("$GIT" -C "$wt" rev-parse --git-common-dir 2>/dev/null) || exit 0
[ -n "$common" ] || exit 0

# Resolve to the main worktree root (parent of the common .git dir). The common
# path may be relative to $wt, so resolve from there.
mainroot=$(cd "$wt" 2>/dev/null && cd "$(dirname "$common")" 2>/dev/null && pwd -P) || exit 0
[ -n "$mainroot" ] || exit 0
# Sanity-check the derived root actually holds a git dir/file (guards a stale or
# corrupt --git-common-dir). -e (not -d) also accepts a separate-git-dir setup.
[ -e "$mainroot/.git" ] || exit 0

printf '%s/.orchestration/escalations\n' "$mainroot"
