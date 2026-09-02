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
#   safe-cleanup.sh teardown [--dry-run] <repo-root>         [requires LO_RUN_ID]
#       Atomic, idempotent, run-scoped end-of-run cleanup: derive this run's
#       worktrees from its own .orchestration/status/*.json records, remove
#       them, sweep its sessions, then archive .orchestration/* (except prior
#       archive-* dirs) into archive-<YYYYMMDD>-<runid>/. Requires jq. A
#       re-run with nothing left to do is a no-op (exit 0).
#   safe-cleanup.sh list-orphans [--stale] <repo-root>        [read-only]
#       Enumerate orphan candidates across ALL run ids and exit. Kills nothing,
#       deletes nothing, prunes nothing. Needs no LO_RUN_ID. With --stale,
#       annotates each session record with stale=yes|no|unknown, derived from
#       that run's own status records (requires jq; without it, warns and
#       reports unknown for all). Without --stale, output is unchanged.
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
#   session<TAB><name><TAB>run=<runid|none><TAB>created=<epoch>[<TAB>stale=<yes|no|unknown>]
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
    # `|| status_out=""` matters under `set -eu`: this is a bare top-level
    # assignment (unlike the old `[ -n "$(...)" ]` form, where a substitution
    # failure inside `[ ]` was immune to set -e), so a $wt that exists but has
    # a stale/broken gitdir link (git fails, nonzero exit) would otherwise
    # abort the WHOLE script here instead of degrading to "treat as clean,
    # let `git worktree remove` below report FAILED and move on".
    status_out=$("$GIT" -C "$wt" status --porcelain 2>/dev/null) || status_out=""
    if [ -n "$status_out" ]; then
      # Classify: any line NOT starting with `??` is tracked dirt (staged or
      # modified); lines that are ALL `??` are untracked-only (e.g. worker
      # scratch). Split on newline only (IFS) so a path containing spaces
      # stays one element — reassigning "$@" here is safe: the enclosing
      # `for br in "$@"` already snapshotted its own iteration list above.
      oldifs=$IFS; IFS='
'
      set -- $status_out
      IFS=$oldifs
      tracked=0; upaths=""; ucount=0
      for pline in "$@"; do
        case "$pline" in
          '??'*)
            ucount=$((ucount + 1))
            [ "$ucount" -le 3 ] && upaths="${upaths:+$upaths }${pline#???}"
            ;;
          *) tracked=1 ;;
        esac
      done
      if [ "$tracked" -eq 1 ]; then
        echo "remove-worktrees: SKIP — uncommitted changes in $wt (dirt=modified; never --force)." >&2
      else
        echo "remove-worktrees: SKIP — uncommitted changes in $wt (untracked-only: $upaths; never --force)." >&2
      fi
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
# $1: the calling verb's name, for the REFUSE message (default sweep, so
# sweep's own REFUSE output is unchanged for callers that pass nothing).
run_scope() {
  verb="${1:-sweep}"
  rid="${LO_RUN_ID:-}"
  case "$rid" in
    ''|*[!A-Za-z0-9_-]*)
      echo "$verb: REFUSE — LO_RUN_ID unset or malformed (need [A-Za-z0-9_-]+); refusing to $verb an unscoped pattern." >&2
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

# Scratch that is intentionally excluded on purpose (info/exclude, e.g. the
# .claude/ worker-guardrails.sh excludes) and so is NOT covered by
# --exclude-standard's ignore-aware enumeration below — archived separately,
# dir-level. Space-separated if this ever grows beyond one entry.
SCRATCH_WHITELIST=".claude"

