#!/bin/sh
# token-report.sh — per-session + total token usage report from Claude Code
# session transcript JSONL files (Claude Code writes these under
# ~/.claude/projects/<escaped-cwd>/). Read at orchestration run teardown to
# audit a run's token efficiency: calls, output tokens, cache hit %, and
# final/peak context per session.
#
# usage: token-report.sh [--cwd <project-dir>] <file-or-dir>...
#   <file-or-dir>       a .jsonl transcript, or a directory (its *.jsonl
#                       files, non-recursive). At least one is required.
#                       An ABSOLUTE file-or-dir is used as-is; a RELATIVE
#                       one is resolved against the --cwd mapping below (or
#                       taken as relative to the caller's cwd if --cwd was
#                       not given).
#   --cwd <project-dir> an absolute project/worktree path, mapped to
#                       ~/.claude/projects/<escaped> — the directory Claude
#                       Code writes that project's session transcripts
#                       under. <escaped> is <project-dir> with every `/`
#                       and `.` replaced by `-`. Typical use at teardown:
#                       `token-report.sh --cwd "$PWD" .`
#
# exit 0   report printed: table on stdout, peak-context warnings on stderr
# exit 2   usage error — no sources given, a source path that does not
#          exist, or (when --cwd is given) its mapped directory does not
#          exist (stderr names the attempted path)
# exit 4   malformed LO_CTX_WARN (non-numeric or <= 0) — refused, never
#          silently defaulted
# exit 127 jq not found
#
# metrics (one row per session = one .jsonl source file):
#   calls      count of JSONL lines carrying a `.message.usage` object. A
#              line that fails to parse as JSON, or parses but has no
#              `.message.usage`, is skipped — not an error.
#   out        sum of output_tokens across those lines
#   hit%       sum(cache_read_input_tokens) /
#              sum(input_tokens + cache_read_input_tokens +
#              cache_creation_input_tokens) * 100, one decimal;
#              "0.0" when the denominator is 0
#   final_ctx  input+cache_read+cache_creation of the LAST usage line
#   peak_ctx   max input+cache_read+cache_creation across usage lines
# TOTAL row: calls/out are sums across sessions; hit% is recomputed from
#   the summed token counts (not averaged); final_ctx/peak_ctx are the MAX
#   across sessions (not summed).
#
# env:
#   LO_CTX_WARN  peak-context warning threshold (default 300000). After the
#                table, every session whose peak_ctx >= this threshold gets
#                one `warn: ...` line on stderr. Empty/unset = default; a
#                non-numeric or <= 0 value is refused at exit 4 rather than
#                silently falling back to the default.
set -eu

JQ=$(command -v jq) || { echo "token-report: jq not found" >&2; exit 127; }

usage() { echo "usage: token-report.sh [--cwd <project-dir>] <file-or-dir>..." >&2; }

