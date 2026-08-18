#!/bin/sh
# ready-set.sh — which tasks may be dispatched right now?
#
# This is the Wave-barrier replacement. Waves made the whole batch wait for its
# slowest member; here a task is dispatchable the moment its own dependencies
# are approved and a slot is free, so a finished worker is refilled immediately.
#
# usage: ready-set.sh <graph.json> <status-dir> <cap>
#   <graph.json>  {"tasks":[{"id":"t1","deps":["t0"]}, ...]} — Phase 2 writes it.
#                 Only `id` and `deps` are read here; files/outputs/consumes are
#                 the coordinator's conflict-matrix fields.
#   <status-dir>  .orchestration/status — one <task>.json per task, `.phase`
#                 written by status-update.sh. A task with no file is `pending`.
#   <cap>         the coordinator's approved slot count. LO_MAX_SESSIONS, when
#                 set, is an UPPER BOUND on it, never a raise.
#
# exit 0  dispatch these (stdout: one task id per line, at most <free> of them)
# exit 2  nothing to dispatch, but tasks are in flight — wait for an event
# exit 3  nothing to dispatch, nothing in flight, unfinished tasks remain —
#         DEADLOCK (a failed dependency, a cycle, or a task whose rework
#         `.attempt` has reached LO_MAX_REWORK). Never wait on this: with no
#         worker running, no event can ever arrive. Report it.
# exit 4  the graph or the status dir could not be read, or an argument is
#         invalid — refuse rather than guess
# exit 5  every task is in a terminal state — the run is complete
# exit 127 jq not found
#
# A dependency counts as satisfied only at `approved` or higher, NOT at
# impl_done: a task that consumes an unreviewed interface has to be redone when
# rework changes that signature. This is the Wave model's "previous Wave fully
# approved" guarantee, narrowed from a global barrier to a per-task wait.
#
# env:
#   LO_MAX_SESSIONS  upper bound on <cap> (a tuning knob like LO_PHASE_TIMEOUTS)
#   LO_MAX_REWORK    rework budget: a task whose status `.attempt` >= this and
#                     whose phase is not approved/merged/done is failed-for-
#                     scheduling (default 3; exit-4 validated, same as LO_MAX_SESSIONS)
set -u

JQ=$(command -v jq) || { echo "ready-set: jq not found" >&2; exit 127; }

graph="${1:-}"; sdir="${2:-}"; cap="${3:-}"
[ -n "$graph" ] && [ -n "$sdir" ] && [ -n "$cap" ] || {
  echo "usage: ready-set.sh <graph.json> <status-dir> <cap>" >&2; exit 4; }
[ -f "$graph" ] || { echo "ready-set: graph '$graph' not found" >&2; exit 4; }
[ -d "$sdir" ]  || { echo "ready-set: status dir '$sdir' not found" >&2; exit 4; }

case "$cap" in ''|*[!0-9]*) echo "ready-set: cap must be a positive integer" >&2; exit 4 ;; esac
[ "$cap" -gt 0 ] || { echo "ready-set: cap must be > 0" >&2; exit 4; }

# LO_MAX_SESSIONS caps the cap. It is a ceiling the operator sets, so it lowers
# the coordinator's proposal and never raises it.
if [ -n "${LO_MAX_SESSIONS:-}" ]; then
  case "$LO_MAX_SESSIONS" in
    ''|*[!0-9]*) echo "ready-set: LO_MAX_SESSIONS must be a positive integer" >&2; exit 4 ;;
  esac
  [ "$LO_MAX_SESSIONS" -gt 0 ] || { echo "ready-set: LO_MAX_SESSIONS must be > 0" >&2; exit 4; }
  [ "$LO_MAX_SESSIONS" -lt "$cap" ] && cap="$LO_MAX_SESSIONS"
fi

# LO_MAX_REWORK is the rework budget: a task whose .attempt reaches it is
# failed-for-scheduling. Validated the same way as LO_MAX_SESSIONS — never
# silently defaulted on a bad value.
max_rework="${LO_MAX_REWORK:-3}"
case "$max_rework" in
  ''|*[!0-9]*) echo "ready-set: LO_MAX_REWORK must be a positive integer" >&2; exit 4 ;;
