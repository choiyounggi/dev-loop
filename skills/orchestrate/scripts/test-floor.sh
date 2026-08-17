#!/bin/sh
# test-floor.sh — mechanical pre-gate in front of the test-quality-auditor.
#
# Judges the COUNTABLE half of test quality only: tests exist, each NEW test
# file has >=3 cases, each case has >=1 assertion. Semantic quality (whether
# an assertion is meaningful, error/boundary CLASSIFICATION) stays with the
# auditor — this script never runs it, only counts.
#
# usage: test-floor.sh <repo-dir> <diff-range>
#
# exit 0  stdout `pass`    — floor met
# exit 3  stdout `fail`    — floor failed; stderr: one reason per line, each
#                            `no-tests` | `case-count:<file>:<n>` |
#                            `no-assertion:<file>:<case>`
# exit 2  stdout `unknown` — every new test file the floor needed was
#                            unrecognized by the framework table; caller
#                            proceeds to the auditor with full scope
# exit 4  stdout (nothing) — bad args / repo-dir / diff-range; reason on stderr
#
# Read-only: never executes tests, never writes files. Runtime deps: sh + git
# + grep/awk only — no jq, no bash arrays, no GNU-only flags (must run on
# macOS BSD userland and Linux CI alike).
set -u

CASE_MIN=3
TAB=$(printf '\t')

repo="${1:-}"; range="${2:-}"
[ -n "$repo" ] && [ -n "$range" ] || {
  echo "test-floor: usage: test-floor.sh <repo-dir> <diff-range>" >&2; exit 4; }
[ -d "$repo" ] || { echo "test-floor: repo-dir '$repo' not found" >&2; exit 4; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "test-floor: '$repo' is not a git repository" >&2; exit 4; }

name_status=$(git -C "$repo" diff --name-status "$range" 2>/dev/null) || {
  echo "test-floor: diff range '$range' did not resolve" >&2; exit 4; }

