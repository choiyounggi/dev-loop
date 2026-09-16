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
#   exit 8: a worker is blocked — a current .orchestration/blocked record
#           (worker-blocked-signal.sh hook) whose pane stayed unchanged across
#           two polls; handle it, delete both record copies, then relaunch
#
# A blocked record is a HINT, not proof: the hook contract says a dialog
# answered by `keys` in-turn leaves the record behind, so a record only
# counts as current while its .ts is not older than the task's status
# .updatedAt (>=, not strictly >: a status-update and a hook can legitimately
# stamp the same whole second — see F2 of the round-2 integration review).
# Equality is safe here precisely because currency is not the only gate:
# the static-pane witness below still requires two consecutive identical
# captures, so a worker that actually moved on in that same second repaints
# and never wakes. Currency alone still is not enough (an idle_prompt can fire
# while a background agent is still working), so the witness is the pane
# itself: this script hashes `tmux capture-pane` for the task's session once
# per poll, and only wakes (exit 8) once the same (ts, hash) has been seen on
# two consecutive polls — about one interval after the pane truly stops
# moving, and never while it keeps repainting (a spinner, a counter, a
# background-agent timer).
#
# LO_GRAPH + LO_WORKTREES_ROOT (both required together, issue #167): workers
# write status/questions worker-locally now, never into this checkout. When
# both are set, every poll iteration runs `collect-status.sh $LO_GRAPH <dir>
# $LO_WORKTREES_ROOT` first to pull those records in; a collector failure
# warns on stderr and the wait continues. Either unset -> unchanged behavior.
#
# Auto-recover (on by default): a worker's pane can hold an unsubmitted
# [Pasted text placeholder (send-prompt.sh `state` exit 9) after a prompt
# lands but nothing presses Enter — today that costs the full stall timeout
# before the coordinator wakes to press it itself. When a non-terminal,
# below-target task's session reports exit 9 on two consecutive polls of this
# watch process, watch-status.sh presses Enter itself via `send-prompt.sh keys
# SESSION Enter` and keeps polling; this never changes the exit-code contract
# above. LO_AUTO_RECOVER set to 0, off, or false disables it (unset or any
# other value, including empty, enables it). LO_AUTO_RECOVER_MAX (default 3)
# bounds Enter presses per session for the lifetime of this watch process; a
# non-numeric or zero value is refused with exit 4 before polling starts, the
# same treatment LO_PHASE_TIMEOUTS gets. WATCH_SEND_PROMPT overrides the
# send-prompt.sh path used (default: the sibling send-prompt.sh next to this
# script) — tests use it to stub the `state`/`keys` verbs. Single-actor
# assumption the two-poll debounce relies on: the coordinator only calls
# send-prompt.sh after a watch-status.sh run has exited, never while a poll is
# in flight, so this script's own `keys` call is always the only outstanding
# send for a session.
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
# Blocked records (worker-blocked-signal.sh hook, collected by collect-status.sh)
# use the same sibling layout: <root>/.orchestration/blocked.
bdir="$(dirname "$dir")/blocked"
# Per-task static-pane witness state for this watch process: newline-separated
# "TASK<TAB>TS<TAB>HASH<TAB>COUNT" lines. bl_get prints TS/HASH/COUNT for a
# task (nothing if absent); bl_put replaces that task's line and prints the
# new state. A literal tab (not a space) delimits fields — task ids and ts
# values may contain either.
bl_state=""
bl_tab=$(printf '\t')
bl_get() {
  printf '%s\n' "$bl_state" | awk -F "$bl_tab" -v t="$1" '$1==t{print $2 "\t" $3 "\t" $4; exit}'
}
bl_put() {
  printf '%s\n' "$bl_state" | awk -F "$bl_tab" -v t="$1" -v ts="$2" -v h="$3" -v c="$4" -v tab="$bl_tab" \
    'NF==0{next} $1!=t{print} END{print t tab ts tab h tab c}'
}
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

