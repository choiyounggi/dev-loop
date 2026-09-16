#!/bin/sh
# collect-status.sh — coordinator-side collector: workers write worktree-local
# .orchestration/status and .orchestration/questions records; this copies them
# into the canonical dir, filtered by the run's graph.json, atomically, and
# without regressing coordinator-set state ("collect, don't deposit" — see
# wiki/infrastructure/agent-orchestration/worktree-isolated-workers.md).
#
# usage: collect-status.sh <graph.json> <canonical-status-dir> <worktrees-root>
#   scans <worktrees-root>/*/.orchestration/status/*.json for records whose
#   basename (minus .json) is a task id in graph.json's .tasks[].id — anything
#   else is a foreign run sharing the parent dir and is counted, not copied.
#   Each in-graph record is copied into <canonical-status-dir>/<task>.json via
#   tmp+mv when:
#     - no canonical record exists yet, or
#     - the canonical .phase is not done/failed (tombstone — never overwritten), AND
#     - the worker record's .updatedAt is strictly greater (ISO-8601 UTC
#       strings, lexical compare) than the canonical's .updatedAt
#   The canonical record's .attempt (when present) is preserved onto the
#   collected record — only the coordinator's rework increments .attempt, and
#   only on the canonical copy.
#
#   Also copies <worktrees-root>/*/.orchestration/questions/*.json (task id in
#   the graph) to <canonical-status-dir>/../questions/<task>.json, but only
#   when no canonical question record already exists (copy-if-absent) — an
#   answered/cleared question must never be re-collected.
#
#   Also collects <worktrees-root>/*/.orchestration/blocked/<task>.json
#   (BlockedRecord, written by hooks/worker-blocked-signal.sh; task id in the
#   graph) into <canonical-status-dir>/../blocked/<task>.json via tmp+mv when
#   the canonical copy is absent or its .ts is NOT strictly greater (lexical
#   compare) than the worker's .ts — the last event always wins, including a
#   same-second tie, unlike status's tombstone rule. A second pass then
#   removes any canonical
#   blocked record whose .worktree field is empty, names a missing directory,
#   or has no matching WORKTREE/.orchestration/blocked/<task>.json, so a
#   cleared or relaunched worker's stale record does not linger and keep
#   waking the coordinator. Neither pass changes the collected/skipped/foreign
#   counters or the stdout contract.
#
#   exit 0: ran (stdout: exactly one line `collected=<n> skipped=<n> foreign=<n>`)
#   exit 2: usage error (wrong arg count)
#   exit 4: graph unreadable or malformed (no .tasks array), or the canonical
#           dirs could not be created
#   exit 127: jq not found
set -eu

JQ=$(command -v jq) || { echo "collect-status: jq not found" >&2; exit 127; }

[ $# -eq 3 ] || {
  echo "usage: collect-status.sh <graph.json> <canonical-status-dir> <worktrees-root>" >&2
  exit 2
}
graph="$1"; cdir="$2"; wroot="$3"

[ -f "$graph" ] || { echo "collect-status: graph '$graph' not found" >&2; exit 4; }
"$JQ" -e '.tasks | type == "array"' "$graph" >/dev/null 2>&1 || {
  echo "collect-status: graph '$graph' is not valid JSON with a .tasks array" >&2
  exit 4
}

mkdir -p "$cdir" || { echo "collect-status: cannot create '$cdir'" >&2; exit 4; }
qdir="$(dirname "$cdir")/questions"
mkdir -p "$qdir" || { echo "collect-status: cannot create '$qdir'" >&2; exit 4; }
bdir="$(dirname "$cdir")/blocked"
mkdir -p "$bdir" || { echo "collect-status: cannot create '$bdir'" >&2; exit 4; }

ids=$("$JQ" -r '.tasks[]?.id // empty' "$graph")
# -F: the candidate is a LITERAL string, not a BRE pattern — an id/basename
# containing a regex metacharacter (e.g. `t1.status`) must not fuzzy-match a
# near-miss; D2's contract is exact membership.
is_task() { echo "$ids" | grep -Fqx -- "$1"; } # $1 = candidate id -> 0 if it's in this run's graph

tmp=""
trap '[ -n "$tmp" ] && rm -f "$tmp"' EXIT

