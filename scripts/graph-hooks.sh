#!/bin/sh
# graph-hooks.sh — install / uninstall / status of dev-loop's marker-delimited
# post-merge hook (templates/graph-post-merge.sh) in ONE git repo.
#
# usage: graph-hooks.sh install   <repo>
#        graph-hooks.sh uninstall <repo>
#        graph-hooks.sh status    <repo>
#
# The hook file is `$(git -C <repo> rev-parse --git-path hooks)/post-merge` —
# the directory git will actually run. When that directory lies outside the
# repo's own `--git-common-dir` (a core.hooksPath override) every verb refuses:
#   stdout `cannot-evaluate hooks-path-override`  exit 4  (nothing written)
# The block is delimited by the exact lines
#   # dev-loop-graph-merge-start
#   # dev-loop-graph-merge-end
#
# install   absent file  -> create `#!/bin/sh` + block, chmod 755   stdout `installed <path>`         exit 0
#           foreign file -> append a blank line + block (never overwrite) stdout `installed <path>`   exit 0
#           block present -> no change                              stdout `already-installed <path>` exit 0
#           also appends the line `graphify-out/` to `$(git rev-parse --git-path info/exclude)`
#           once (creating the file if needed); never touches .gitignore
# uninstall block present -> remove start..end inclusive, keep foreign content,
#           delete the file when only `#!/bin/sh` (or nothing) remains        stdout `uninstalled <path>` exit 0
#           block absent  -> no change                              stdout `not-installed`           exit 0
# status    stdout `ok`      exit 0  graphify post-commit (`# graphify-hook-start`) AND
#                                    graphify post-checkout (`# graphify-checkout-hook-start`) AND
#                                    dev-loop post-merge block all present
#           stdout `partial` exit 2  any proper subset (a broken dev-loop block is `cannot-evaluate broken-marker` exit 4, see Every verb below)
#           stdout `none`    exit 3  none of the three
# Every verb:
#   <repo> is not a git work tree           stdout `cannot-evaluate not-git`        exit 4
#   start marker without its end marker     stdout `cannot-evaluate broken-marker`  exit 4 (install/uninstall write nothing)
#   bad verb / missing operand              stdout `cannot-evaluate usage`          exit 4
# Never runs graphify. Never installs graphify's own hooks (the onboarding skill
# runs `graphify hook install` itself). Never called from a SessionStart hook.
# contract: t6-graph-scripts owns the implementation
set -eu

usage_fail() {
  printf 'usage: graph-hooks.sh install|uninstall|status <repo>\n' >&2
  printf 'cannot-evaluate usage\n'
  exit 4
}

[ $# -eq 2 ] || usage_fail
verb="$1"
repo="$2"
case "$verb" in
  install|uninstall|status) ;;
  *) usage_fail ;;
esac

HERE=$(cd "$(dirname "$0")" && pwd -P)
TEMPLATE="$HERE/../templates/graph-post-merge.sh"

git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  printf 'cannot-evaluate not-git\n'
  exit 4
}

