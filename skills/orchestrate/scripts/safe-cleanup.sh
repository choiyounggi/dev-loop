#!/bin/sh
# safe-cleanup.sh — guarded destructive operations for loop-orchestrator.
# Every destructive step refuses unless it is provably safe. No `--force`.
#
# usage:
#   safe-cleanup.sh init-check <workdir>
#       Verify it is safe to `git init` <workdir>: refuse if it sits inside an
#       existing repo (nesting) or contains secret-like files; warn if no
#       .gitignore. (design §6)
#   safe-cleanup.sh merge [--dry-run] <repo-root> <integ-branch> <task-branch>...
#       Refuse if any worktree has uncommitted changes, then merge each task
#       branch into the integration branch sequentially; stop on conflict and
#       report merged/remaining. (design §7.2/§7.3)
#   safe-cleanup.sh remove-worktrees [--dry-run] <repo-root> <task-branch>...
#       Remove each task worktree, refusing any with uncommitted changes
#       (never --force), then `git worktree prune`. (design §7.4/§8.7)
#   safe-cleanup.sh kill-sessions [--dry-run] <session-name>...
#       Kill ONLY the exact session names given (no prefix/grep). (design §7.5/§8.9)
#   safe-cleanup.sh sweep [--dry-run] <repo-root>            [requires LO_RUN_ID]
#       Teardown for ONE run: kill every tmux session named lo-<n>-$LO_RUN_ID,
#       then `git worktree prune`, then report (never delete) any .worktrees/
#       directory git does not know about. The coordinator no longer has to
#       remember each session name.
#   safe-cleanup.sh list-orphans <repo-root>                 [read-only]
#       Enumerate orphan candidates across ALL run ids and exit. Kills nothing,
#       deletes nothing, prunes nothing. Needs no LO_RUN_ID.
#
# --dry-run may appear in any argument position on any destructive verb. It
# prints exactly what the real run would touch and changes nothing; refusals
# (dirty worktree, etc.) still fire, so a dry run never looks safer than the
# real one.
#
# LO_RUN_ID scoping (sweep only):
#   `sweep` REFUSES (exit 1, nothing touched) when LO_RUN_ID is unset or is not
#   [A-Za-z0-9_-]+ . With no scope the pattern would match every concurrent
#   run's sessions, so it fails closed rather than widening. Two coordinators on
#   one machine therefore cannot tear down each other's workers.
#   To clean up a run that already died: read its id from `list-orphans`, then
#   re-run with LO_RUN_ID=<that-id> sweep — deliberate, never automatic.
#
# list-orphans record format (tab-separated, one record per line):
#   session<TAB><name><TAB>run=<runid|none><TAB>created=<epoch>
#   worktree-stale<TAB><path><TAB>reason=gitdir-missing
#   worktree-unregistered<TAB><path>
set -eu
GIT=$(command -v git) || { echo "safe-cleanup: git not found" >&2; exit 127; }
DRY=0   # set by --dry-run in the dispatcher below; read by every destructive verb

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
  if [ "$DRY" -eq 1 ]; then
    for br in "$@"; do echo "would merge: $br -> $integ"; done
    return 0
  fi
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
    if [ "$DRY" -eq 1 ]; then echo "would remove: $wt"; continue; fi
    if "$GIT" -C "$root" worktree remove "$wt"; then
      echo "removed: $wt"
    else
      echo "remove-worktrees: FAILED to remove $wt (locked/prunable?) — left in place" >&2
    fi
  done
  # removals (and worktrees whose directory vanished on their own) leave git
  # admin files behind — clear them here rather than letting them accumulate
  prune_worktrees "$root"
  return 0
}

