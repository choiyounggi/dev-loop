#!/bin/sh
# wiki-contradiction.sh — record an implement-time wiki falsification candidate in log.md
#
# usage: wiki-contradiction.sh --page <page-id> --row <n|directive> --task <task-id> \
#          --count <n> --verify "<cmd>" --output "<excerpt>" [--log <path>]
#
# Appends ONE line to log.md (never creates, truncates or rewrites it):
#   ## [YYYY-MM-DD] contradiction | <page-id> row <row> — task <task>: verify `<cmd>` failed <count>x -> <excerpt>
# only when every evidence field is non-empty AND --count is an integer >= 2.
# loop-implement rule 4 requires the WIKI: line and two same-row Verify failures
# to be in the task report already; this script checks the evidence structurally
# (fields present, count >= 2) and trusts the caller's count.
#
# stdout: exactly one token   written | refused
# exit:   0 written | 2 usage (stderr: usage line) | 3 refused (stderr: the
#         missing field or the count) | 4 log file missing (stderr: the path)
# log path: --log, else $DEV_LOOP_LOG_MD, else <plugin root>/log.md where
#   HERE=$(cd "$(dirname "$0")" && pwd -P)  (as scripts/graph-workspace.sh)
#   ROOT=$(cd "$HERE/.." && pwd -P)
# No CLAUDE_* variable is read: they are unset in Bash-tool commands and bats.
set -eu

usage() {
  printf 'usage: wiki-contradiction.sh --page <id> --row <n|directive> --task <id> --count <n> --verify "<cmd>" --output "<excerpt>" [--log <path>]\n' >&2
  exit 2
}

HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT=$(cd "$HERE/.." && pwd -P)

page= row= task= count= verify= output= log=
[ $# -gt 0 ] || usage
while [ $# -gt 0 ]; do
  case $1 in
    --page)   [ $# -ge 2 ] || usage; page=$2;   shift 2 ;;
    --row)    [ $# -ge 2 ] || usage; row=$2;    shift 2 ;;
    --task)   [ $# -ge 2 ] || usage; task=$2;   shift 2 ;;
    --count)  [ $# -ge 2 ] || usage; count=$2;  shift 2 ;;
    --verify) [ $# -ge 2 ] || usage; verify=$2; shift 2 ;;
    --output) [ $# -ge 2 ] || usage; output=$2; shift 2 ;;
    --log)    [ $# -ge 2 ] || usage; log=$2;    shift 2 ;;
    *) usage ;;
  esac
done

refuse() {
  printf 'refused\n'
  printf 'wiki-contradiction: %s\n' "$1" >&2
  exit 3
}

[ -n "$page" ]   || refuse 'missing --page (the WIKI: line must name the page id)'
[ -n "$row" ]    || refuse 'missing --row (the WIKI: line must name the row or directive)'
[ -n "$task" ]   || refuse 'missing --task'
[ -n "$verify" ] || refuse 'missing --verify (the failing Verify command)'
[ -n "$output" ] || refuse 'missing --output (the actual failure output)'
case $count in
  ''|*[!0-9]*) refuse "count must be an integer >= 2, got '$count'" ;;
esac
[ "$count" -ge 2 ] || refuse "count $count is below 2: one failure is a retry, not a falsification candidate"

[ -n "$log" ] || log=${DEV_LOOP_LOG_MD:-$ROOT/log.md}
if [ ! -f "$log" ]; then
  printf 'refused\n'
  printf 'wiki-contradiction: log file not found at %s (never created here)\n' "$log" >&2
  exit 4
fi

excerpt=$(printf '%s' "$output" | tr '\n\t' '  ' | cut -c1-300)
today=$(date -u +%Y-%m-%d)
printf '## [%s] contradiction | %s row %s — task %s: verify `%s` failed %sx -> %s\n' \
  "$today" "$page" "$row" "$task" "$verify" "$count" "$excerpt" >> "$log"
printf 'written\n'
exit 0
