#!/bin/sh
# ask-coordinator.sh — record a worker->coordinator question as a durable file.
#
# A worker that needs a decision writes ONE pending question record; the
# coordinator's watch-status.sh surfaces it as exit 6 within one poll interval.
# Questions live beside the status dir, mirroring the escalations/ sibling:
#   <root>/.orchestration/{status,escalations,questions}
#
# usage: STATUS_DIR=<absolute-status-dir> ask-coordinator.sh <task> <question> [options-csv]
#   writes $(dirname $STATUS_DIR)/questions/<task>.json atomically (tmp+mv):
#     {ts, taskId, question, options, worktree}
#   options-csv splits on "," verbatim — no trimming, so "a," yields ["a",""];
#   absent or empty -> []. worktree = `pwd -P`. One pending question per task:
#   a second call for the same task overwrites the record.
#
#   exit 0: record written    exit 1: usage error    exit 127: jq not found
set -eu
JQ=$(command -v jq) || { echo "ask-coordinator: jq not found" >&2; exit 127; }

usage() { echo "usage: STATUS_DIR=<dir> ask-coordinator.sh <task> <question> [options-csv]" >&2; exit 1; }

dir="${STATUS_DIR:-}"
[ -n "$dir" ] || usage
{ [ $# -ge 2 ] && [ $# -le 3 ]; } || usage
task="$1"; question="$2"; csv="${3:-}"
[ -n "$question" ] || usage
# The task name becomes a filename below; refuse anything that could escape the
# questions dir (the same guard tmux-worker-stalled.sh applies to session names).
case "$task" in
  */*|.|..|'') usage ;;
esac

qdir="$(dirname "$dir")/questions"
mkdir -p "$qdir"
qfile="$qdir/$task.json"

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)   # cross-platform (GNU/BSD) iso-8601 UTC
wt=$(pwd -P)

# One atomic write: build the whole record in memory and land it with tmp+mv,
# so watch-status can never read a half-written record.
tmp="$qfile.tmp.$$"
trap 'rm -f "$tmp"' EXIT
"$JQ" -n --arg ts "$now" --arg t "$task" --arg q "$question" --arg o "$csv" --arg w "$wt" \
  '{ts:$ts, taskId:$t, question:$q,
    options:(if $o == "" then [] else ($o | split(",")) end),
    worktree:$w}' > "$tmp" && mv "$tmp" "$qfile"

echo "question[$task] recorded"
