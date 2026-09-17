#!/usr/bin/env bash
# dev-loop — fail-open launcher for the bundled-wiki RAG entry points.
#
#   wiki-mcp-launch.sh [serve]        the dev-loop-wiki stdio MCP server
#   wiki-mcp-launch.sh index <flags>  the indexer (--build / --incremental / ...)
#
# Runs them through `uv run --with ...` so nothing is installed globally. Every
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

# Range pins, not floating latest: an unpinned major bump is a supply-chain
# change nobody reviewed. No --python — the packages' own Requires-Python
# floor is the interpreter constraint.
PINS=(--with 'sqlite-vec>=0.1.6,<0.2' --with 'fastembed>=0.7,<1' --with 'mcp>=2,<3')

case "$verb" in
  serve)
    uv run "${PINS[@]}" python "$HERE/wiki-mcp.py"
    ;;
  index)
    uv run "${PINS[@]}" python "$HERE/wiki-index.py" "$@"
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