esac
[ "$max_rework" -gt 0 ] || { echo "ready-set: LO_MAX_REWORK must be > 0" >&2; exit 4; }

ids=$("$JQ" -r '.tasks[]?.id // empty' "$graph" 2>/dev/null) || {
  echo "ready-set: graph '$graph' is not valid JSON" >&2; exit 4; }

# `.tasks` absent is a malformed graph, not an empty one — tell them apart so a
# typo'd key cannot read as "nothing to do".
"$JQ" -e 'has("tasks") and (.tasks | type == "array")' "$graph" >/dev/null 2>&1 || {
  echo "ready-set: graph '$graph' has no .tasks array" >&2; exit 4; }

phase_of() { # $1 = task id -> its recorded phase, or "pending" when unrecorded
  f="$sdir/$1.json"
  [ -f "$f" ] || { echo pending; return; }
  p=$("$JQ" -r '.phase // "pending"' "$f" 2>/dev/null) || p=pending
  [ -n "$p" ] || p=pending
  echo "$p"
}

attempt_of() { # $1 = task id -> its recorded rework .attempt, or 0
  f="$sdir/$1.json"
  [ -f "$f" ] || { echo 0; return; }
  a=$("$JQ" -r '.attempt // 0' "$f" 2>/dev/null) || a=0
  case "$a" in ''|*[!0-9]*) a=0 ;; esac
  echo "$a"
}

is_satisfied() { # $1 = phase -> 0 when a dependent may start on it
  case "$1" in approved|merged|done) return 0 ;; *) return 1 ;; esac
}
is_terminal() {  # $1 = phase -> 0 when the task will never occupy a slot again
  case "$1" in approved|merged|done|failed) return 0 ;; *) return 1 ;; esac
}

busy=0; unfinished=0; ready=""
for id in $ids; do
  ph=$(phase_of "$id")
  if is_terminal "$ph"; then
    # `failed` is terminal for scheduling but is NOT completion: it leaves its
    # dependents permanently unreachable, which is what exit 3 exists to report.
    [ "$ph" = failed ] && unfinished=$((unfinished + 1))
    continue
  fi

  # A non-terminal task whose rework budget is exhausted is failed-for-
  # scheduling exactly like `failed` above: it never occupies a slot again
  # and permanently blocks its dependents. Checked strictly in the
  # non-terminal path so a `failed` task with a stale high attempt can never
  # be counted here too.
  att=$(attempt_of "$id")
  if [ "$att" -ge "$max_rework" ]; then
    echo "ready-set: $id rework budget exhausted (attempt=$att, max=$max_rework)" >&2
    unfinished=$((unfinished + 1))
    continue
  fi

  unfinished=$((unfinished + 1))
  if [ "$ph" != pending ]; then busy=$((busy + 1)); continue; fi

  deps=$("$JQ" -r --arg id "$id" '.tasks[] | select(.id == $id) | .deps[]? // empty' "$graph" 2>/dev/null)
  ok=1
  for d in $deps; do
    # A dep naming a task the graph does not define is a malformed graph, not an
    # unsatisfied edge — refuse instead of silently blocking that task forever.
    echo "$ids" | grep -qx "$d" || { echo "ready-set: task '$id' depends on unknown '$d'" >&2; exit 4; }
    is_satisfied "$(phase_of "$d")" || { ok=0; break; }
  done
  [ "$ok" = 1 ] && ready="$ready $id"
done

[ "$unfinished" -eq 0 ] && { echo "[ready-set] all tasks terminal"; exit 5; }

free=$((cap - busy))
[ "$free" -lt 0 ] && free=0

n=0
for id in $ready; do
  [ "$n" -ge "$free" ] && break
  echo "$id"; n=$((n + 1))
done
[ "$n" -gt 0 ] && exit 0

[ "$busy" -gt 0 ] && { echo "[ready-set] nothing dispatchable, $busy in flight — wait" >&2; exit 2; }

echo "[ready-set] DEADLOCK: $unfinished task(s) unfinished, none dispatchable, none running — a failed dependency or a cycle. Inspect the graph and status; do not wait." >&2
exit 3
