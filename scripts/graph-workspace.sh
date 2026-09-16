#!/bin/sh
# graph-workspace.sh — enumerate the git repos under one or more workspace roots
# and report each repo's graphify graph freshness + dev-loop hook status.
#
# usage: graph-workspace.sh --list   [--depth N] [--exclude GLOB]... [--] <root>...
#        graph-workspace.sh --status [--depth N] [--exclude GLOB]... [--] <root>...
#
# A repo is a directory whose `.git` is a DIRECTORY found by
#   find -P <root> -maxdepth <depth> -type d -name .git      (default depth 2)
# so git worktrees (`.git` file), bare repos, and paths reachable only through a
# symlink are never listed. `--exclude GLOB` drops a repo when any path component
# under <root> matches GLOB (shell case pattern).
#
# --list   stdout: one repo path per line (sorted)            exit 0
# --status stdout: one line per repo (sorted), tab-separated:
#            <repo-path>\t<freshness>\thooks: <hooks>
#          <freshness> is scripts/graph-freshness.sh's stdout verbatim:
#            fresh | stale <N> | absent | cannot-evaluate <reason>
#          <hooks> is scripts/graph-hooks.sh status's stdout verbatim:
#            ok | partial | none | cannot-evaluate <reason>
#          exit: the maximum over repos of the freshness exit codes
#            0 all fresh | 2 a stale repo | 3 an absent graph | 4 cannot-evaluate
#          (hook status never changes the exit code)
# Both verbs:
#   no repo under any root       stdout `no-repos`                     exit 0
#   a root is not a directory    stdout `cannot-evaluate missing-root` exit 4
#   bad flags / no verb / no root stdout `cannot-evaluate usage`       exit 4
#   an unreadable directory      one stderr line `skip: unreadable <dir>`, skipped
# Never runs graphify; never writes anything. GRAPHIFY_BIN passes through to
# graph-freshness.sh. Roots are explicit operands — this script never reads
# tools.json (the caller resolves the workspace config).
# contract: t6-graph-scripts owns the implementation
set -eu

NL='
'

usage_fail() {
  printf 'usage: graph-workspace.sh --list|--status [--depth N] [--exclude GLOB]... [--] <root>...\n' >&2
  printf 'cannot-evaluate usage\n'
  exit 4
}

VERB=""
DEPTH=2
EXCLUDES=""

n=$#
while [ "$n" -gt 0 ]; do
  a="$1"; shift; n=$((n - 1))
  case "$a" in
    --list)
      [ -z "$VERB" ] || usage_fail
      VERB=list
      ;;
    --status)
      [ -z "$VERB" ] || usage_fail
      VERB=status
      ;;
    --depth)
      [ "$n" -ge 1 ] || usage_fail
      DEPTH="$1"; shift; n=$((n - 1))
      ;;
    --exclude)
      [ "$n" -ge 1 ] || usage_fail
      EXCLUDES="${EXCLUDES}${EXCLUDES:+$NL}$1"; shift; n=$((n - 1))
      ;;
    --)
      while [ "$n" -gt 0 ]; do
        set -- "$@" "$1"; shift; n=$((n - 1))
      done
      ;;
    -*)
      usage_fail
      ;;
    *)
      set -- "$@" "$a"
      ;;
  esac
done

[ -n "$VERB" ] || usage_fail
[ "$#" -ge 1 ] || usage_fail
case "$DEPTH" in
  ''|*[!0-9]*) usage_fail ;;
esac
[ "$DEPTH" -ge 1 ] || usage_fail

HERE=$(cd "$(dirname "$0")" && pwd -P)
FRESH="$HERE/graph-freshness.sh"
HOOKS="$HERE/graph-hooks.sh"

# Every root must exist before any repo output is produced.
for root in "$@"; do
  [ -d "$root" ] || {
    printf 'cannot-evaluate missing-root\n'
    printf 'missing root: %s\n' "$root" >&2
    exit 4
  }
done

# match_excluded RELPATH — true when any '/'-separated component of RELPATH
# matches one of the newline-separated $EXCLUDES glob patterns.
match_excluded() {
  rp="$1"
  [ -n "$EXCLUDES" ] || return 1
  while [ -n "$rp" ]; do
    case "$rp" in
      */*) comp="${rp%%/*}"; rp="${rp#*/}" ;;
      *) comp="$rp"; rp="" ;;
    esac
    oldIFS="$IFS"
    IFS="$NL"
    for pat in $EXCLUDES; do
      IFS="$oldIFS"
      case "$comp" in
        $pat) return 0 ;;
      esac
      IFS="$NL"
    done
    IFS="$oldIFS"
  done
  return 1
}

errf=$(mktemp)
trap 'rm -f "$errf"' EXIT

repos=""
for root in "$@"; do
  root_abs=$(cd "$root" && pwd -P)
  : > "$errf"
  gitdirs=$(find -P "$root_abs" -maxdepth "$DEPTH" -type d -name .git 2>"$errf") || true
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      *'Permission denied')
        p=$(printf '%s\n' "$line" | sed -e "s/^find: //" -e "s/: Permission denied$//" -e "s/^'//" -e "s/'\$//")
        printf 'skip: unreadable %s\n' "$p" >&2
        ;;
    esac
  done < "$errf"
  [ -n "$gitdirs" ] || continue
  while IFS= read -r gitdir; do
    [ -n "$gitdir" ] || continue
    repo=$(dirname "$gitdir")
    case "$repo" in
      "$root_abs") rel="" ;;
      "$root_abs"/*) rel="${repo#"$root_abs"/}" ;;
      *) rel="" ;;
    esac
    if [ -n "$rel" ] && match_excluded "$rel"; then
      continue
    fi
    repos="${repos}${repos:+$NL}$repo"
  done <<GITDIRS
$gitdirs
GITDIRS
done

repos=$(printf '%s\n' "$repos" | sed '/^$/d' | sort -u)

if [ -z "$repos" ]; then
  printf 'no-repos\n'
  exit 0
fi

if [ "$VERB" = list ]; then
  printf '%s\n' "$repos"
  exit 0
fi

worst=0
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  if f=$("$FRESH" "$repo" 2>/dev/null); then fr=0; else fr=$?; fi
  if h=$("$HOOKS" status "$repo" 2>/dev/null); then hr=0; else hr=$?; fi
  : "$hr" # hook status never changes the exit code
  printf '%s\t%s\thooks: %s\n' "$repo" "$f" "$h"
  if [ "$fr" -gt "$worst" ]; then worst="$fr"; fi
done <<REPOS
$repos
REPOS

exit "$worst"