# ---- --cwd: map an absolute project path to its transcript directory ------
cwd_map=""
if [ "${1:-}" = "--cwd" ]; then
  if [ $# -lt 2 ]; then usage; exit 2; fi
  proj="$2"; shift 2
  escaped=$(printf '%s' "$proj" | tr '/.' '-')
  cwd_map="$HOME/.claude/projects/$escaped"
  if [ ! -d "$cwd_map" ]; then
    echo "token-report: --cwd mapped directory not found: '$cwd_map' (from '$proj')" >&2
    exit 2
  fi
fi

if [ $# -lt 1 ]; then usage; exit 2; fi

# ---- LO_CTX_WARN: default 300000; refuse (exit 4) rather than silently
# default on a non-numeric or non-positive value ----------------------------
warn_threshold="${LO_CTX_WARN:-}"
if [ -z "$warn_threshold" ]; then
  warn_threshold=300000
else
  case "$warn_threshold" in
    *[!0-9]*)
      echo "token-report: invalid LO_CTX_WARN '$warn_threshold' (must be a positive integer)" >&2
      exit 4 ;;
  esac
  if [ "$warn_threshold" -le 0 ]; then
    echo "token-report: invalid LO_CTX_WARN '$warn_threshold' (must be > 0)" >&2
    exit 4
  fi
fi

# ---- resolve each positional arg to one or more .jsonl source files -------
# $1 = raw arg -> stdout: one resolved path per line. Exits 2 if it does not
# exist. A directory yields its immediate *.jsonl files (sorted, non-recursive).
resolve_source() {
  arg="$1"
  case "$arg" in
    /*) path="$arg" ;;
    *)  if [ -n "$cwd_map" ]; then path="$cwd_map/$arg"; else path="$arg"; fi ;;
  esac
  if [ ! -e "$path" ]; then
    echo "token-report: source not found: '$path'" >&2
    exit 2
  fi
  if [ -d "$path" ]; then
    find "$path" -maxdepth 1 -type f -name '*.jsonl' | sort
  else
    printf '%s\n' "$path"
  fi
}

sources=$(
  for arg in "$@"; do
    resolve_source "$arg"
  done
)

# ---- per-session metrics ----------------------------------------------
# $1 = file path -> stdout: one TSV line "calls out in cread ccreate final_ctx peak_ctx".
# jq confirms/parses each line and extracts the 4 usage fields (skipping a
# line that isn't valid JSON, or lacks .message.usage, rather than failing);
# awk does the integer aggregation (sums, running max, last-line capture).
session_metrics() {
  "$JQ" -R -r '
    (fromjson? // empty) as $obj
    | ($obj.message.usage? // empty) as $u
    | [($u.input_tokens // 0), ($u.cache_read_input_tokens // 0),
       ($u.cache_creation_input_tokens // 0), ($u.output_tokens // 0)]
    | @tsv
  ' "$1" | awk -F'\t' '
    {
      in_s = $1 + 0; cr = $2 + 0; cc = $3 + 0; out = $4 + 0
      ctx = in_s + cr + cc
      calls++; out_sum += out; in_sum += in_s; cr_sum += cr; cc_sum += cc
      final_ctx = ctx
      if (ctx > peak_ctx) peak_ctx = ctx
    }
    END {
      printf "%d\t%d\t%d\t%d\t%d\t%d\t%d\n", calls + 0, out_sum + 0, in_sum + 0, cr_sum + 0, cc_sum + 0, final_ctx + 0, peak_ctx + 0
    }
  '
}

# $1 = numerator $2 = denominator -> "N.N" (one decimal; "0.0" when denom is 0)
pct1() {
  "$JQ" -nr --argjson n "$1" --argjson d "$2" '
    if $d == 0 then "0.0"
    else
      (($n * 1000 / $d) | round) as $tenths
      | ($tenths / 10 | floor) as $whole
      | ($tenths - ($whole * 10)) as $frac
      | "\($whole).\($frac)"
    end
  '
}

printf 'SESSION\tCALLS\tOUT\tHIT%%\tFINAL_CTX\tPEAK_CTX\n'

calls_total=0; out_total=0; in_total=0; cr_total=0; cc_total=0
final_max=0; peak_max=0
warnings=""

if [ -n "$sources" ]; then
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    name=$(basename "$file")
    case "$name" in *.jsonl) name="${name%.jsonl}" ;; esac

    metrics=$(session_metrics "$file")
    calls=$(printf '%s' "$metrics" | cut -f1)
    out=$(printf '%s' "$metrics" | cut -f2)
    in_s=$(printf '%s' "$metrics" | cut -f3)
    cr=$(printf '%s' "$metrics" | cut -f4)
    cc=$(printf '%s' "$metrics" | cut -f5)
    final_ctx=$(printf '%s' "$metrics" | cut -f6)
    peak_ctx=$(printf '%s' "$metrics" | cut -f7)

    hit=$(pct1 "$cr" "$((in_s + cr + cc))")
    printf '%s\t%d\t%d\t%s\t%d\t%d\n' "$name" "$calls" "$out" "$hit" "$final_ctx" "$peak_ctx"

    calls_total=$((calls_total + calls))
    out_total=$((out_total + out))
    in_total=$((in_total + in_s))
    cr_total=$((cr_total + cr))
    cc_total=$((cc_total + cc))
    [ "$final_ctx" -gt "$final_max" ] && final_max=$final_ctx
    [ "$peak_ctx" -gt "$peak_max" ] && peak_max=$peak_ctx

    if [ "$peak_ctx" -ge "$warn_threshold" ]; then
      warnings="${warnings}warn: $name peak context $peak_ctx >= $warn_threshold — consider phase-boundary /compact or delegating large reads
"
    fi
  done <<SOURCES_EOF
$sources
SOURCES_EOF
fi

hit_total=$(pct1 "$cr_total" "$((in_total + cr_total + cc_total))")
printf 'TOTAL\t%d\t%d\t%s\t%d\t%d\n' "$calls_total" "$out_total" "$hit_total" "$final_max" "$peak_max"

if [ -n "$warnings" ]; then
  printf '%s' "$warnings" >&2
fi

exit 0