# Archive one worktree's untracked scratch into this run's dated archive dir,
# then delete exactly what was archived from the worktree, pruning
# directories left empty by that deletion. Tracked files are never touched
# here.
#
# Enumeration is `ls-files --others --exclude-standard` (untracked AND not
# ignored), so gitignored dependency trees (node_modules/, target/, dist/...)
# are never swept into the archive — the prior WITHOUT-exclude-standard
# enumeration is what caused issue #170's 512MB/12,519-file teardown hang.
#
# Scratch that IS ignored on purpose is not caught by that enumeration, so
# each SCRATCH_WHITELIST entry is archived separately, dir-level (cp -Rp),
# but ONLY when `git check-ignore` confirms it is actually ignored —
# otherwise it is untracked-and-not-ignored, already covered by the
# enumeration above, and a whitelist copy would double-archive it.
#
# Copy-before-delete: a mkdir/cp failure aborts this worktree's archive
# (whitelist dirs first, then the per-file loop) without deleting anything,
# so the caller's remove_worktrees below still SKIPs it as dirty rather than
# half-deleting.
# $1: worktree path  $2: this branch's worker-scratch destination dir
archive_scratch() {
  wt="$1"; adest="$2"

  for w in $SCRATCH_WHITELIST; do
    [ -e "$wt/$w" ] || continue
    "$GIT" -C "$wt" check-ignore -q "$w" || continue
    if [ "$DRY" -eq 1 ]; then
      find "$wt/$w" -type f 2>/dev/null | while IFS= read -r wf; do
        echo "would archive: $wf"
      done
      continue
    fi
    if ! mkdir -p "$adest" || ! cp -Rp "$wt/$w" "$adest/$w"; then
      echo "teardown: FAILED to archive $wt/$w — worktree left in place" >&2
      return 1
    fi
    rm -rf "$wt/$w"
  done

  files=$("$GIT" -C "$wt" ls-files --others --exclude-standard 2>/dev/null) || return 0
  [ -n "$files" ] || return 0
  oldifs=$IFS; IFS='
'
  set -- $files
  IFS=$oldifs
  if [ "$DRY" -eq 1 ]; then
    for f in "$@"; do echo "would archive: $wt/$f"; done
    return 0
  fi
  for f in "$@"; do
    src="$wt/$f"
    [ -f "$src" ] || continue
    tgt="$adest/$f"
    if ! mkdir -p "$(dirname "$tgt")" || ! cp -p "$src" "$tgt"; then
      echo "teardown: FAILED to archive $src — worktree left in place" >&2
      return 1
    fi
    rm -f "$src"
    d=$(dirname "$src")
    while [ "$d" != "$wt" ] && [ -d "$d" ]; do
      rmdir "$d" 2>/dev/null || break
      d=$(dirname "$d")
    done
  done
  return 0
}