# Auto-recover setup (see the header paragraph above). Validated up front,
# like LO_PHASE_TIMEOUTS, so a typo'd bound fails fast rather than mid-wait.
AR_MAX="${LO_AUTO_RECOVER_MAX:-3}"
case "$AR_MAX" in
  ''|*[!0-9]*) echo "watch-status: invalid LO_AUTO_RECOVER_MAX '$AR_MAX' (must be a positive integer)" >&2; exit 4 ;;
esac
[ "$AR_MAX" -gt 0 ] || { echo "watch-status: invalid LO_AUTO_RECOVER_MAX '$AR_MAX' (must be > 0)" >&2; exit 4; }
SEND_PROMPT="${WATCH_SEND_PROMPT:-$(dirname "$0")/send-prompt.sh}"
case "${LO_AUTO_RECOVER:-1}" in
  0|off|false) AR_ON=0; echo "[watch] auto-recover=off (LO_AUTO_RECOVER=${LO_AUTO_RECOVER})" ;;
  *)
    if [ -f "$SEND_PROMPT" ]; then
      AR_ON=1; echo "[watch] auto-recover=on (max=$AR_MAX)"
    else
      AR_ON=0; echo "[watch] auto-recover=off (send-prompt script missing)"
    fi
    ;;
esac
# Per-session counters, POSIX sh has no arrays: a leading space then
# "session:count " tokens; the trailing colon in the match pattern keeps
# lo-1 from matching lo-10. Session names are letters/digits/_/- only
# (launch-session.sh), so they cannot collide with the ":"/" " delimiters.
ar_consec=" "
ar_presses=" "
ar_get() {
  case "$1" in
    *" $2:"*)
      ar_g_val="${1#*" $2:"}"
      ar_g_val="${ar_g_val%% *}"
      echo "$ar_g_val"
      ;;
    *) echo 0 ;;
  esac
}
ar_set() {
  case "$1" in
    *" $2:"*)
      ar_s_pre="${1%%" $2:"*}"
      ar_s_rest="${1#*" $2:"}"
      ar_s_post="${ar_s_rest#*" "}"
      printf '%s %s:%s %s' "$ar_s_pre" "$2" "$3" "$ar_s_post"
      ;;
    *) printf '%s%s:%s ' "$1" "$2" "$3" ;;
  esac
}

# classify_stall <session> — read the pane SCROLLBACK (not just the visible
# region) for a stalled session and print an annotation for the exit-7
# message, or nothing if no known pattern matches. Never fails the watch:
# every step degrades to "no annotation" on any capture/parse failure.
# Precedence: usage-limit wins over chooser (the chooser IS the limit
# chooser in the case this was built from).
classify_stall() {
  [ -n "$TMUX_BIN" ] || return 0
  cs_pane=$("$TMUX_BIN" capture-pane -t "=$1:" -p -S -1000 2>/dev/null) || cs_pane=""
  [ -n "$cs_pane" ] || return 0

  # ASCII-only ERE on purpose: the real message's "·" and curly quote are
  # multibyte, and BSD/GNU grep + locale differences make matching them
  # fragile. LO_LIMIT_EXTRA is an ADDITIVE fixed-string match, checked only
  # when the default pattern misses — unset/empty means default-only, never
  # an off switch.
  cs_line=$(printf '%s\n' "$cs_pane" | grep -E "hit your (session|weekly) limit" | tail -n 1)
  if [ -z "$cs_line" ] && [ -n "${LO_LIMIT_EXTRA:-}" ]; then
    cs_line=$(printf '%s\n' "$cs_pane" | grep -F "$LO_LIMIT_EXTRA" | tail -n 1)
  fi
  if [ -n "$cs_line" ]; then
    cs_tail=$(printf '%s\n' "$cs_line" | sed -n 's/.*resets \(.*\)/\1/p')
    if [ -n "$cs_tail" ]; then
      printf 'usage limit \302\267 resets %s' "$cs_tail"
    else
      printf 'usage limit'
    fi
    return 0
  fi

  # Chooser: last 30 lines only — it is live UI at the bottom, so a confirm
  # hint deep in scrollback history is stale, not a pending chooser.
  cs_last30=$(printf '%s\n' "$cs_pane" | tail -n 30)
  if printf '%s\n' "$cs_last30" | grep -qF "Enter to confirm"; then
    printf 'chooser pending \342\200\224 answer with send-prompt.sh keys'
    return 0
  fi
  return 0
}

