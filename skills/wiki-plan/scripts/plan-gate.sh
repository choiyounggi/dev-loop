#!/bin/sh
# plan-gate.sh — mechanical judge for Phase A/B plan gates (cycle-hardening design §3)
#
# Usage:
#   plan-gate.sh check <gate-id> <plan-dir> [<wiki-root>]   one gate -> stdout "ok"|"fail"
#   plan-gate.sh emit  <A|B> <plan-dir> <out-file>          write gates ledger from templates/plan-gates.md
#
# Gate ids (A): baseline-tests-ran affected-files-evidenced open-questions-resolved
#               constraints-surveyed research-evidenced
# Gate ids (B): groundings-exist decision-rows-complete reviewer-verdict
#
# Exit codes: 0 ok | 2 usage | 3 check failed (content defect, stderr itemizes)
#             4 target file/section missing (distinct from content missing)
#
# `check` always prints exactly one token to stdout ("ok" or "fail"); details
# go to stderr. `emit` prints nothing to stdout on success. POSIX sh only —
# no bashisms (matches skills/loop-implement/scripts/gate-check.sh's style).
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT_DEFAULT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT_DEFAULT}"

usage_exit() {
  echo "usage: plan-gate.sh check <gate-id> <plan-dir> [<wiki-root>]" >&2
  echo "       plan-gate.sh emit  <A|B> <plan-dir> <out-file>" >&2
  exit 2
}

ok() { echo ok; exit 0; }
fail3() { echo fail; echo "plan-gate: $1" >&2; exit 3; }
fail4() { echo fail; echo "plan-gate: $1" >&2; exit 4; }

# extract_l2 <file> <heading> — lines strictly between an exact "## <heading>"
# line and the next "## " line (or EOF). Nested "### " subsections stay in.
extract_l2() {
  awk -v hdr="$2" '
    $0 == hdr { flag=1; next }
    flag && /^## / { exit }
    flag { print }
  ' "$1"
}

# extract_l3 <file> <heading> — lines strictly between an exact "### <heading>"
# line and the next heading of any level (or EOF).
extract_l3() {
  awk -v hdr="$2" '
    $0 == hdr { flag=1; next }
    flag && /^#+ / { exit }
    flag { print }
  ' "$1"
}

# has_heading <file> <exact-heading-line>
has_heading() { grep -Fxq -- "$2" "$1"; }

# literal_replace <token> <value> — reads text on stdin, replaces every
# literal (non-regex) occurrence of <token>, writes to stdout.
literal_replace() {
  awk -v tok="$1" -v val="$2" '
    {
      line = $0
      out = ""
      while ((i = index(line, tok)) > 0) {
        out = out substr(line, 1, i - 1) val
        line = substr(line, i + length(tok))
      }
      print out line
    }
  '
}

# ------------------------------------------------------------- gate-A checks

check_baseline_tests_ran() { # <plan-dir>
  file="$1/analysis.md"
  [ -f "$file" ] || fail4 "analysis.md not found in $1"
  has_heading "$file" "## Ground truth" || fail4 "## Ground truth section missing in $file"
  line=$(extract_l2 "$file" "## Ground truth" | grep '^- Baseline: ' | head -1 || true)
  [ -n "$line" ] || fail4 "no '- Baseline: ' line under ## Ground truth in $file"
  cmd=$(printf '%s\n' "$line" | sed -e 's/^- Baseline: //' -e 's/ -> .*$//')
  [ -n "$cmd" ] || fail3 "could not parse a Baseline command from: $line"
  # Target presence + parseability only — plan-gate never executes the
  # Baseline command itself (design §3 D4). Execution belongs solely to the
  # emitted ledger's own `CHECK: {BASELINE_CMD} && echo GATE_OK` line, which
  # gate-check.sh --run executes under its own timeout/evidence handling.
  ok
}

check_affected_files_evidenced() { # <plan-dir>
  file="$1/analysis.md"
  [ -f "$file" ] || fail4 "analysis.md not found in $1"
  has_heading "$file" "### Affected files" || fail4 "### Affected files section missing in $file"
  bullets=$(extract_l3 "$file" "### Affected files" | grep '^- ' || true)
  [ -n "$bullets" ] || fail3 "### Affected files has no bullets"
  missing=$(printf '%s\n' "$bullets" | grep -v 'evidence:' || true)
  [ -z "$missing" ] || fail3 "bullet(s) missing an 'evidence:' token: $(printf '%s' "$missing" | head -1)"
  ok
}

