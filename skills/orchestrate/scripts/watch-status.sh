#!/bin/sh
# watch-status.sh — poll a status dir until every session reaches (>=) a target
# phase, then exit 0. The orchestrator launches this with run_in_background; on
# exit the harness re-invokes the orchestrator.
#
# usage: watch-status.sh [--tasks <csv>] <status-dir> <target-phase> <expected-count> [timeout-sec] [interval-sec]
#   --tasks: scope the scan to only the given comma-separated task ids. The slot
#   scheduler needs to wake as soon as ANY currently-running task reaches the target;
#   without scoping, the full status dir would count tasks approved in earlier rounds
#   and the wait would spin on stale data.
#   exit 0: all reached target (or higher)
#   exit 2: timeout
#   exit 3: a failed session detected (abort → orchestrator intervenes)
#   exit 4: bad arguments (unknown target phase, missing dir, bad LO_PHASE_TIMEOUTS)
#   exit 5: an escalation is pending (a worker's guardrails `ask` needs approval)
#   exit 6: a worker question is pending (an ask-coordinator.sh record — answer
#           and clear questions/ before relaunching)
#   exit 7: a live non-terminal worker's pane is stalled (tmux-worker-stalled.sh
#           reported 1 — a wedged/idle worker; inspect or nudge the session)
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

# --tasks scopes the scan to the given ids. The slot scheduler needs "any ONE of
# the tasks I am currently running reached the target"; counting the whole status
# dir would satisfy expected=1 from tasks approved in earlier rounds and spin.
only=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tasks) shift; only="${1:-}"; [ -n "$only" ] || { echo "watch-status: --tasks needs a comma-separated id list" >&2; exit 4; }; shift ;;
    --) shift; break ;;
    -*) echo "watch-status: unknown option '$1'" >&2; exit 4 ;;
    *) break ;;
  esac
done
# Captured AFTER option parsing: argc decides whether the 4th POSITIONAL was
# given, and options must not be counted toward it.
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
# Worker questions (ask-coordinator.sh) use the same sibling layout: <root>/.orchestration/questions.
qdir="$(dirname "$dir")/questions"
# tmux binary for dead-worker (liveness) checks; overridable in tests via WATCH_TMUX.
# If it is not resolvable, DISABLE liveness (empty) rather than flag every worker
# dead — a missing tmux must not abort the run (`! missing-cmd` would invert to true).
TMUX_BIN="${WATCH_TMUX:-tmux}"
command -v "$TMUX_BIN" >/dev/null 2>&1 || TMUX_BIN=""
# Per-session stall detection (a live pane silent for LO_STALL_SEC), run via
# tmux-worker-stalled.sh; overridable in tests via WATCH_STALL_SCRIPT. A missing
# script DISABLES the check (empty), mirroring the TMUX_BIN treatment above.
STALL_SCRIPT="${WATCH_STALL_SCRIPT:-$(dirname "$0")/tmux-worker-stalled.sh}"
[ -f "$STALL_SCRIPT" ] || STALL_SCRIPT=""
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

  # A worker question (ask-coordinator.sh) wakes the coordinator the same way an
  # escalation does. The coordinator MUST answer and clear the record before
  # relaunching watch; exit 6 recurs while the record file exists, like exit 5.
  # The escalation check above runs first, so exit 5 wins when both are pending.
  if [ -d "$qdir" ]; then
    q_found=0
    for q in "$qdir"/*.json; do
      [ -f "$q" ] || continue
      qtk=$("$JQ" -r '.taskId // "?"' "$q" 2>/dev/null || echo "?")
      qtxt=$("$JQ" -r '.question // "?"' "$q" 2>/dev/null || echo "?")
      echo "[watch] question pending — ${qtk}: ${qtxt}"
      q_found=1
    done
    if [ "$q_found" -eq 1 ]; then exit 6; fi
  fi

  done_count=0; failed=0; summary=""; stalled=""
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    if [ -n "$only" ]; then
      base=${f##*/}; base=${base%.json}
      # Exact membership on a comma-delimited list: the commas around both sides
      # keep `t1` from matching `t12`.
      case ",$only," in *",$base,"*) : ;; *) continue ;; esac
    fi
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
        # Per-session stall check: only rc 1 marks a stall. rc 0 (progressing),
        # rc 2 (unknown), or a broken script are all NOT stalled — the explicit
        # rc capture means no failure here can abort the watch loop.
        if [ -n "$STALL_SCRIPT" ] && [ -n "$TMUX_BIN" ] && [ -n "$sess" ]; then
          src=0; sh "$STALL_SCRIPT" "$sess" >/dev/null 2>&1 || src=$?
          if [ "$src" -eq 1 ]; then stalled="$stalled $tk:$sess"; fi
        fi
        ;;
    esac
    r=$(rank "$ph")
    [ "$r" -ge "$target_rank" ] && done_count=$((done_count+1))
  done
  echo "[watch ->$target] $done_count/$expected |$summary"
  [ "$failed" -gt 0 ] && { echo "[watch] failed session detected — abort"; exit 3; }
  [ "$done_count" -ge "$expected" ] && { echo "[watch] all reached $target"; exit 0; }
  # Stall is the weakest signal: failed(3) and all-reached(0) above win over it.
  if [ -n "$stalled" ]; then echo "[watch] worker stalled —$stalled"; exit 7; fi
  sleep "$interval"; elapsed=$((elapsed+interval))
done
echo "[watch] TIMEOUT (${budget}s, source=${budget_src}):$summary"; exit 2