while [ "$elapsed" -lt "$budget" ]; do
  # Workers write status/questions worker-locally now (issue #167); when both
  # LO_GRAPH and LO_WORKTREES_ROOT are set, pull those records into this
  # canonical dir before scanning it. A transient collector failure must not
  # kill a long wait — warn on stderr and keep polling. Either env unset ->
  # behavior is byte-identical to before this existed (no collector call).
  if [ -n "${LO_GRAPH:-}" ] && [ -n "${LO_WORKTREES_ROOT:-}" ]; then
    sh "$(dirname "$0")/collect-status.sh" "$LO_GRAPH" "$dir" "$LO_WORKTREES_ROOT" >/dev/null \
      || echo "[watch] collect failed (rc=$?) — continuing" >&2
  fi

  # A worker's guardrails `ask`, recorded as an escalation, wakes the coordinator
  # immediately rather than waiting out the timeout. The coordinator MUST resolve
  # (approve/deny) and clear these records before relaunching watch; exit 5 recurs
  # by design so an unhandled escalation is never silently dropped.
  if [ -d "$escdir" ]; then
    esc_pending=""
    esc_lines=""
    for e in "$escdir"/*.json; do
      [ -f "$e" ] || continue
      etk=$("$JQ" -r '.taskId // "?"' "$e" 2>/dev/null || echo "?")
      erule=$("$JQ" -r '.rule // "?"' "$e" 2>/dev/null || echo "?")
      ets=$("$JQ" -r '.ts // "?"' "$e" 2>/dev/null || echo "?")
      # A stale record's meaning ("answer still awaited") is decided by comparing
      # its ts against the task's CURRENT phase/updatedAt — read from the same
      # status file the rest of the watch already polls.
      esf="$dir/${etk}.json"
      if [ -f "$esf" ]; then
        ephase=$("$JQ" -r '.phase // "?"' "$esf" 2>/dev/null || echo "?")
        eupdated=$("$JQ" -r '.updatedAt // "?"' "$esf" 2>/dev/null || echo "?")
      else
        ephase="?"
        eupdated="?"
      fi
      esc_lines="${esc_lines}[watch] escalation pending — ${etk}:${erule} (recorded ${ets}; phase=${ephase} @${eupdated})
"
      esc_pending="$esc_pending ${etk}:${erule}"
    done
    if [ -n "$esc_pending" ]; then
      printf '%s' "$esc_lines"
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

  done_count=0; failed=0; summary=""; stalled=""; blocked=""
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    if [ -n "$only" ]; then
      base=${f##*/}; base=${base%.json}
      # Exact membership on a comma-delimited list: the commas around both sides
      # keep `t1` from matching `t12`.
      case ",$only," in *",$base,"*) : ;; *) continue ;; esac
    fi
    ph=$("$JQ" -r '.phase // "pending"' "$f" 2>/dev/null || echo "pending")
    r=$(rank "$ph")
    tk=$("$JQ" -r '.task // "?"' "$f" 2>/dev/null || echo "?")
    summary="$summary $tk:$ph"
    [ "$ph" = "failed" ] && { failed=$((failed+1)); continue; }
    # dead-worker (zombie) detection: a non-terminal task whose tmux session is
    # gone is treated as a failure, so the run aborts fast instead of waiting the
    # whole timeout. Terminal phases are skipped (the session may legitimately end).
    # This gate is UNCHANGED by the stall-skip gate below (#88): a vanished
    # session at a reached-but-non-terminal phase (e.g. impl_done) is still
    # reportable — reached-target only silences the STALL check, not liveness.
    case "$ph" in
      done|merged|approved) : ;;
      *)
        sess=$("$JQ" -r '.session // empty' "$f" 2>/dev/null || echo "")
        if [ -n "$TMUX_BIN" ] && [ -n "$sess" ] && ! "$TMUX_BIN" has-session -t "$sess" 2>/dev/null; then
          echo "[watch] task $tk: session '$sess' gone at phase '$ph' — dead worker"
          failed=$((failed+1)); continue
        fi
        # Auto-recover: a below-target session whose pane holds an unsubmitted
        # paste on two consecutive polls gets Enter pressed for it here. Runs
        # before the stall check so a just-repaired pane skips this poll's
        # stall verdict (ar_pressed below) instead of re-reporting the exact
        # condition just fixed.
        ar_pressed=0
        if [ "$AR_ON" -eq 1 ] && [ "$r" -lt "$target_rank" ] && [ -n "$TMUX_BIN" ] && [ -n "$sess" ]; then
          ar_n=$(ar_get "$ar_presses" "$sess")
          if [ "$ar_n" -lt "$AR_MAX" ]; then
            arc=0; sh "$SEND_PROMPT" state "$sess" >/dev/null 2>&1 || arc=$?
            if [ "$arc" -eq 9 ]; then
              ar_c=$(( $(ar_get "$ar_consec" "$sess") + 1 ))
              if [ "$ar_c" -ge 2 ]; then
                ar_n=$((ar_n+1))
                ar_presses=$(ar_set "$ar_presses" "$sess" "$ar_n")
                ar_consec=$(ar_set "$ar_consec" "$sess" 0)
                ar_pressed=1
                krc=0; sh "$SEND_PROMPT" keys "$sess" Enter >/dev/null 2>&1 || krc=$?
                if [ "$krc" -eq 0 ]; then
                  echo "[watch] auto-recover — $tk:$sess unsubmitted prompt -> Enter ($ar_n/$AR_MAX)"
                else
                  echo "[watch] auto-recover failed — $tk:$sess (keys rc=$krc)"
                fi
                if [ "$ar_n" -ge "$AR_MAX" ]; then
                  echo "[watch] auto-recover cap reached — $tk:$sess"
                fi
              else
                ar_consec=$(ar_set "$ar_consec" "$sess" "$ar_c")
              fi
            else
              ar_consec=$(ar_set "$ar_consec" "$sess" 0)
            fi
          fi
        fi
        # Blocked-worker check: a current .orchestration/blocked/<task>.json
        # record (see the header) is a HINT confirmed by hashing the pane
        # across two consecutive polls (D3, D4). Gated on ar_pressed==0,
        # exactly like the stall check below: send-prompt.sh keys returns as
        # soon as tmux accepts the key event, not once the CLI has redrawn,
        # so a capture taken moments later can still show the PRE-Enter
        # pane. A poll that pressed Enter is skipped here entirely — neither
        # judged nor recorded into the witness state — so a stale pre-repaint
        # capture never counts toward the two-poll confirmation; the next
        # poll judges the (by then actually repainted) pane fresh.
        if [ "$ar_pressed" -eq 0 ] && [ "$r" -lt "$target_rank" ] && [ -n "$TMUX_BIN" ] && [ -n "$sess" ] \
           && [ -f "$bdir/$tk.json" ] && "$JQ" -e . "$bdir/$tk.json" >/dev/null 2>&1; then
          bts=$("$JQ" -r '.ts // empty' "$bdir/$tk.json" 2>/dev/null || true)
          bupd=$("$JQ" -r '.updatedAt // empty' "$f" 2>/dev/null || true)
          # not older than (>=), not strictly newer — POSIX test has no
          # string >=, so this is "NOT (bupd is newer than bts)".
          if [ -n "$bts" ] && ! [ "$bupd" \> "$bts" ]; then
            cs_ok=1
            cs_pane=$("$TMUX_BIN" capture-pane -t "=$sess:" -p 2>/dev/null) || cs_ok=0
            if [ "$cs_ok" -eq 1 ]; then
              bh=$(printf '%s' "$cs_pane" | cksum)
            else
              bh="capture-failed-$elapsed"
            fi
            bl_prev=$(bl_get "$tk")
            bl_pts=""; bl_phash=""; bl_pcount=0
            if [ -n "$bl_prev" ]; then
              bl_pts=$(printf '%s' "$bl_prev" | awk -F "$bl_tab" '{print $1}')
              bl_phash=$(printf '%s' "$bl_prev" | awk -F "$bl_tab" '{print $2}')
              bl_pcount=$(printf '%s' "$bl_prev" | awk -F "$bl_tab" '{print $3}')
            fi
            if [ "$bl_pts" = "$bts" ] && [ "$bl_phash" = "$bh" ]; then
              bl_count=$((bl_pcount+1))
            else
              bl_count=1
            fi
            bl_state=$(bl_put "$tk" "$bts" "$bh" "$bl_count")
            if [ "$bl_count" -ge 2 ]; then
              breason=$("$JQ" -r '.reason // "?"' "$bdir/$tk.json" 2>/dev/null || echo "?")
              bdetail=$("$JQ" -r '.detail // ""' "$bdir/$tk.json" 2>/dev/null || echo "")
              bdetail=$(printf '%s' "$bdetail" | tr '\n' ' ' | cut -c1-120)
              blocked="${blocked}[watch] worker blocked — ${tk}:${sess} (${breason}: ${bdetail})
