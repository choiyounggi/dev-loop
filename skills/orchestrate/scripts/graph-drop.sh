#!/bin/sh
# graph-drop.sh — remove ONE undispatched task node from graph.json, or
# change nothing.
#
# Symmetric to graph-add.sh: every check runs against the RESULTING graph
# rather than the node alone, because the defects that matter are relational
# — a dangling dependency, a dangling split_of, a dangling consumes. A
# rejected drop leaves the file byte-identical — a half-applied graph would
# make re-entry read a state that never existed.
#
# usage: graph-drop.sh <graph.json> <status-dir> <task-id>
#   <status-dir>  .orchestration/status — one <task>.json per task.
#                 launch-session.sh pre-seeds phase=pending at dispatch, so a
#                 task with an EXISTING status file (any phase, pending
#                 included) has already been dispatched and may not be
#                 dropped here — that is the rework/failed flow's job.
#
# exit 0  dropped (file rewritten atomically)
# exit 3  REJECTED — the resulting graph would be invalid, or the task is
#         already dispatched. Nothing was written; the reason is printed.
# exit 4  the graph or status-dir could not be read — refuse rather than guess
# exit 127 jq not found
set -u

JQ=$(command -v jq) || { echo "graph-drop: jq not found" >&2; exit 127; }

graph="${1:-}"; sdir="${2:-}"; id="${3:-}"
[ -n "$graph" ] && [ -n "$sdir" ] && [ -n "$id" ] || {
  echo "usage: graph-drop.sh <graph.json> <status-dir> <task-id>" >&2; exit 4; }
[ -f "$graph" ] || { echo "graph-drop: graph '$graph' not found" >&2; exit 4; }
[ -d "$sdir" ]  || { echo "graph-drop: status dir '$sdir' not found" >&2; exit 4; }

"$JQ" -e 'has("tasks") and (.tasks | type == "array")' "$graph" >/dev/null 2>&1 || {
  echo "graph-drop: graph '$graph' is not a valid task graph" >&2; exit 4; }

reject() { echo "graph-drop: REJECTED — $1" >&2; exit 3; }

# 1. The id must name a task the graph defines.
"$JQ" -e --arg id "$id" '[.tasks[] | select(.id == $id)] | length == 1' "$graph" >/dev/null 2>&1 \
  || reject "'$id' names no task in the graph"

# 2. Already dispatched: a status file exists (any phase). Dropping a
#    dispatched task would orphan its worker — the rework/failed flow owns
#    that instead.
[ -f "$sdir/$id.json" ] && reject "'$id' is already dispatched — has a status file"

# Build the candidate graph in memory. Nothing touches the file until every
# check below has passed.
cand=$("$JQ" --arg id "$id" 'del(.tasks[] | select(.id == $id))' "$graph" 2>/dev/null) || {
  echo "graph-drop: could not build the candidate graph" >&2; exit 4; }

# 3. No remaining task may still name the dropped id in deps, split_of, or
#    consume one of its outputs — dependents must be dropped first (leaves
#    before parents). Every check (and the id list for its message) is
#    computed wholly inside jq, never iterated in the shell: a task id or
#    output value containing whitespace must not be word-split.
dependers=$(printf '%s' "$cand" | "$JQ" -r --arg id "$id" \
  '[.tasks[] | select(.deps[]? == $id) | .id] | join(", ")')
[ -z "$dependers" ] || reject "'$id' — task(s) $dependers still depend on it"

splitters=$(printf '%s' "$cand" | "$JQ" -r --arg id "$id" \
  '[.tasks[] | select(.split_of? == $id) | .id] | join(", ")')
[ -z "$splitters" ] || reject "'$id' — task(s) $splitters still name it as split_of"

consumers=$("$JQ" -r --arg id "$id" '
    ([.tasks[] | select(.id == $id) | .outputs[]?]) as $outs
    | [.tasks[] | select(.id != $id) | select(any(.consumes[]?; $outs | index(.) != null)) | .id]
    | join(", ")
  ' "$graph" 2>/dev/null)
[ -z "$consumers" ] || reject "'$id' output(s) still consumed by task(s) $consumers"

# Atomic: write beside the target and rename, so a reader never sees a
# partial file.
tmp="$graph.tmp.$$"
printf '%s\n' "$cand" > "$tmp" || { rm -f "$tmp"; echo "graph-drop: could not write $tmp" >&2; exit 4; }
mv "$tmp" "$graph" || { rm -f "$tmp"; echo "graph-drop: could not replace $graph" >&2; exit 4; }
echo "graph-drop: dropped '$id'"