# Atomic, idempotent, run-scoped end-of-run teardown: derive (from THIS run's
# own status records) -> archive worker scratch -> remove_worktrees -> sweep
# -> archive. Archive runs last because derivation and sweep both still need
# the status files in place.
teardown() {
  root="${1:?teardown: repo-root required}"
  run_scope teardown || return 1
  JQ=$(command -v jq) || { echo "teardown: jq not found" >&2; return 127; }

  adir="$root/.orchestration"
  dest="$adir/archive-$(date +%Y%m%d)-$rid"

  # Derive this run's worktree branches from its own status/*.json records
  # only — NEVER a bare .worktrees/* glob, which would cross into concurrent
  # runs' worktrees.
  branches=""
  sdir="$root/.orchestration/status"
  if [ -d "$sdir" ]; then
    for f in "$sdir"/*.json; do
      [ -f "$f" ] || continue
      sess=$("$JQ" -r '.session // empty' "$f" 2>/dev/null) || continue
      case "$sess" in
        lo-*-"$rid") : ;;
        *) continue ;;
      esac
      # same single-field boundary rule as sweep's own match, so a foreign run
      # whose id merely ends with ours can never alias into this run's derive.
      mid=${sess#lo-}; mid=${mid%-"$rid"}
      case "$mid" in ''|*-*) continue ;; esac
      wt=$("$JQ" -r '.worktree // empty' "$f" 2>/dev/null) || continue
      [ -n "$wt" ] || continue
      [ -d "$wt" ] || continue
      br=$("$GIT" -C "$wt" branch --show-current 2>/dev/null) || continue
      [ -n "$br" ] || continue
      branches="$branches
$br"
    done
  fi
  # no status files or no worktrees -> proceed silently (idempotent)
  if [ -n "$branches" ]; then
    # Archive each branch's untracked scratch BEFORE removal — including
    # info/exclude-excluded scratch like .claude/ — so a worktree whose only
    # dirt is scratch ends up clean and gets removed below instead of
    # SKIPped; tracked modifications are untouched here and still make
    # remove_worktrees SKIP exactly as before.
    for br in $branches; do
      safe=$(printf '%s' "$br" | tr '/' '-'); wt="$root/.worktrees/$safe"
      [ -d "$wt" ] || continue
      archive_scratch "$wt" "$dest/worker-scratch/$safe" \
        || echo "teardown: scratch archive failed for $wt — left in place, will SKIP as dirty" >&2
    done
    # deliberately unquoted: word-split the newline-joined list into separate
    # operands (POSIX sh has no arrays); safe because git ref names cannot
    # contain whitespace, so no branch here can be split mid-name.
    remove_worktrees "$root" $branches
  fi
  sweep "$root"

  # Archive everything remaining under .orchestration/ except prior archive-*
  # dirs into the same dated, run-scoped destination used for worker scratch
  # above. mkdir -p makes a re-run reuse the same destination instead of
  # failing.
  moved=0
  if [ -d "$adir" ]; then
    for e in "$adir"/*; do
      [ -e "$e" ] || continue
      base=$(basename "$e")
      case "$base" in archive-*) continue ;; esac
      if [ "$DRY" -eq 1 ]; then
        echo "would archive: $e"
      else
        mkdir -p "$dest"
        mv "$e" "$dest/"
        echo "archived: $e"
      fi
      moved=$((moved + 1))
    done
  fi
  [ "$moved" -eq 0 ] && echo "teardown: nothing to archive"
  return 0
}

# Classify one run id's staleness from ITS OWN status records, for
# `list-orphans --stale`: yes = every matching record's phase is terminal
# (done|failed); no = at least one is not; unknown = no matching records at
# all (archived away, or a hand-made session with no run id) — unknown is
# positive absence-of-evidence, not a sweep recommendation. Caches verdicts in
# $STALE_CACHE across calls within one list_orphans run (POSIX sh has no maps).
_stale_for_rid() {
  qrid="$1"; qroot="$2"
  [ "$qrid" = "none" ] && { echo unknown; return 0; }
  [ -n "$SJQ" ] || { echo unknown; return 0; }
  case "$STALE_CACHE" in
    *" $qrid=yes "*)     echo yes;     return 0 ;;
    *" $qrid=no "*)      echo no;      return 0 ;;
    *" $qrid=unknown "*) echo unknown; return 0 ;;
  esac
  found=0; nonterm=0
  qsdir="$qroot/.orchestration/status"
  if [ -d "$qsdir" ]; then
    for sf in "$qsdir"/*.json; do
      [ -f "$sf" ] || continue
      s=$("$SJQ" -r '.session // empty' "$sf" 2>/dev/null) || continue
      case "$s" in
        *-"$qrid") : ;;
        *) continue ;;
      esac
      found=1
      p=$("$SJQ" -r '.phase // empty' "$sf" 2>/dev/null) || continue
      case "$p" in
        done|failed) : ;;
        *) nonterm=1 ;;
      esac
    done
  fi
  if [ "$found" -eq 0 ]; then verdict=unknown
  elif [ "$nonterm" -eq 1 ]; then verdict=no
  else verdict=yes
  fi
  STALE_CACHE="$STALE_CACHE $qrid=$verdict "
  echo "$verdict"
}

# Read-only enumeration of orphan candidates. Deliberately NOT scoped to
# LO_RUN_ID: a run that died mid-flight took its id with it, so scoping the
# listing would hide exactly the leaks worth finding. Removal stays scoped
# (`sweep`), so discovery is cheap and destruction stays deliberate.
list_orphans() {
  # Parse --stale in any position; self-contained since this function is the
  # terminal consumer of its own "$@" (no caller relies on it afterward).
  STALE=0
  n=$#
  while [ "$n" -gt 0 ]; do
    a="$1"; shift
    case "$a" in
      --stale) STALE=1 ;;
      *) set -- "$@" "$a" ;;
    esac
    n=$((n - 1))
  done
  root="${1:?list-orphans: repo-root required}"

  SJQ=""
  if [ "$STALE" -eq 1 ]; then
    SJQ=$(command -v jq 2>/dev/null) || echo "list-orphans: jq not found — --stale reporting unknown for all" >&2
  fi
  STALE_CACHE=""

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
      if [ "$STALE" -eq 1 ]; then
        stale=$(_stale_for_rid "$rid" "$root")
        printf 'session\t%s\trun=%s\tcreated=%s\tstale=%s\n' "$name" "$rid" "$created" "$stale"
      else
        printf 'session\t%s\trun=%s\tcreated=%s\n' "$name" "$rid" "$created"
      fi
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
  teardown)        teardown "$@" ;;
  list-orphans)    list_orphans "$@" ;;
  *) echo "usage: safe-cleanup.sh {init-check <workdir>|merge [--dry-run] <root> <integ> <branch>...|remove-worktrees [--dry-run] <root> <branch>...|kill-sessions [--dry-run] <session>...|sweep [--dry-run] <root>|teardown [--dry-run] <root>|list-orphans [--stale] <root>}" >&2; exit 1 ;;
esac
