#!/bin/sh
# setup-worktrees.sh — create an integration branch + one worktree per task.
# Dependency installs run separately (in the background). Ends with a real
# `git worktree list` so callers verify actual state rather than trusting
# echo logs (set -e is fail-open inside some eval subshells).
#
# usage: setup-worktrees.sh <integration-branch> <repo-root> <base-ref> <task-branch>...
#   <integration-branch>  integration (feature) branch name, e.g. feat/my-goal
#   <repo-root>           absolute path to the main worktree
#   <base-ref>            ref to branch the integration branch from, e.g. origin/main
#   <task-branch>...      per-task branch names
set -eu
GIT=$(command -v git) || { echo "setup-worktrees: git not found" >&2; exit 127; }

# Resolve our own directory to an ABSOLUTE path before the `cd "$root"` below:
# `$0` may be relative to the invocation cwd, and after the cd a relative
# `$(dirname "$0")/worker-guardrails.sh` resolves against the repo root instead
# — the sibling script is then not found and set -e aborts mid-provision.
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P) \
  || { echo "setup-worktrees: cannot resolve script directory from '$0'" >&2; exit 1; }

[ $# -ge 4 ] || { echo "usage: setup-worktrees.sh <integ-branch> <repo-root> <base-ref> <task-branch>..." >&2; exit 1; }
integ="$1"; root="$2"; base="$3"; shift 3

cd "$root"
if ! "$GIT" fetch origin --quiet 2>/dev/null; then
  echo "setup-worktrees: fetch failed — using local refs; if base '$base' is a remote-tracking ref it may be stale" >&2
fi

# 1) integration branch (branch only; keep the main worktree's current branch)
if "$GIT" show-ref --verify --quiet "refs/heads/$integ"; then
  echo "-> $integ already exists"
else
  "$GIT" branch "$integ" "$base"
  echo "ok: $integ (from $base)"
fi

# 2) per-task worktrees (based on the integration branch)
for br in "$@"; do
  safe=$(printf '%s' "$br" | tr '/' '-')
  path="$root/.worktrees/$safe"
  if "$GIT" show-ref --verify --quiet "refs/heads/$br"; then
    [ -d "$path" ] || "$GIT" worktree add "$path" "$br"
    if "$GIT" merge-base --is-ancestor "$integ" "$br" 2>/dev/null; then
      echo "-> $br exists — worktree ensured"
    else
      echo "-> $br exists but is NOT based on $integ (possibly stale from a previous run) — verify before relying on it" >&2
    fi
  else
    "$GIT" worktree add -b "$br" "$path" "$integ"
    echo "ok: worktree $path ($br)"
  fi
  # Scope guardrails inside this worktree (single source: worker-guardrails.sh —
  # the Orca substrate calls the same script for an orca-created worktree).
  sh "$SCRIPT_DIR/worker-guardrails.sh" "$path"
  # optional env copy if the project provides one (e.g. monorepos)
  if [ -f "$root/scripts/worktree-copy-env.sh" ]; then
    sh "$root/scripts/worktree-copy-env.sh" "$path" >/dev/null 2>&1 \
      && echo "  env copied" || echo "  warn: env copy skipped" >&2
  fi
done

echo "=== VERIFY ==="
"$GIT" worktree list