# classify $1=path -> test|doc|config|source (D3: first match wins)
classify() {
  p="$1"; b=$(basename "$p")
  case "$b" in
    *.bats) echo test; return ;;
    test_*.py) echo test; return ;;
    *_test.py) echo test; return ;;
    *_test.go) echo test; return ;;
    *.test.js|*.test.jsx|*.test.ts|*.test.tsx|*.test.mjs|*.test.cjs) echo test; return ;;
    *.spec.js|*.spec.jsx|*.spec.ts|*.spec.tsx|*.spec.mjs|*.spec.cjs) echo test; return ;;
  esac
  case "/$p/" in
    */tests/*|*/test/*|*/__tests__/*) echo test; return ;;
  esac
  case "$b" in
    *.md|*.txt|*.rst|LICENSE*) echo doc; return ;;
  esac
  case "/$p/" in */docs/*) echo doc; return ;; esac
  case "$b" in
    *.json|*.yml|*.yaml|*.toml|*.ini|*.cfg|*.lock) echo config; return ;;
    .*) echo config; return ;;
  esac
  echo source
}

# framework_of $1=path -> bats|jest|pytest|go|unknown (D7/D8)
framework_of() {
  b=$(basename "$1")
  case "$b" in
    *.bats) echo bats; return ;;
    test_*.py) echo pytest; return ;;
    *_test.py) echo pytest; return ;;
    *_test.go) echo go; return ;;
    *.test.js|*.test.jsx|*.test.ts|*.test.tsx|*.test.mjs|*.test.cjs) echo jest; return ;;
    *.spec.js|*.spec.jsx|*.spec.ts|*.spec.tsx|*.spec.mjs|*.spec.cjs) echo jest; return ;;
  esac
  echo unknown
}

# analyze_* $1=working-tree path $2=diff path (for reason labels) -> stdout:
# zero or more of `case-count:$2:<n>` / `no-assertion:$2:<name>`, one per line.
analyze_bats() {
  awk -v file="$2" -v casemin="$CASE_MIN" '
    function reset() { name = ""; has_assert = 0; has_bracket = 0; has_run = 0; has_status = 0 }
    function check() { if (!(has_assert || has_bracket || (has_run && has_status)))
                          printf "no-assertion:%s:%s\n", file, name }
    BEGIN { in_case = 0; n = 0; reset() }
    /^@test/ {
      if (in_case) { n++; check() }
      in_case = 1; reset()
      line = $0
      q1 = index(line, "\"")
      if (q1 > 0) {
        rest = substr(line, q1 + 1); q2 = index(rest, "\"")
        name = (q2 > 0) ? substr(rest, 1, q2 - 1) : rest
      } else { name = "(unnamed)" }
      next
    }
    {
      if (in_case) {
        if ($0 ~ /assert/) has_assert = 1
        if ($0 ~ /^[ \t]*\[\[?[ \t]/) has_bracket = 1
        if ($0 ~ /^[ \t]*run[ \t]/) has_run = 1
        if ($0 ~ /status/) has_status = 1
      }
    }
    END { if (in_case) { n++; check() }; if (n < casemin) printf "case-count:%s:%d\n", file, n }
  ' "$1"
}

analyze_jest() {
  awk -v file="$2" -v casemin="$CASE_MIN" '
    function check() { if (!has_expect) printf "no-assertion:%s:%s\n", file, name }
    BEGIN { in_case = 0; n = 0; name = ""; has_expect = 0 }
    /^[ \t]*(it|test)\(/ {
      if (in_case) { n++; check() }
      in_case = 1; has_expect = 0; name = "(unnamed)"
      line = $0
      if (match(line, /["`]|\047/)) {
        q = substr(line, RSTART, 1); rest = substr(line, RSTART + 1)
        e = index(rest, q)
        if (e > 0) name = substr(rest, 1, e - 1)
      }
      next
    }
    { if (in_case && $0 ~ /expect\(/) has_expect = 1 }
    END { if (in_case) { n++; check() }; if (n < casemin) printf "case-count:%s:%d\n", file, n }
  ' "$1"
}

analyze_pytest() {
  awk -v file="$2" -v casemin="$CASE_MIN" '
    function check() { if (!ok) printf "no-assertion:%s:%s\n", file, name }
    BEGIN { in_case = 0; n = 0; name = ""; ok = 0 }
    /^[ \t]*def[ \t]+test_/ {
      if (in_case) { n++; check() }
      in_case = 1; ok = 0
      line = $0
      sub(/^[ \t]*def[ \t]+/, "", line)
      p = index(line, "(")
      name = (p > 0) ? substr(line, 1, p - 1) : line
      next
    }
    { if (in_case && ($0 ~ /assert[ \t]/ || $0 ~ /pytest\.raises/)) ok = 1 }
    END { if (in_case) { n++; check() }; if (n < casemin) printf "case-count:%s:%d\n", file, n }
  ' "$1"
}

analyze_go() {
  awk -v file="$2" -v casemin="$CASE_MIN" '
    function check() { if (!ok) printf "no-assertion:%s:%s\n", file, name }
    BEGIN { in_case = 0; n = 0; name = ""; ok = 0 }
    /^func Test/ {
      if (in_case) { n++; check() }
      in_case = 1; ok = 0
      line = $0
      sub(/^func /, "", line)
      p = index(line, "(")
      name = (p > 0) ? substr(line, 1, p - 1) : line
      next
    }
    { if (in_case && ($0 ~ /t\.Error/ || $0 ~ /t\.Fatal/ || $0 ~ /require\./ || $0 ~ /assert\./)) ok = 1 }
    END { if (in_case) { n++; check() }; if (n < casemin) printf "case-count:%s:%d\n", file, n }
  ' "$1"
}

source_count=0
test_count=0
new_test_files=""

if [ -n "$name_status" ]; then
  while IFS="$TAB" read -r st path; do
    [ -n "$st" ] || continue
    is_new=0
    case "$st" in
      A) is_new=1 ;;
      M) is_new=0 ;;
      *) continue ;;  # D, R###, C###, T, U, X, B — not counted (out of scope)
    esac
    cls=$(classify "$path")
    case "$cls" in
      test)
        test_count=$((test_count + 1))
        [ "$is_new" = 1 ] && new_test_files="${new_test_files}${path}
"
        ;;
      source) source_count=$((source_count + 1)) ;;
    esac
  done <<NAMESTATUS
$name_status
NAMESTATUS
fi

reasons=""
[ "$source_count" -gt 0 ] && [ "$test_count" -eq 0 ] && reasons="no-tests
"

recognized_count=0
unknown_count=0
unknown_notes=""

if [ -n "$new_test_files" ]; then
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    fw=$(framework_of "$path")
    fpath="$repo/$path"
    if [ "$fw" = unknown ] || [ ! -f "$fpath" ]; then
      unknown_count=$((unknown_count + 1))
      unknown_notes="${unknown_notes}unclassified:${path}
"
      continue
    fi
    recognized_count=$((recognized_count + 1))
    case "$fw" in
      bats) out=$(analyze_bats "$fpath" "$path") ;;
      jest) out=$(analyze_jest "$fpath" "$path") ;;
      pytest) out=$(analyze_pytest "$fpath" "$path") ;;
      go) out=$(analyze_go "$fpath" "$path") ;;
    esac
    [ -n "$out" ] && reasons="${reasons}${out}
"
  done <<NEWTESTS
$new_test_files
NEWTESTS
fi

if [ -n "$reasons" ]; then
  printf '%s' "$reasons" >&2
  echo fail
  exit 3
fi

if [ "$unknown_count" -gt 0 ]; then
  printf '%s' "$unknown_notes" >&2
  if [ "$recognized_count" -eq 0 ] && [ "$source_count" -gt 0 ]; then
    echo unknown
    exit 2
  fi
  echo pass
  exit 0
fi

echo pass
exit 0