# normalize_abs PATH BASE — resolve PATH to an absolute path against BASE
# (used when PATH is relative), canonicalizing through the filesystem when
# the target directory exists and falling back to string-join otherwise
# (a core.hooksPath override may name a directory that does not exist yet).
normalize_abs() {
  p="$1"; base="$2"
  case "$p" in
    /*) : ;;
    *) p="$base/$p" ;;
  esac
  if [ -d "$p" ]; then
    (cd "$p" && pwd -P)
  else
    d=$(dirname "$p"); b=$(basename "$p")
    if [ -d "$d" ]; then
      printf '%s/%s\n' "$(cd "$d" && pwd -P)" "$b"
    else
      printf '%s\n' "$p"
    fi
  fi
}

repo_abs=$(cd "$repo" && pwd -P)
hooks_dir_raw=$(git -C "$repo" rev-parse --git-path hooks)
hooks_dir=$(normalize_abs "$hooks_dir_raw" "$repo_abs")
common_raw=$(git -C "$repo" rev-parse --git-common-dir)
common=$(normalize_abs "$common_raw" "$repo_abs")

case "$hooks_dir" in
  "$common") : ;;
  "$common"/*) : ;;
  *)
    printf 'cannot-evaluate hooks-path-override\n'
    printf 'hooks dir outside git-common-dir: %s\n' "$hooks_dir" >&2
    exit 4
    ;;
esac

hook="$hooks_dir/post-merge"

if [ -f "$hook" ]; then
  starts=$(grep -c '^# dev-loop-graph-merge-start$' "$hook" 2>/dev/null || true)
  ends=$(grep -c '^# dev-loop-graph-merge-end$' "$hook" 2>/dev/null || true)
else
  starts=0
  ends=0
fi

case "$verb" in
  install)
    if [ "$starts" -ne "$ends" ]; then
      printf 'cannot-evaluate broken-marker\n'
      exit 4
    fi
    if [ "$starts" -eq 1 ]; then
      echo_status="already-installed"
    else
      mkdir -p "$hooks_dir"
      if [ ! -f "$hook" ]; then
        printf '#!/bin/sh\n' > "$hook"
        chmod 755 "$hook"
      else
        printf '\n' >> "$hook"
      fi
      cat "$TEMPLATE" >> "$hook"
      echo_status="installed"
    fi
    ex_raw=$(git -C "$repo" rev-parse --git-path info/exclude)
    ex=$(normalize_abs "$ex_raw" "$repo_abs")
    mkdir -p "$(dirname "$ex")"
    grep -qx 'graphify-out/' "$ex" 2>/dev/null || printf 'graphify-out/\n' >> "$ex"
    printf '%s %s\n' "$echo_status" "$hook"
    exit 0
    ;;
  uninstall)
    if [ "$starts" -ne "$ends" ]; then
      printf 'cannot-evaluate broken-marker\n'
      exit 4
    fi
    if [ "$starts" -eq 0 ]; then
      printf 'not-installed\n'
      exit 0
    fi
    tmp="$hook.tmp"
    awk '/^# dev-loop-graph-merge-start$/{skip=1} !skip{print} /^# dev-loop-graph-merge-end$/{skip=0}' "$hook" > "$tmp"
    remainder=$(grep -v '^[[:space:]]*$' "$tmp" 2>/dev/null || true)
    if [ -z "$remainder" ] || [ "$remainder" = "#!/bin/sh" ]; then
      rm -f "$hook" "$tmp"
    else
      cat "$tmp" > "$hook"
      rm -f "$tmp"
    fi
    printf 'uninstalled %s\n' "$hook"
    exit 0
    ;;
  status)
    if [ "$starts" -ne "$ends" ]; then
      printf 'cannot-evaluate broken-marker\n'
      exit 4
    fi
    pc=0
    if [ -f "$hooks_dir/post-commit" ] && grep -q '^# graphify-hook-start$' "$hooks_dir/post-commit" 2>/dev/null; then
      pc=1
    fi
    pco=0
    if [ -f "$hooks_dir/post-checkout" ] && grep -q '^# graphify-checkout-hook-start$' "$hooks_dir/post-checkout" 2>/dev/null; then
      pco=1
    fi
    pm=0
    if [ "$starts" -eq 1 ] && [ "$ends" -eq 1 ]; then
      pm=1
    fi
    if [ "$pc" -eq 1 ] && [ "$pco" -eq 1 ] && [ "$pm" -eq 1 ]; then
      printf 'ok\n'
      exit 0
    elif [ "$pc" -eq 0 ] && [ "$pco" -eq 0 ] && [ "$pm" -eq 0 ]; then
      printf 'none\n'
      exit 3
    else
      printf 'partial\n'
      exit 2
    fi
    ;;
esac
