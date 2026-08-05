#!/bin/sh
# watch-status.sh — poll a status dir until every session reaches (>=) a target
# phase, then exit 0. The orchestrator launches this with run_in_background; on
# exit the harness re-invokes the orchestrator.
#
# usage: watch-status.sh <status-dir> <target-phase> <expected-count> [timeout-sec] [interval-sec]
#   exit 0: all reached target (or higher)
#   exit 2: timeout
#   exit 3: a failed session detected (abort → orchestrator intervenes)
#   exit 4: bad arguments (unknown target phase, missing dir, bad LO_PHASE_TIMEOUTS)
#   exit 5: an escalation is pending (a worker's guardrails `ask` needs approval)
#
# Per-phase deadlines: one flat timeout gave a plan phase and a long implement
# phase the same budget. LO_PHASE_TIMEOUTS carries a per-phase budget keyed on
# the TARGET phase of this wait, so one exported value serves every call:
#
#   LO_PHASE_TIMEOUTS="plan_ready=900,impl_done=3600,done=1800"
#
# Precedence, highest first:
#   1. an explicitly passed [timeout-sec] argument   (source=arg)
#   2. the entry matching <target-phase>             (source=LO_PHASE_TIMEOUTS)
#   3. the 3600s default                             (source=default)
# A malformed entry (no `=`, non-numeric, <= 0, or a phase name that is not in
# the phase order) is refused with exit 4 rather than silently defaulted — the
# same treatment an unknown target phase already gets, and for the same reason:
# a typo must not quietly buy a wildly wrong deadline. The effective budget and
# its source are printed before the wait and repeated in the TIMEOUT line.
set -eu
JQ=$(command -v jq) || { echo "watch-status: jq not found" >&2; exit 127; }

argc=$#
dir="$1"; target="$2"; expected="$3"; timeout="${4:-3600}"; interval="${5:-15}"

# monotonic phase order (low->high); failed handled separately
order="pending planning plan_ready implementing impl_done approved merged done"
rank() { i=0; for p in $order; do [ "$p" = "$1" ] && { echo "$i"; return; }; i=$((i+1)); done; echo -1; }
target_rank=$(rank "$target")
# Guard: an unknown/typo'd target phase yields rank -1, which every phase would
# satisfy (r >= -1) → instant false "all done". Refuse it.
if [ "$target_rank" -lt 0 ]; then echo "watch-status: unknown target phase '$target'" >&2; exit 4; fi
[ -d "$dir" ] || { echo "watch-status: status dir '$dir' does not exist" >&2; exit 4; }

# ---- effective budget (see the header for the precedence rules) -------------
budget=3600; budget_src=default
if [ -n "${LO_PHASE_TIMEOUTS:-}" ]; then
  # Split on commas via $@ rather than looping with IFS=',' still set: `rank` below
  # splits $order on whitespace, so IFS must be back to normal inside the loop.
  # `set -f` keeps an entry from being glob-expanded on the way in.
  oldifs=$IFS; IFS=','; set -f
  # shellcheck disable=SC2086
  set -- $LO_PHASE_TIMEOUTS
  set +f; IFS=$oldifs
  for entry in "$@"; do
    [ -n "$entry" ] || continue          # tolerate a trailing/doubled comma
    case "$entry" in
      *=*) : ;;
      *) echo "watch-status: invalid LO_PHASE_TIMEOUTS entry '$entry' (expected phase=seconds)" >&2; exit 4 ;;
    esac
    ph=${entry%%=*}; val=${entry#*=}
    case "$val" in
      ''|*[!0-9]*) echo "watch-status: invalid LO_PHASE_TIMEOUTS entry '$entry' (seconds must be a positive integer)" >&2; exit 4 ;;
    esac
    [ "$val" -gt 0 ] || { echo "watch-status: invalid LO_PHASE_TIMEOUTS entry '$entry' (seconds must be > 0)" >&2; exit 4; }
    [ "$(rank "$ph")" -ge 0 ] || { echo "watch-status: invalid LO_PHASE_TIMEOUTS entry '$entry' (unknown phase '$ph')" >&2; exit 4; }
    if [ "$ph" = "$target" ]; then budget="$val"; budget_src=LO_PHASE_TIMEOUTS; fi
  done
