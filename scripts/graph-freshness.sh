#!/usr/bin/env bash
# graph-freshness.sh — is the repo's graphify code graph fresh enough to use as a lead?
#
# usage: graph-freshness.sh <root> [--graph <path>]
#
# stdout: exactly one line the caller branches on
#   fresh                      exit 0  no commit touched a file after graph.json's mtime
#   stale <N>                  exit 2  N distinct paths changed by commits after the mtime
#   absent                     exit 3  no graph.json (default <root>/graphify-out/graph.json)
#   cannot-evaluate <reason>   exit 4  reason: usage | no-cli | bad-graph | not-git
# stderr: on exit 2 one hint line naming `graphify update <root>`; on exit 4 the reason.
#
# Never runs graphify. It only checks that `${GRAPHIFY_BIN:-graphify}` resolves via
# `command -v`, because the CLI exits 0 on a missing node, a missing file, and a
# JSON decode error, so its exit status carries no signal (wiki: infrastructure/
# agent-orchestration/code-graph-as-orientation-layer, edge case row 3).
# Uncommitted edits are not counted — freshness is relative to commits only.
# A commit in the same second as the mtime counts as stale (git --since is inclusive).
set -euo pipefail

usage_fail() {
  printf 'usage: graph-freshness.sh <root> [--graph <path>]\n' >&2
  printf 'cannot-evaluate usage\n'
  exit 4
}

root=""
graph_override=""
while [ $# -gt 0 ]; do
  case "$1" in
    --graph)
      [ $# -ge 2 ] || usage_fail
      graph_override="$2"; shift 2 ;;
    --*) usage_fail ;;
    *)
      [ -z "$root" ] || usage_fail
      root="$1"; shift ;;
  esac
done
[ -n "$root" ] && [ -d "$root" ] || usage_fail

graph="${graph_override:-$root/graphify-out/graph.json}"
if [ ! -f "$graph" ]; then
  printf 'absent\n'
  exit 3
fi

bin="${GRAPHIFY_BIN:-graphify}"
if ! command -v "$bin" >/dev/null 2>&1; then
  printf 'graphify CLI not found (GRAPHIFY_BIN=%s)\n' "$bin" >&2
  printf 'cannot-evaluate no-cli\n'
  exit 4
fi

if ! jq -e '.nodes | type == "array"' "$graph" >/dev/null 2>&1; then
  printf 'unreadable graph: %s\n' "$graph" >&2
  printf 'cannot-evaluate bad-graph\n'
  exit 4
fi

if ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'not a git repository: %s\n' "$root" >&2
  printf 'cannot-evaluate not-git\n'
  exit 4
fi

# mtime as epoch: BSD/GNU `date -r FILE`, then GNU stat, then BSD stat.
epoch=$(date -r "$graph" +%s 2>/dev/null || stat -c %Y "$graph" 2>/dev/null || stat -f %m "$graph")

# Paths under the graph's own output directory are not code changes: a repo that
# commits graphify-out/ would otherwise report the rebuild commit itself as stale.
root_abs=$(cd "$root" && pwd -P)
gdir_abs=$(cd "$(dirname "$graph")" && pwd -P)
gdir_rel=""
case "$gdir_abs/" in
  "$root_abs"/*) gdir_rel="${gdir_abs#"$root_abs"/}/" ;;
esac

# An unborn HEAD (git init, no commits yet) has nothing newer than the graph;
# `git log` would exit 128 there, outside the contract.
if ! git -C "$root" rev-parse -q --verify HEAD >/dev/null 2>&1; then
  printf 'fresh\n'
  exit 0
fi

# -m --first-parent: a merge commit lists what it landed on this branch (plain
# --name-only prints nothing for merges, under-counting merged changes).
n=$(git -C "$root" log --since="@$epoch" -m --first-parent --name-only --format='' \
  | sed '/^$/d' \
  | awk -v p="$gdir_rel" 'p == "" || index($0, p) != 1' \
  | sort -u | wc -l | tr -d ' ')

if [ "$n" -eq 0 ]; then
  printf 'fresh\n'
  exit 0
fi

printf 'hint: graphify update "%s"   # AST-only, no LLM; rebuilds graphify-out/graph.json from the current checkout\n' "$root" >&2
printf 'stale %s\n' "$n"
exit 2