collected=0; skipped=0; foreign=0

for f in "$wroot"/*/.orchestration/status/*.json; do
  [ -f "$f" ] || continue
  base=${f##*/}; task=${base%.json}

  if ! is_task "$task"; then
    foreign=$((foreign + 1))
    continue
  fi

  "$JQ" -e . "$f" >/dev/null 2>&1 || {
    echo "collect-status: malformed worker record '$f' — skipped" >&2
    skipped=$((skipped + 1))
    continue
  }

  cfile="$cdir/$task.json"
  cattempt=""
  if [ -f "$cfile" ]; then
    "$JQ" -e . "$cfile" >/dev/null 2>&1 || {
      echo "collect-status: malformed canonical record '$cfile' — skipped" >&2
      skipped=$((skipped + 1))
      continue
    }
    cphase=$("$JQ" -r '.phase // ""' "$cfile")
    case "$cphase" in
      done|failed)
        skipped=$((skipped + 1))
        continue
        ;;
    esac
    cupdated=$("$JQ" -r '.updatedAt // ""' "$cfile")
    wupdated=$("$JQ" -r '.updatedAt // ""' "$f")
    if ! [ "$wupdated" \> "$cupdated" ]; then
      skipped=$((skipped + 1))
      continue
    fi
    cattempt=$("$JQ" -r 'if has("attempt") then .attempt else empty end' "$cfile")
  fi

  tmp="$cfile.tmp.$$"
  if [ -n "$cattempt" ]; then
    "$JQ" --argjson a "$cattempt" '.attempt = $a' "$f" > "$tmp"
  else
    "$JQ" '.' "$f" > "$tmp"
  fi
  mv "$tmp" "$cfile"
  tmp=""
  collected=$((collected + 1))
done

for f in "$wroot"/*/.orchestration/questions/*.json; do
  [ -f "$f" ] || continue
  base=${f##*/}; task=${base%.json}
  is_task "$task" || continue

  "$JQ" -e . "$f" >/dev/null 2>&1 || {
    echo "collect-status: malformed worker question '$f' — skipped" >&2
    continue
  }

  qfile="$qdir/$task.json"
  [ -f "$qfile" ] && continue

  tmp="$qfile.tmp.$$"
  "$JQ" '.' "$f" > "$tmp"
  mv "$tmp" "$qfile"
  tmp=""
done

for f in "$wroot"/*/.orchestration/blocked/*.json; do
  [ -f "$f" ] || continue
  base=${f##*/}; task=${base%.json}
  is_task "$task" || continue

  # type=="object", not just "-e ." (which a bare array or string also
  # passes): an indexing error like `.ts` on `[]` is NOT rescued by `//`
  # under set -eu and would abort the whole script (F4, round-2 review).
  "$JQ" -e 'type == "object"' "$f" >/dev/null 2>&1 || {
    echo "collect-status: malformed worker blocked record '$f' — skipped" >&2
    continue
  }

  bfile="$bdir/$task.json"
  if [ -f "$bfile" ] && "$JQ" -e 'type == "object"' "$bfile" >/dev/null 2>&1; then
    wts=$("$JQ" -r '.ts // ""' "$f")
    cts=$("$JQ" -r '.ts // ""' "$bfile")
    # Skip only when the canonical is STRICTLY newer — a same-second tie
    # goes to the worker record, so the last event wins even when it was
    # stamped in the same whole second as what's already canonical (F1,
    # round-3 review).
    [ "$cts" \> "$wts" ] && continue
  fi

  tmp="$bfile.tmp.$$"
  "$JQ" '.' "$f" > "$tmp"
  mv "$tmp" "$bfile"
  tmp=""
done

for b in "$bdir"/*.json; do
  [ -f "$b" ] || continue
  bbase=${b##*/}; btask=${bbase%.json}
  bwt=$("$JQ" -r '.worktree // ""' "$b" 2>/dev/null || true)
  if [ -z "$bwt" ] || [ ! -d "$bwt" ] || [ ! -f "$bwt/.orchestration/blocked/$btask.json" ]; then
    rm -f "$b"
  fi
done

echo "collected=$collected skipped=$skipped foreign=$foreign"
