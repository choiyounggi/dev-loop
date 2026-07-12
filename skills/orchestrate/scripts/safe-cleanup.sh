#!/bin/sh
# safe-cleanup.sh — guarded destructive operations for loop-orchestrator.
# Every destructive step refuses unless it is provably safe. No `--force`.
#
# usage:
#   safe-cleanup.sh init-check <workdir>
#       Verify it is safe to `git init` <workdir>: refuse if it sits inside an
#       existing repo (nesting) or contains secret-like files; warn if no
#       .gitignore. (design §6)
#   safe-cleanup.sh merge <repo-root> <integ-branch> <task-branch>...
#       Refuse if any worktree has uncommitted changes, then merge each task
#       branch into the integration branch sequentially; stop on conflict and
#       report merged/remaining. (design §7.2/§7.3)
#   safe-cleanup.sh remove-worktrees <repo-root> <task-branch>...
#       Remove each task worktree, refusing any with uncommitted changes
#       (never --force). (design §7.4/§8.7)
#   safe-cleanup.sh kill-sessions <session-name>...
#       Kill ONLY the exact session names given (no prefix/grep). (design §7.5/§8.9)
set -eu
GIT=$(command -v git) || { echo "safe-cleanup: git not found" >&2; exit 127; }

init_check() {
  wd="${1:?init-check: workdir required}"
  [ -d "$wd" ] || { echo "init-check: '$wd' is not a directory" >&2; return 1; }
  parent=$(dirname "$wd")
  if "$GIT" -C "$parent" rev-parse --show-toplevel >/dev/null 2>&1; then
    top=$("$GIT" -C "$parent" rev-parse --show-toplevel 2>/dev/null)
    echo "init-check: REFUSE — '$wd' is inside an existing git repo ($top); git init would nest." >&2
    return 1
  fi
  # best-effort secret scan (not exhaustive — deeper or oddly-named secrets may pass)
  if find "$wd" -maxdepth 4 \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -iname '*credential*' \) 2>/dev/null | grep -q .; then
    echo "init-check: REFUSE — secret-like files present (.env / .env.* / *.pem / *credential*). Add them to .gitignore before init." >&2
    return 1
  fi
  [ -f "$wd/.gitignore" ] || echo "init-check: WARN — no .gitignore; add ignores (node_modules, .env*, build, .orchestration/) before committing." >&2
  echo "init-check: ok"
  return 0
}

merge() {
  root="${1:?merge: repo-root required}"; integ="${2:?merge: integ-branch required}"; shift 2
  [ $# -ge 1 ] || { echo "merge: need at least one task-branch" >&2; return 1; }
  # 1) precheck — refuse if any worktree is dirty (design §7.2)
  for br in "$@"; do
    safe=$(printf '%s' "$br" | tr '/' '-'); wt="$root/.worktrees/$safe"
    [ -d "$wt" ] || continue
    if [ -n "$("$GIT" -C "$wt" status --porcelain 2>/dev/null)" ]; then
      echo "merge: REFUSE — uncommitted changes in $wt ($br). Commit or discard first." >&2
      return 1
    fi
  done
  # 2) sequential merge; stop on conflict, record state (design §7.3)
  "$GIT" -C "$root" checkout "$integ" >/dev/null 2>&1 || { echo "merge: cannot checkout $integ" >&2; return 1; }
  merged=""
  for br in "$@"; do
    if "$GIT" -C "$root" merge --no-ff -m "merge: $br into $integ" "$br" >/dev/null 2>&1; then
      merged="$merged $br"
    else
      "$GIT" -C "$root" merge --abort >/dev/null 2>&1 || true
      echo "merge: CONFLICT on $br — aborted. merged=[$merged ] remaining starts at [$br]. Resolve manually, then re-run." >&2
      return 2
    fi
  done
  echo "merge: ok — merged$merged into $integ"
  return 0
}

remove_worktrees() {
  root="${1:?remove-worktrees: repo-root required}"; shift
  [ $# -ge 1 ] || { echo "remove-worktrees: need task-branch(es)" >&2; return 1; }
  for br in "$@"; do
    safe=$(printf '%s' "$br" | tr '/' '-'); wt="$root/.worktrees/$safe"
    [ -d "$wt" ] || continue
    if [ -n "$("$GIT" -C "$wt" status --porcelain 2>/dev/null)" ]; then
      echo "remove-worktrees: SKIP — uncommitted changes in $wt (never --force)." >&2
      continue
    fi
    if "$GIT" -C "$root" worktree remove "$wt"; then
      echo "removed: $wt"
    else
      echo "remove-worktrees: FAILED to remove $wt (locked/prunable?) — left in place" >&2
    fi
  done
  return 0
}

kill_sessions() {
  TMUX=$(command -v tmux) || { echo "kill-sessions: tmux not found" >&2; return 127; }
  [ $# -ge 1 ] || { echo "kill-sessions: need session name(s)" >&2; return 1; }
  for s in "$@"; do
    # exact target only — has-session -t matches the exact name, never a prefix/grep
    if "$TMUX" has-session -t "$s" 2>/dev/null; then
      "$TMUX" kill-session -t "$s" && echo "killed: $s"
    else
      echo "skip: $s (no such session)"
    fi
  done
  return 0
}

cmd="${1:-}"; [ $# -ge 1 ] && shift || true
case "$cmd" in
  init-check)      init_check "$@" ;;
  merge)           merge "$@" ;;
  remove-worktrees) remove_worktrees "$@" ;;
  kill-sessions)   kill_sessions "$@" ;;
  *) echo "usage: safe-cleanup.sh {init-check <workdir>|merge <root> <integ> <branch>...|remove-worktrees <root> <branch>...|kill-sessions <session>...}" >&2; exit 1 ;;
esac
