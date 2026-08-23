#!/bin/sh
# worker-guardrails.sh <worktree-path> — scope guardrails inside ONE worker
# worktree and keep the config out of commits.
#
# An isolated sandbox loosens harmless rules (rm_rf, git_discard, tmp writes) and
# keeps genuinely dangerous ones as `ask` — which the escalation env
# (GROUNDWORK_ESCALATION_DIR, exported by launch-session.sh / orca-worker-start.sh)
# turns into a coordinator escalation rather than a hard block. Unknown rule ids
# are ignored by older guardrails, so worktree_escape is forward-compatible.
#
# worktree_escape stays `ask` — `allowPaths` declares the ONE sanctioned path
# (`.orchestration`, the coordination dir a worker writes its status and plan into)
# rather than disabling the rule. Without it every such write reads as a write into
# the main worktree: measured 2026-08-05, three escalations in one run, each
# aborting the watch (exit 5) for legitimate coordination writes. Older guardrails
# read only `.rules[<id>].mode` (guardrails 1.0.0 hooks/bash-guard.sh, inspected
# 2026-08-05), so they ignore the extra key — safe to ship before the release that
# implements it. Paths are relative to the MAIN worktree root.
#
# This is the SINGLE source of the worker config. `setup-worktrees.sh` calls it
# for the tmux substrate; on the Orca substrate the worktree is created by
# `orca worktree create`, so the orchestrator calls this script directly with the
# path Orca reports — same contract, no prose to re-implement.
#
# usage: worker-guardrails.sh <worktree-path>
# exit: 0 written (idempotent) | 1 usage | 2 path is not a directory
set -eu

wt="${1:-}"
[ -n "$wt" ] || { echo "usage: worker-guardrails.sh <worktree-path>" >&2; exit 1; }
[ -d "$wt" ] || { echo "worker-guardrails: '$wt' is not a directory — create the worktree first" >&2; exit 2; }

mkdir -p "$wt/.groundwork"
cat > "$wt/.groundwork/guardrails.json" <<'GRJSON'
{"rules":{"rm_rf":{"mode":"off"},"git_discard":{"mode":"off"},"system_tmp_write":{"mode":"off"},"cloud_delete":{"mode":"ask"},"sql_drop":{"mode":"ask"},"git_force_push":{"mode":"ask"},"secret_export":{"mode":"ask"},"curl_pipe_shell":{"mode":"ask"},"worktree_escape":{"mode":"ask","allowPaths":[".orchestration"]}}}
GRJSON

# Keep the sandbox config out of commits (worktree-local git exclude). Create the
# exclude file if it does not exist, and never let an append failure abort the
# caller (set -e) — warn instead. A non-git path is fine: the config still applies.
GIT=$(command -v git 2>/dev/null || true)
[ -n "$GIT" ] || { echo "worker-guardrails: warn — git not found, .groundwork/ not excluded in $wt" >&2; exit 0; }

excl=$("$GIT" -C "$wt" rev-parse --git-path info/exclude 2>/dev/null || echo "")
[ -n "$excl" ] || exit 0
case "$excl" in /*) : ;; *) excl="$wt/$excl" ;; esac   # rev-parse may return a relative path
mkdir -p "$(dirname "$excl")" 2>/dev/null || true
if ! grep -qxF '.groundwork/' "$excl" 2>/dev/null; then
  printf '.groundwork/\n' >> "$excl" 2>/dev/null \
    || echo "worker-guardrails: warn — could not exclude .groundwork/ in $wt" >&2
fi

# Claude worker sessions predictably create untracked .claude/ scratch in
# their cwd; exclude it the same way as .groundwork/ above so it never
# dirties the worker worktree's status (issue #129 proposal 1).
if ! grep -qxF '.claude/' "$excl" 2>/dev/null; then
  printf '.claude/\n' >> "$excl" 2>/dev/null \
    || echo "worker-guardrails: warn — could not exclude .claude/ in $wt" >&2
fi
exit 0
