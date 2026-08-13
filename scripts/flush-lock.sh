#!/bin/sh
# flush-lock.sh — shared owner-token lock serializing both knowledge-flush
# entry points (the manual /dev-loop:knowledge-flush skill and the
# hooks/auto-flush.sh Stop hook). See issue #77.
#
# mkdir is the acquire primitive (portable — flock(1) is util-linux-only and
# absent on macOS). The lock dir holds one file, "owner", containing
# "<runid> <pid> <epoch>". Release deletes the lock only when the caller's
# run id matches the recorded owner, so a stale caller can never delete the
# next holder's lock (see wiki/backend/common/concurrency/distributed-locks.md).
#
# usage:
#   flush-lock.sh acquire   # mkdir the lock; on success writes the owner file
#                            # and exits 0 ("acquired <runid>" / "reclaimed <runid>").
#                            # exits 3 ("held ...") when another run holds it.
#   flush-lock.sh release   # removes the lock iff this run id is the owner.
#                            # exits 4 ("refused: ...") when it is not.
#                            # exits 0 when no lock is present (already released).
#   flush-lock.sh holder    # prints the owner line; exit 0 held / exit 1 free.
#
# env overrides (mainly for tests / non-standard layouts):
#   DEV_LOOP_FLUSH_LOCK      lock dir path (default: $HOME/.dev-loop/.flush.lock)
#   DEV_LOOP_FLUSH_RUN_ID    this run's id (default: <timestamp>-<pid>)
#   DEV_LOOP_FLUSH_LOCK_TTL  seconds before a lock is stale-reclaimable (default: 900)
set -eu

LOCK="${DEV_LOOP_FLUSH_LOCK:-$HOME/.dev-loop/.flush.lock}"
RUNID="${DEV_LOOP_FLUSH_RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
TTL="${DEV_LOOP_FLUSH_LOCK_TTL:-900}"

usage() {
  echo "usage: flush-lock.sh acquire|release|holder" >&2
  exit 2
}

# Reads "$LOCK/owner" into H_RUNID/H_PID/H_EPOCH. Sets OWNER_OK=1 only for a
# well-formed line (numeric epoch) — a missing, empty, or malformed owner file
# leaves OWNER_OK=0 so the caller treats the lock as infinitely stale rather
# than wedging on a file it cannot parse.
_owner_fields() {
  H_RUNID=""
  H_PID=""
  H_EPOCH=""
  OWNER_OK=0
  if [ -f "$LOCK/owner" ]; then
    read -r H_RUNID H_PID H_EPOCH < "$LOCK/owner" 2>/dev/null || true
    case "$H_EPOCH" in
      '' | *[!0-9]*) OWNER_OK=0 ;;
      *) OWNER_OK=1 ;;
    esac
  fi
}

# $1 = pid. True only for a well-formed, live pid; a malformed or empty pid
# field never crashes this check — it is simply "not alive".
_pid_alive() {
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
  esac
  kill -0 "$1" 2>/dev/null
}

_write_owner() {
  printf '%s %s %s\n' "$RUNID" "$$" "$(date +%s)" > "$LOCK/owner"
}

cmd_acquire() {
  if mkdir "$LOCK" 2>/dev/null; then
    _write_owner
    echo "acquired $RUNID"
    exit 0
  fi

  _owner_fields

  # Re-entrant: this caller already holds the lock (same run id). A run
  # commonly spans more than one process under one run id — e.g.
  # hooks/auto-flush.sh acquires, then exports DEV_LOOP_FLUSH_RUN_ID into the
  # headless session it spawns, and that session's own step-0 acquire must
  # not see itself as a foreign holder. Refresh the epoch and continue rather
  # than falling into the held/reclaim logic below. A different run id still
  # goes through that logic unchanged.
  if [ -n "$H_RUNID" ] && [ "$H_RUNID" = "$RUNID" ]; then
    _write_owner
    echo "already-owned $RUNID"
    exit 0
  fi

  if [ "$OWNER_OK" = 1 ]; then
    now=$(date +%s)
    age=$((now - H_EPOCH))
  else
    age=999999999
  fi

  if [ "$age" -le "$TTL" ] || _pid_alive "$H_PID"; then
    echo "held ${H_RUNID:-unknown} ${age}s" >&2
    exit 3
  fi

  # Past TTL and the recorded pid is not alive: reclaim.
  rm -rf "$LOCK"
  if mkdir "$LOCK" 2>/dev/null; then
    _write_owner
    echo "reclaimed $RUNID"
    exit 0
  fi
  echo "held (reclaim raced)" >&2
  exit 3
}

cmd_release() {
  [ -d "$LOCK" ] || exit 0
  _owner_fields
  if [ "$H_RUNID" = "$RUNID" ]; then
    rm -rf "$LOCK"
    exit 0
  fi
  echo "refused: lock owned by ${H_RUNID:-unknown}" >&2
  exit 4
}

cmd_holder() {
  if [ -f "$LOCK/owner" ]; then
    cat "$LOCK/owner"
    exit 0
  fi
  exit 1
}

case "${1:-}" in
  acquire) cmd_acquire ;;
  release) cmd_release ;;
  holder) cmd_holder ;;
  *) usage ;;
esac
