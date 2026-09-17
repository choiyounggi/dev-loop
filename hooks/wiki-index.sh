#!/usr/bin/env bash
# dev-loop — SessionStart: keep the bundled-wiki vector index fresh.
#
# Reads one freshness token from scripts/wiki-index.py --status and, when the
# index is stale, detaches the rebuild through scripts/wiki-mcp-launch.sh so
# session start never waits on embedding. Prints nothing and always exits 0 —
# an absent uv, an absent python3, or a failing status leaves every existing
# routing path untouched. Disable with DEV_LOOP_WIKI_INDEX=0 (also off/false).
set +e

case "${DEV_LOOP_WIKI_INDEX:-1}" in
  0|off|false) exit 0 ;;
esac

# Don't reindex from inside the flush working checkout.
case "${CLAUDE_PROJECT_DIR:-$PWD}" in
  "$HOME/.dev-loop/repo"*) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0
command -v uv >/dev/null 2>&1 || exit 0

HERE=$(cd "$(dirname "$0")" && pwd -P)
INDEX_DIR="${DEV_LOOP_WIKI_INDEX_DIR:-$HOME/.dev-loop/wiki-index}"

status=$(python3 "$HERE/../scripts/wiki-index.py" --status 2>/dev/null)
case "$status" in
  full) flag=--build ;;
  incremental) flag=--incremental ;;
  *) exit 0 ;;
esac

mkdir -p "$INDEX_DIR" 2>/dev/null || exit 0
LOG="$INDEX_DIR/build.log"

nohup bash "$HERE/../scripts/wiki-mcp-launch.sh" index "$flag" >>"$LOG" 2>&1 </dev/null &
disown 2>/dev/null

exit 0
