#!/usr/bin/env bash
# dev-loop — fail-open launcher for the bundled-wiki RAG entry points.
#
#   wiki-mcp-launch.sh [serve]        the dev-loop-wiki stdio MCP server
#   wiki-mcp-launch.sh index <flags>  the indexer (--build / --incremental / ...)
#
# Runs them through `uv run --locked` so nothing is installed globally. Every
# failure path — no uv, an unresolvable dependency, a crashing server — exits 0
# silently: a broken index must leave the existing wiki routing untouched.
# Disable with DEV_LOOP_WIKI_INDEX=0 (also off/false). DEV_LOOP_WIKI_DEBUG=1
# prints the reason to stderr; stdout belongs to the MCP protocol.
set +e

HERE=$(cd "$(dirname "$0")" && pwd -P)

verb="${1:-serve}"
[ $# -gt 0 ] && shift

case "${DEV_LOOP_WIKI_INDEX:-1}" in
  0|off|false) exit 0 ;;
esac

command -v uv >/dev/null 2>&1 || exit 0

# Locked, not floating or ranged: an unpinned dependency is a supply-chain
# change nobody reviewed. scripts/wiki-env/pyproject.toml pins each package
# exactly and scripts/wiki-env/uv.lock records the whole resolved tree;
# --locked refuses to run if the two disagree, and --isolated keeps the
# environment in uv's cache instead of a .venv inside the plugin. No --python —
# requires-python in that pyproject is the interpreter constraint.
case "$verb" in
  serve)
    uv run --locked --isolated --project "$HERE/wiki-env" python "$HERE/wiki-mcp.py"
    ;;
  index)
    uv run --locked --isolated --project "$HERE/wiki-env" python "$HERE/wiki-index.py" "$@"
    ;;
  *)
    if [ "${DEV_LOOP_WIKI_DEBUG:-0}" = 1 ]; then
      echo "wiki-mcp-launch: unknown verb $verb" >&2
    fi
    exit 0
    ;;
esac
rc=$?

if [ "$rc" -ne 0 ] && [ "${DEV_LOOP_WIKI_DEBUG:-0}" = 1 ]; then
  echo "wiki-mcp-launch: $verb exited $rc (fail-open)" >&2
fi
exit 0
