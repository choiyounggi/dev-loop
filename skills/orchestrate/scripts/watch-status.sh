#!/bin/sh
# watch-status.sh — poll a status dir until every session reaches (>=) a target
# phase, then exit 0. The orchestrator launches this with run_in_background; on
# exit the harness re-invokes the orchestrator.
#
# usage: watch-status.sh <status-dir> <target-phase> <expected-count> [timeout-sec] [interval-sec]
#   exit 0: all reached target (or higher)
#   exit 2: timeout
#   exit 3: a failed session detected (abort → orchestrator intervenes)
set -eu
JQ=$(command -v jq) || { echo "watch-status: jq not found" >&2; exit 127; }

dir="$1"; target="$2"; expected="$3"; timeout="${4:-3600}"; interval="${5:-15}"

# monotonic phase order (low->high); failed handled separately
order="pending planning plan_ready implementing impl_done approved merged done"
rank() { i=0; for p in $order; do [ "$p" = "$1" ] && { echo "$i"; return; }; i=$((i+1)); done; echo -1; }
target_rank=$(rank "$target")
# Guard: an unknown/typo'd target phase yields rank -1, which every phase would
# satisfy (r >= -1) → instant false "all done". Refuse it.
if [ "$target_rank" -lt 0 ]; then echo "watch-status: unknown target phase '$target'" >&2; exit 4; fi
[ -d "$dir" ] || { echo "watch-status: status dir '$dir' does not exist" >&2; exit 4; }

elapsed=0
while [ "$elapsed" -lt "$timeout" ]; do
  done_count=0; failed=0; summary=""
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    ph=$("$JQ" -r '.phase // "pending"' "$f" 2>/dev/null || echo "pending")
    tk=$("$JQ" -r '.task // "?"' "$f" 2>/dev/null || echo "?")
    summary="$summary $tk:$ph"
    [ "$ph" = "failed" ] && { failed=$((failed+1)); continue; }
    r=$(rank "$ph")
    [ "$r" -ge "$target_rank" ] && done_count=$((done_count+1))
  done
  echo "[watch ->$target] $done_count/$expected |$summary"
  [ "$failed" -gt 0 ] && { echo "[watch] failed session detected — abort"; exit 3; }
  [ "$done_count" -ge "$expected" ] && { echo "[watch] all reached $target"; exit 0; }
  sleep "$interval"; elapsed=$((elapsed+interval))
done
echo "[watch] TIMEOUT (${timeout}s):$summary"; exit 2