check_open_questions_resolved() { # <plan-dir>
  file="$1/analysis.md"
  [ -f "$file" ] || fail4 "analysis.md not found in $1"
  has_heading "$file" "## Requirements" || fail4 "## Requirements section missing in $file"
  open=$(extract_l2 "$file" "## Requirements" | grep -c 'OPEN:' || true)
  [ "$open" -eq 0 ] || fail3 "$open unresolved OPEN: question(s) remain in ## Requirements"
  ok
}

check_constraints_surveyed() { # <plan-dir>
  file="$1/analysis.md"
  [ -f "$file" ] || fail4 "analysis.md not found in $1"
  has_heading "$file" "## Constraints" || fail4 "## Constraints section missing in $file"
  bullets=$(extract_l2 "$file" "## Constraints" | grep -c '^- ' || true)
  [ "$bullets" -ge 1 ] || fail3 "## Constraints has no bullets (use '- none — checked: <command>' if none apply)"
  ok
}

check_research_evidenced() { # <plan-dir>
  file="$1/analysis.md"
  [ -f "$file" ] || fail4 "analysis.md not found in $1"
  has_heading "$file" "## Research" || fail4 "## Research section missing in $file"
  section=$(extract_l2 "$file" "## Research")
  if printf '%s\n' "$section" | grep -qF 'no useful results — queries:'; then
    ok
  fi
  rows=$(printf '%s\n' "$section" | awk '
    /^\|/ {
      n++
      if (n == 1) next
      line = $0; gsub(/[-:| \t]/, "", line)
      if (line == "") next
      print
    }
  ')
  [ -n "$rows" ] || fail3 "## Research has no query/source data row and no 'no useful results — queries:' line"
  ok
}

# ------------------------------------------------------------- gate-B checks

_decision_rows() { # <design.md> — prints only data rows of ## Decisions table
  extract_l2 "$1" "## Decisions" | awk '
    /^\|/ {
      n++
      if (n == 1) next
      line = $0; gsub(/[-:| \t]/, "", line)
      if (line == "") next
      print
    }
  '
}

check_groundings_exist() { # <plan-dir> <wiki-root>
  file="$1/design.md"
  wiki_root="$2"
  [ -f "$file" ] || fail4 "design.md not found in $1"
  has_heading "$file" "## Decisions" || fail4 "## Decisions section missing in $file"
  rows=$(_decision_rows "$file")
  [ -n "$rows" ] || ok   # no decisions yet: decision-rows-complete gate owns that defect
  misses=""
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    basis=$(printf '%s\n' "$row" | awk -F'|' '{v=$5; gsub(/^[ \t]+|[ \t]+$/,"",v); print v}')
    [ -n "$basis" ] || continue
    [ "$basis" = "[no-wiki]" ] && continue
    [ -f "$wiki_root/$basis" ] || misses="$misses $basis"
  done <<EOF
$rows
EOF
  [ -z "$misses" ] || fail3 "Wiki basis page(s) not found under $wiki_root:$misses"
  ok
}

check_decision_rows_complete() { # <plan-dir>
  file="$1/design.md"
  [ -f "$file" ] || fail4 "design.md not found in $1"
  has_heading "$file" "## Decisions" || fail4 "## Decisions section missing in $file"
  rows=$(_decision_rows "$file")
  [ -n "$rows" ] || fail3 "## Decisions has no data rows"
  incomplete=0
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    nf=$(printf '%s\n' "$row" | awk -F'|' '{print NF}')
    [ "$nf" -ge 8 ] || { incomplete=$((incomplete + 1)); continue; }
    blank=$(printf '%s\n' "$row" | awk -F'|' '
      { for (i=2;i<=7;i++) { v=$i; gsub(/^[ \t]+|[ \t]+$/,"",v); if (v=="") { print "1"; exit } } }
    ')
    [ -z "$blank" ] || incomplete=$((incomplete + 1))
  done <<EOF
$rows
EOF
  [ "$incomplete" -eq 0 ] || fail3 "$incomplete decision row(s) have a blank cell"
  ok
}

check_reviewer_verdict() { # <plan-dir>
  file="$1/review-verdict.md"
  [ -f "$file" ] || fail4 "review-verdict.md not found in $1"
  grep -Fxq 'VERDICT: PASS' "$file" || fail3 "no 'VERDICT: PASS' line in $file"
  ok
}

# ------------------------------------------------------------------- check --

do_check() {
  gate_id="${1:-}"
  plan_dir="${2:-}"
  wiki_root="${3:-$PLUGIN_ROOT}"
  [ -n "$gate_id" ] && [ -n "$plan_dir" ] || usage_exit
  [ -d "$plan_dir" ] || fail4 "plan dir not found: $plan_dir"
  case "$gate_id" in
    baseline-tests-ran) check_baseline_tests_ran "$plan_dir" ;;
    affected-files-evidenced) check_affected_files_evidenced "$plan_dir" ;;
    open-questions-resolved) check_open_questions_resolved "$plan_dir" ;;
    constraints-surveyed) check_constraints_surveyed "$plan_dir" ;;
    research-evidenced) check_research_evidenced "$plan_dir" ;;
    groundings-exist) check_groundings_exist "$plan_dir" "$wiki_root" ;;
    decision-rows-complete) check_decision_rows_complete "$plan_dir" ;;
    reviewer-verdict) check_reviewer_verdict "$plan_dir" ;;
    *) echo "plan-gate: unknown gate id: $gate_id" >&2; exit 2 ;;
  esac
}

