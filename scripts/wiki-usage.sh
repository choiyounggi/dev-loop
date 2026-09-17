#!/bin/sh
# wiki-usage.sh — append WIKI: usage records to <repo>/.dev-loop/wiki-usage.jsonl
#
# usage: wiki-usage.sh --task <task-id> [--repo <dir>] [--source report|plan] [--line "<text>"]...
#        With no --line, every non-empty stdin line is a record.
#
# Each accepted line becomes ONE JSON object appended to
#   <repo>/.dev-loop/wiki-usage.jsonl   (repo = --repo, else $PWD; .dev-loop/ is created)
#   {"ts":"YYYY-MM-DDTHH:MM:SSZ","page_id":"<id>","row":"<text>","task":"<id>","source":"report|plan"}
# Line grammar (a leading `WIKI:` label and surrounding blanks are stripped first):
#   <page-id> → <row/directive>        (U+2192, as the loop-implement report template)
#   <page-id> -> <row/directive>       (ASCII)
#   wiki/<domain>/<category>/<page>.md  only with --source plan: page_id <domain>-<category>-<page>, row "Wiki basis"
# page-id must match ^[a-z0-9-]+$ and row must be non-empty.
# Every line is validated BEFORE anything is written; one bad line refuses the whole call.
#
# stdout: exactly one token   appended | refused
# exit:   0 appended | 2 usage (stderr: usage line) | 3 refused (stderr: the offending line)
#         | 4 --repo is not a directory (stderr: the value)
# The lint side is scripts/wiki-lint-usage.js (wiki-lint check 18).
# No CLAUDE_* variable is read: they are unset in Bash-tool commands and bats.
set -eu

usage() {
  printf 'usage: wiki-usage.sh --task <id> [--repo <dir>] [--source report|plan] [--line "<text>"]...\n' >&2
  exit 2
}
refuse() {
  printf 'refused\n'
  printf 'wiki-usage: %s\n' "$1" >&2
  exit 3
}
esc() {
  printf '%s' "$1" | tr '\n\t' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g'
}
trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

task= repo= source=report lines=
[ $# -gt 0 ] || usage
while [ $# -gt 0 ]; do
  case $1 in
    --task)   [ $# -ge 2 ] || usage; task=$2;   shift 2 ;;
    --repo)   [ $# -ge 2 ] || usage; repo=$2;   shift 2 ;;
    --source) [ $# -ge 2 ] || usage; source=$2; shift 2 ;;
    --line)   [ $# -ge 2 ] || usage; lines="$lines$2
"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$task" ] || usage
case $source in report|plan) ;; *) usage ;; esac
[ -n "$lines" ] || lines=$(cat)

if [ -n "$repo" ]; then
  if [ ! -d "$repo" ]; then
    printf 'refused\n'
    printf 'wiki-usage: --repo is not a directory: %s\n' "$repo" >&2
    exit 4
  fi
  repo=$(cd -- "$repo" && pwd -P)
else
  repo=$(pwd -P)
fi
target="$repo/.dev-loop/wiki-usage.jsonl"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
etask=$(esc "$task")

records= n=0
while IFS= read -r raw; do
  line=$(trim "$raw")
  [ -n "$line" ] || continue
  case $line in WIKI:*) line=$(trim "${line#WIKI:}") ;; esac
  page= row=
  case $line in
    *→*)  page=$(trim "${line%%→*}");  row=$(trim "${line#*→}") ;;
    *-\>*) page=$(trim "${line%%->*}"); row=$(trim "${line#*->}") ;;
    wiki/*.md)
      [ "$source" = plan ] || refuse "a bare wiki path needs --source plan: $raw"
      p=${line#wiki/}; p=${p%.md}; page=$(printf '%s' "$p" | tr '/' '-'); row='Wiki basis' ;;
    *) refuse "no page-id → row separator in: $raw" ;;
  esac
  case $page in ''|*[!a-z0-9-]*) refuse "page id must match ^[a-z0-9-]+\$ in: $raw" ;; esac
  [ -n "$row" ] || refuse "empty row/directive in: $raw"
  records="$records{\"ts\":\"$ts\",\"page_id\":\"$page\",\"row\":\"$(esc "$row")\",\"task\":\"$etask\",\"source\":\"$source\"}
"
  n=$((n + 1))
done <<EOF
$lines
EOF
[ "$n" -gt 0 ] || refuse 'no WIKI: line given'

mkdir -p "$repo/.dev-loop"
printf '%s' "$records" >> "$target"
printf 'appended\n'
exit 0
