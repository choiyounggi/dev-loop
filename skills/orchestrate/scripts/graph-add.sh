#!/bin/sh
# graph-add.sh — add ONE task node to graph.json, or change nothing.
#
# Phase 2 writes graph.json once; this is the only thing that may grow it
# afterwards, when a worker's split proposal is accepted. Every check runs
# against the RESULTING graph rather than the node alone, because the defects
# that matter are relational: a cycle, a second producer of the same output, a
# split of a split. A rejected add leaves the file byte-identical — a
# half-applied graph would make re-entry read a state that never existed.
#
# usage: graph-add.sh <graph.json> <node-json>
#   <node-json>  {"id","deps":[],"files":[],"outputs":[],"split_of":"<parent>"}
#                `split_of` is what enforces the depth-1 rule: a node carrying
#                it is a split child and can never be split again.
#
# exit 0  added (file rewritten atomically)
# exit 3  REJECTED — the resulting graph would be invalid. Nothing was written;
#         the reason is printed. Fix the proposal, do not retry unchanged.
# exit 4  the graph or the node could not be read — refuse rather than guess
# exit 127 jq not found
set -u

JQ=$(command -v jq) || { echo "graph-add: jq not found" >&2; exit 127; }

graph="${1:-}"; node="${2:-}"
[ -n "$graph" ] && [ -n "$node" ] || {
  echo "usage: graph-add.sh <graph.json> <node-json>" >&2; exit 4; }
[ -f "$graph" ] || { echo "graph-add: graph '$graph' not found" >&2; exit 4; }

"$JQ" -e 'has("tasks") and (.tasks | type == "array")' "$graph" >/dev/null 2>&1 || {
  echo "graph-add: graph '$graph' is not a valid task graph" >&2; exit 4; }

printf '%s' "$node" | "$JQ" -e 'type == "object" and (.id | type == "string") and (.id | length > 0)' \
  >/dev/null 2>&1 || { echo "graph-add: node must be a JSON object with a non-empty string id" >&2; exit 4; }

# Build the candidate graph in memory. Nothing touches the file until every
# check below has passed.
cand=$(printf '%s' "$node" | "$JQ" --slurpfile g "$graph" '. as $node | $g[0] | .tasks += [$node]' 2>/dev/null) || {
  echo "graph-add: could not build the candidate graph" >&2; exit 4; }

reject() { echo "graph-add: REJECTED — $1" >&2; exit 3; }

nid=$(printf '%s' "$node" | "$JQ" -r '.id')

# 1. The id must be new. Overwriting a live task would orphan its worker.
printf '%s' "$graph" >/dev/null
"$JQ" -e --arg id "$nid" '[.tasks[] | select(.id == $id)] | length == 0' "$graph" >/dev/null 2>&1 \
  || reject "task id '$nid' already exists"

# 2. Every dependency must name a task the graph defines, otherwise the new node
#    is unreachable forever and ready-set.sh would refuse the whole graph.
missing=$(printf '%s' "$cand" | "$JQ" -r --arg id "$nid" '
  (.tasks | map(.id)) as $ids
  | .tasks[] | select(.id == $id) | .deps[]? | select(. as $d | ($ids | index($d)) | not)')
[ -z "$missing" ] || reject "dependency '$missing' names no task in the graph"

# 3. Depth 1: a split child may not itself be split. This is what stops a worker
#    from deferring work by recursive subdivision, and keeps the graph readable.
sof=$(printf '%s' "$node" | "$JQ" -r '.split_of // empty')
if [ -n "$sof" ]; then
  "$JQ" -e --arg p "$sof" '[.tasks[] | select(.id == $p)] | length == 1' "$graph" >/dev/null 2>&1 \
    || reject "split_of '$sof' names no task in the graph"
  "$JQ" -e --arg p "$sof" '[.tasks[] | select(.id == $p) | select(has("split_of"))] | length == 0' \
    "$graph" >/dev/null 2>&1 || reject "'$sof' is itself a split child — splitting a split is refused (depth 1)"
fi

# 4. One producer per output. Phase 2 already assigns a single producer; a split
#    child therefore declares only what IT newly produces. Moving an output off a
#    parent is a re-decomposition, not an add — that goes back to the user.
dup=$(printf '%s' "$cand" | "$JQ" -r '[.tasks[].outputs[]?] | group_by(.) | map(select(length > 1) | .[0]) | .[]?')
[ -z "$dup" ] || reject "output '$dup' would have two producers"

# 5. No cycle. Repeatedly strip tasks whose deps are all outside the remaining
#    set; whatever will not strip is a cycle.
printf '%s' "$cand" | "$JQ" -e '
  def acyclic:
    def step($rem):
      ($rem | map(.id)) as $ids
      | ($rem | map(select([.deps[]? | select(. as $d | $ids | index($d))] | length == 0))) as $free
      | if ($free | length) == 0 then ($rem | length) == 0
        else step($rem - $free) end;
    step(.tasks);
  acyclic' >/dev/null 2>&1 || reject "the resulting graph contains a dependency cycle"

# Atomic: write beside the target and rename, so a reader never sees a partial
# file (the same tmp+mv shape ask-coordinator.sh uses for question records).
tmp="$graph.tmp.$$"
printf '%s\n' "$cand" > "$tmp" || { rm -f "$tmp"; echo "graph-add: could not write $tmp" >&2; exit 4; }
mv "$tmp" "$graph" || { rm -f "$tmp"; echo "graph-add: could not replace $graph" >&2; exit 4; }
echo "graph-add: added '$nid'"