# -------------------------------------------------------------------- emit --

do_emit() {
  phase="${1:-}"
  plan_dir="${2:-}"
  out_file="${3:-}"
  case "$phase" in A|B) ;; *) usage_exit ;; esac
  [ -n "$plan_dir" ] && [ -n "$out_file" ] || usage_exit
  [ -d "$plan_dir" ] || fail4 "plan dir not found: $plan_dir"

  template="$PLUGIN_ROOT/templates/plan-gates.md"
  [ -f "$template" ] || fail4 "template not found: $template"

  baseline_cmd=""
  if [ "$phase" = "A" ]; then
    analysis="$plan_dir/analysis.md"
    [ -f "$analysis" ] || fail4 "analysis.md not found in $plan_dir"
    line=$(extract_l2 "$analysis" "## Ground truth" | grep '^- Baseline: ' | head -1 || true)
    [ -n "$line" ] || fail4 "no '- Baseline: ' line under ## Ground truth in $analysis"
    baseline_cmd=$(printf '%s\n' "$line" | sed -e 's/^- Baseline: //' -e 's/ -> .*$//')
    [ -n "$baseline_cmd" ] || fail4 "could not parse a Baseline command from: $line"
  fi

  marker="<!-- PHASE: $phase -->"
  block=$(awk -v marker="$marker" '
    $0 == marker { flag=1; next }
    flag && /^<!-- PHASE: / { exit }
    flag { print }
  ' "$template")
  [ -n "$block" ] || fail4 "no gates found for phase $phase in $template"

  result=$(printf '%s\n' "$block" | literal_replace '{PLAN_DIR}' "$plan_dir")
  if [ "$phase" = "A" ]; then
    result=$(printf '%s\n' "$result" | literal_replace '{BASELINE_CMD}' "$baseline_cmd")
  fi

  out_dir=$(dirname -- "$out_file")
  [ -d "$out_dir" ] || mkdir -p "$out_dir"
  {
    printf '# Plan gates (phase %s) — generated by plan-gate.sh emit; do not hand-edit CHECK/EXPECT\n\n' "$phase"
    printf '%s\n' "$result"
  } > "$out_file"
}

# -------------------------------------------------------------------- main --

mode="${1:-}"
case "$mode" in
  check) shift; do_check "${1:-}" "${2:-}" "${3:-}" ;;
  emit) shift; do_emit "${1:-}" "${2:-}" "${3:-}" ;;
  *) usage_exit ;;
esac