fi
# An explicitly passed argument is the caller's direct instruction and outranks
# the environment's policy. $# alone cannot say whether the 4th argument was
# given or defaulted, so the count is captured before anything consumes it.
if [ "$argc" -ge 4 ]; then budget="$timeout"; budget_src=arg; fi
echo "[watch] budget=${budget}s target=${target} source=${budget_src}"

elapsed=0
# Escalations live beside the status dir: <root>/.orchestration/{status,escalations}.
escdir="$(dirname "$dir")/escalations"
# tmux binary for dead-worker (liveness) checks; overridable in tests via WATCH_TMUX.
# If it is not resolvable, DISABLE liveness (empty) rather than flag every worker
# dead — a missing tmux must not abort the run (`! missing-cmd` would invert to true).
TMUX_BIN="${WATCH_TMUX:-tmux}"
command -v "$TMUX_BIN" >/dev/null 2>&1 || TMUX_BIN=""
while [ "$elapsed" -lt "$budget" ]; do
  # A worker's guardrails `ask`, recorded as an escalation, wakes the coordinator
  # immediately rather than waiting out the timeout. The coordinator MUST resolve
  # (approve/deny) and clear these records before relaunching watch; exit 5 recurs
  # by design so an unhandled escalation is never silently dropped.
  if [ -d "$escdir" ]; then
    esc_pending=""
    for e in "$escdir"/*.json; do
      [ -f "$e" ] || continue
      etk=$("$JQ" -r '.taskId // "?"' "$e" 2>/dev/null || echo "?")
      erule=$("$JQ" -r '.rule // "?"' "$e" 2>/dev/null || echo "?")
      esc_pending="$esc_pending ${etk}:${erule}"
    done
    if [ -n "$esc_pending" ]; then
      echo "[watch] escalation pending —$esc_pending — approve/deny and clear $escdir"
      exit 5
    fi
  fi

  done_count=0; failed=0; summary=""
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    ph=$("$JQ" -r '.phase // "pending"' "$f" 2>/dev/null || echo "pending")
    tk=$("$JQ" -r '.task // "?"' "$f" 2>/dev/null || echo "?")
    summary="$summary $tk:$ph"
    [ "$ph" = "failed" ] && { failed=$((failed+1)); continue; }
    # dead-worker (zombie) detection: a non-terminal task whose tmux session is
    # gone is treated as a failure, so the run aborts fast instead of waiting the
    # whole timeout. Terminal phases are skipped (the session may legitimately end).
    case "$ph" in
      done|merged|approved) : ;;
      *)
        sess=$("$JQ" -r '.session // empty' "$f" 2>/dev/null || echo "")
        if [ -n "$TMUX_BIN" ] && [ -n "$sess" ] && ! "$TMUX_BIN" has-session -t "$sess" 2>/dev/null; then
          echo "[watch] task $tk: session '$sess' gone at phase '$ph' — dead worker"
          failed=$((failed+1)); continue
        fi
        ;;
    esac
    r=$(rank "$ph")
    [ "$r" -ge "$target_rank" ] && done_count=$((done_count+1))
  done
  echo "[watch ->$target] $done_count/$expected |$summary"
  [ "$failed" -gt 0 ] && { echo "[watch] failed session detected — abort"; exit 3; }
  [ "$done_count" -ge "$expected" ] && { echo "[watch] all reached $target"; exit 0; }
  sleep "$interval"; elapsed=$((elapsed+interval))
done
echo "[watch] TIMEOUT (${budget}s, source=${budget_src}):$summary"; exit 2