kill_sessions() {
  # NEVER name this variable TMUX: tmux exports $TMUX (its server socket) into
  # every session, so assigning to it here inherits the export attribute and
  # every subsequent tmux call tries to use the binary path as its socket
  # ("Socket operation on non-socket"). The orchestrator runs this script from
  # inside a tmux session, so that silently turned teardown into a no-op.
  TMUXBIN=$(command -v tmux) || { echo "kill-sessions: tmux not found" >&2; return 127; }
  [ $# -ge 1 ] || { echo "kill-sessions: need session name(s)" >&2; return 1; }
  for s in "$@"; do
    # exact target only — has-session -t matches the exact name, never a prefix/grep
    if "$TMUXBIN" has-session -t "$s" 2>/dev/null; then
      if [ "$DRY" -eq 1 ]; then
        echo "would kill: $s"
      else
        "$TMUXBIN" kill-session -t "$s" && echo "killed: $s"
      fi
    else
      echo "skip: $s (no such session)"
    fi
  done
  return 0
}

# Drop git's administrative files for worktrees whose directory is already gone.
# This is the only "worktree removal" a sweep performs: a registered, live
# worktree is never removed here — that stays an explicit `remove-worktrees`.
prune_worktrees() {
  root="${1:?prune: repo-root required}"
  # NOTE: `git worktree prune --verbose` reports on STDERR, not stdout, so the
  # capture must redirect 2>&1 or the report is lost and this looks like a no-op.
  if [ "$DRY" -eq 1 ]; then
    pout=$("$GIT" -C "$root" worktree prune --dry-run --verbose 2>&1)
  else
    pout=$("$GIT" -C "$root" worktree prune --verbose 2>&1)
  fi
  if [ -n "$pout" ]; then
    printf '%s\n' "$pout" | while IFS= read -r pl; do echo "prune: $pl"; done
  fi
  return 0
}

# Report — never delete — a .worktrees/ directory git does not know about. It
# may hold uncommitted work, so widening the sweep to delete it would make
# teardown more dangerous than the explicit verb it replaces.
report_unregistered() {
  root="${1:?report-unregistered: repo-root required}"
  [ -d "$root/.worktrees" ] || return 0
  reg=$("$GIT" -C "$root" worktree list --porcelain 2>/dev/null | awk '/^worktree /{ sub(/^worktree /, ""); print }')
  for d in "$root"/.worktrees/*; do
    [ -d "$d" ] || continue          # no matches: the glob stayed literal
    # compare physical paths — git reports realpath, the glob may carry a symlink
    dphys=$(cd "$d" 2>/dev/null && pwd -P) || continue
    printf '%s\n' "$reg" | grep -qxF "$dphys" && continue
    echo "sweep: unregistered worktree dir (not removed — may hold work): $d"
  done
  return 0
}

# Validate the run scope BEFORE any destructive sweep. LO_RUN_ID is interpolated
# into tmux -t targets and into a glob, so it is checked against a strict
# allowlist and REFUSED when absent: with no scope the pattern would match every
# concurrent run's sessions, so this fails closed rather than widening.
run_scope() {
  rid="${LO_RUN_ID:-}"
  case "$rid" in
    ''|*[!A-Za-z0-9_-]*)
      echo "sweep: REFUSE — LO_RUN_ID unset or malformed (need [A-Za-z0-9_-]+); refusing to sweep an unscoped pattern." >&2
      return 1 ;;
  esac
  return 0
}

sweep() {
  root="${1:?sweep: repo-root required}"
  run_scope || return 1
  TMUXBIN=$(command -v tmux) || { echo "sweep: tmux not found" >&2; return 127; }
  # Capture the roster BEFORE looping: `cmd | while` runs its body in a subshell
  # in POSIX sh, so the counter below would not survive the pipeline.
  roster=$("$TMUXBIN" list-sessions -F '#{session_name}' 2>/dev/null || true)
  cnt=0
  # Session names are [A-Za-z0-9_-] by construction, so default IFS splitting is safe.
  for s in $roster; do
    # whole-name match against this run only — never a bare lo-* prefix sweep
    case "$s" in
      lo-*-"$rid") : ;;
      *) continue ;;
    esac
    # ...and the segment between `lo-` and the run id must be a single field, so
    # a foreign run whose id merely ENDS with ours (lo-1-x-runA) cannot alias in.
    mid=${s#lo-}; mid=${mid%-"$rid"}
    case "$mid" in ''|*-*) continue ;; esac
    if [ "$DRY" -eq 1 ]; then
      echo "would kill: $s"
    else
      "$TMUXBIN" kill-session -t "$s" && echo "killed: $s"
    fi
    cnt=$((cnt + 1))
  done
  if [ "$DRY" -eq 1 ]; then
    echo "sweep: $cnt session(s) would be killed for run $rid"
  else
    echo "sweep: $cnt session(s) killed for run $rid"
  fi
  prune_worktrees "$root"
  report_unregistered "$root"
  return 0
}

# Read-only enumeration of orphan candidates. Deliberately NOT scoped to
# LO_RUN_ID: a run that died mid-flight took its id with it, so scoping the
# listing would hide exactly the leaks worth finding. Removal stays scoped
# (`sweep`), so discovery is cheap and destruction stays deliberate.
list_orphans() {
  root="${1:?list-orphans: repo-root required}"
  TMUXBIN=$(command -v tmux 2>/dev/null) || TMUXBIN=""
  if [ -n "$TMUXBIN" ]; then
    roster=$("$TMUXBIN" list-sessions -F '#{session_name} #{session_created}' 2>/dev/null || true)
    printf '%s\n' "$roster" | while IFS= read -r line; do
      [ -n "$line" ] || continue
      name=${line%% *}
      created=${line#* }
      [ "$created" = "$line" ] && created=unknown
      # trailing field after the last '-' is the run id; a name without one
      # (e.g. a hand-made `lo-test`) is reported as run=none, never dropped
      case "$name" in
        lo-*-*) rid=${name##*-} ;;
        *) rid=none ;;
      esac
      printf 'session\t%s\trun=%s\tcreated=%s\n' "$name" "$rid" "$created"
    done
  else
    # enumeration is informational — a missing tmux must not fail the command
    echo "list-orphans: tmux not found — session enumeration skipped" >&2
  fi

  reg=$("$GIT" -C "$root" worktree list --porcelain 2>/dev/null | awk '/^worktree /{ sub(/^worktree /, ""); print }') || reg=""
  printf '%s\n' "$reg" | while IFS= read -r w; do
    [ -n "$w" ] || continue
    [ -d "$w" ] || printf 'worktree-stale\t%s\treason=gitdir-missing\n' "$w"
  done

  if [ -d "$root/.worktrees" ]; then
    for d in "$root"/.worktrees/*; do
      [ -d "$d" ] || continue
      dphys=$(cd "$d" 2>/dev/null && pwd -P) || continue
      printf '%s\n' "$reg" | grep -qxF "$dphys" && continue
      printf 'worktree-unregistered\t%s\n' "$d"
    done
  fi
  return 0
}

cmd="${1:-}"; [ $# -ge 1 ] && shift || true

# Strip --dry-run from ANY position, then hand the remaining operands to the
# verb. This rotates each argument through "$@", which preserves order and
# arguments containing spaces without arrays (POSIX sh has none) and without
# eval. It must stay INLINE: `set --` inside a function rebinds only that
# function's positional parameters, so a helper would discard the rebuilt list.
n=$#
while [ "$n" -gt 0 ]; do
  a="$1"; shift
  case "$a" in
    --dry-run) DRY=1 ;;
    *) set -- "$@" "$a" ;;
  esac
  n=$((n - 1))
done

case "$cmd" in
  init-check)      init_check "$@" ;;
  merge)           merge "$@" ;;
  remove-worktrees) remove_worktrees "$@" ;;
  kill-sessions)   kill_sessions "$@" ;;
  sweep)           sweep "$@" ;;
  list-orphans)    list_orphans "$@" ;;
  *) echo "usage: safe-cleanup.sh {init-check <workdir>|merge [--dry-run] <root> <integ> <branch>...|remove-worktrees [--dry-run] <root> <branch>...|kill-sessions [--dry-run] <session>...|sweep [--dry-run] <root>|list-orphans <root>}" >&2; exit 1 ;;
esac
