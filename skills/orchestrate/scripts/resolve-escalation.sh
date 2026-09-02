#!/bin/sh
# resolve-escalation.sh — clear a guardrails escalation record for a task,
# and optionally deliver the coordinator's verdict to the waiting worker in
# the same pre-approved call (see SKILL.md exit-5 playbook).
#
# usage: resolve-escalation.sh <escalations-dir> <task-id> [<session> <message>]
#   <escalations-dir>   directory of watch-status.sh escalation records
#                        (*.json files, each carrying a .taskId field)
#   <task-id>            delete every record in <escalations-dir> whose
#                        .taskId equals this
#   <session> <message>  optional pair: after clearing, deliver <message> to
#                        <session> via the sibling send-prompt.sh (never raw
#                        tmux send-keys)
#
# Matching is by the record's .taskId field, never by filename — records are
# named <ts>-<pid>.json and carry the task id inside (watch-status.sh:169-198).
# A record jq cannot parse is left in place and named on stderr; it does not
# count as matched.
#
# Order is always clear THEN deliver (SKILL.md's exit-5 contract): if nothing
# was cleared, no delivery is attempted — there is nothing pending to answer.
#
# stdout is exactly one line on every non-usage exit: cleared=<n> delivered=<0|1>
#
# exit 0   cleared (and delivered, if requested)
# exit 2   usage error / <escalations-dir> is not a directory / <task-id> is
#          not [A-Za-z0-9_-]+
# exit 3   no record matched <task-id> — nothing deleted, nothing delivered
# exit 6   record(s) cleared but delivery failed — retry directly with:
#          sh $(dirname "$0")/send-prompt.sh send <session> <message>
# exit 127 jq not found
set -eu
JQ=$(command -v jq) || { echo "resolve-escalation: jq not found" >&2; exit 127; }

usage() {
  echo "usage: resolve-escalation.sh <escalations-dir> <task-id> [<session> <message>]" >&2
  exit 2
}

[ $# -eq 2 ] || [ $# -eq 4 ] || usage

dir="$1"
task="$2"
sess="${3:-}"
msg="${4:-}"

[ -d "$dir" ] || { echo "resolve-escalation: '$dir' is not a directory" >&2; exit 2; }

case "$task" in
  ''|*[!A-Za-z0-9_-]*)
    echo "resolve-escalation: invalid task-id '$task' (allowed: A-Z a-z 0-9 _ -)" >&2
    exit 2 ;;
esac

cleared=0
for f in "$dir"/*.json; do
  [ -f "$f" ] || continue
  if ! tid=$("$JQ" -r '.taskId // empty' "$f" 2>/dev/null); then
    echo "resolve-escalation: skipping unparseable record '$f'" >&2
    continue
  fi
  [ "$tid" = "$task" ] || continue
  rm -f "$f"
  cleared=$((cleared + 1))
done

if [ "$cleared" -eq 0 ]; then
  echo "cleared=0 delivered=0"
  echo "resolve-escalation: no escalation record found for task '$task' in '$dir'" >&2
  exit 3
fi

delivered=0
if [ -n "$sess" ]; then
  if sh "$(dirname "$0")/send-prompt.sh" send "$sess" "$msg"; then
    delivered=1
  else
    rc=$?
    echo "cleared=$cleared delivered=0"
    echo "resolve-escalation: cleared $cleared record(s) but delivery failed (send-prompt exit $rc) — retry with: sh $(dirname "$0")/send-prompt.sh send $sess \"$msg\"" >&2
    exit 6
  fi
fi

echo "cleared=$cleared delivered=$delivered"