"
            fi
          fi
        fi
        # Per-session stall check: only rc 1 marks a stall. rc 0 (progressing),
        # rc 2 (unknown), or a broken script are all NOT stalled — the explicit
        # rc capture means no failure here can abort the watch loop.
        # Extra gate vs. the dead-worker check above: a task at/above the
        # target is never stall-checked (#88) — its silence is exactly what
        # the session prompt ordered ("signal and wait"), not a wedged worker.
        # ar_pressed: an Enter just sent for this task this poll skips the
        # stall verdict this poll only — the pane hash it would check is from
        # before the repair.
        if [ "$ar_pressed" -eq 0 ] && [ "$r" -lt "$target_rank" ] && [ -n "$STALL_SCRIPT" ] && [ -n "$TMUX_BIN" ] && [ -n "$sess" ]; then
          src=0; sh "$STALL_SCRIPT" "$sess" >/dev/null 2>&1 || src=$?
          if [ "$src" -eq 1 ]; then stalled="$stalled $tk:$sess"; fi
        fi
        ;;
    esac
    [ "$r" -ge "$target_rank" ] && done_count=$((done_count+1))
  done
  echo "[watch ->$target] $done_count/$expected |$summary"
  [ "$failed" -gt 0 ] && { echo "[watch] failed session detected — abort"; exit 3; }
  [ "$done_count" -ge "$expected" ] && { echo "[watch] all reached $target"; exit 0; }
  # A confirmed blocked worker outranks the stall heuristic — the harness
  # already told us why, so there's nothing left for the heuristic to guess.
  if [ -n "$blocked" ]; then
    printf '%s' "$blocked"
    exit 8
  fi
  # Stall is the weakest signal: failed(3), all-reached(0), and blocked(8) above win over it.
  if [ -n "$stalled" ]; then
    stmsg=""
    for se in $stalled; do
      setk=${se%%:*}; sesess=${se#*:}
      reason=$(classify_stall "$sesess")
      if [ -n "$reason" ]; then
        stmsg="$stmsg $setk:$sesess ($reason)"
      else
        stmsg="$stmsg $setk:$sesess"
      fi
    done
    echo "[watch] worker stalled —$stmsg"
    exit 7
  fi
  sleep "$interval"; elapsed=$((elapsed+interval))
done
echo "[watch] TIMEOUT (${budget}s, source=${budget_src}):$summary"; exit 2
