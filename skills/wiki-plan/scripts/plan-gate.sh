#!/bin/sh
# plan-gate.sh — mechanical judge for Phase A/B plan gates (cycle-hardening design §3)
#
# Usage:
#   plan-gate.sh check <gate-id> <plan-dir> [<wiki-root>]   one gate -> stdout "ok"|"fail"
#   plan-gate.sh emit  <A|B> <plan-dir> <out-file>          write gates ledger from templates/plan-gates.md
#
# Gate ids (A): baseline-tests-ran affected-files-evidenced open-questions-resolved
#               constraints-surveyed lint-surveyed research-evidenced
# Gate ids (B): groundings-exist decision-rows-complete requirements-covered
#               reviewer-verdict
#   groundings-exist resolves wiki-local/... under the project root (see project_root_for)
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

check_lint_surveyed() { # <plan-dir>
  file="$1/analysis.md"
  [ -f "$file" ] || fail4 "analysis.md not found in $1"
  has_heading "$file" "## Ground truth" || fail4 "## Ground truth section missing in $file"
  lines=$(extract_l2 "$file" "## Ground truth" | grep '^- Lint: ' || true)
  [ -n "$lines" ] || fail3 "no '- Lint: ' bullet under ## Ground truth (use '- Lint: none — checked: <command>' when the project has no lint or typecheck command)"
  bad=$(printf '%s\n' "$lines" | grep -v -e '^- Lint: none — checked: *[^ ]' -e '^- Lint: [^ ].* -> rc=[0-9][0-9]*$' || true)
  [ -z "$bad" ] || fail3 "malformed Lint bullet(s): $(printf '%s' "$bad" | head -1)"
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

# project_root_for <plan-dir> — the nearest ancestor of the resolved plan dir
# (the plan dir itself first) that holds a wiki-local/ directory; when none
# does, the caller's PWD. Local-layer Wiki basis paths (wiki-local/...) are
# resolved against this root; bundled paths (wiki/...) never are.
project_root_for() {
  dir=$(CDPATH= cd -- "$1" && pwd)
  while :; do
    if [ -d "$dir/wiki-local" ]; then printf '%s\n' "$dir"; return 0; fi
    [ "$dir" = "/" ] && break
    dir=$(dirname -- "$dir")
  done
  printf '%s\n' "$PWD"
}

check_groundings_exist() { # <plan-dir> <wiki-root>
  file="$1/design.md"
  wiki_root="$2"
  project_root=$(project_root_for "$1")
  [ -f "$file" ] || fail4 "design.md not found in $1"
  has_heading "$file" "## Decisions" || fail4 "## Decisions section missing in $file"
  rows=$(_decision_rows "$file")
  [ -n "$rows" ] || ok   # no decisions yet: decision-rows-complete gate owns that defect
  misses=""
  local_misses=""
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    basis=$(printf '%s\n' "$row" | awk -F'|' '{v=$5; gsub(/^[ \t]+|[ \t]+$/,"",v); print v}')
    [ -n "$basis" ] || continue
    [ "$basis" = "[no-wiki]" ] && continue
    case "$basis" in
      wiki-local/*) [ -f "$project_root/$basis" ] || local_misses="$local_misses $basis" ;;
      *) [ -f "$wiki_root/$basis" ] || misses="$misses $basis" ;;
    esac
  done <<EOF
$rows
EOF
  [ -z "$misses" ] || fail3 "Wiki basis page(s) not found under $wiki_root:$misses"
  [ -z "$local_misses" ] || fail3 "Wiki basis page(s) not found under $project_root (project-local layer):$local_misses"
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

# _rule_ids <analysis.md> — per ## Requirements data row: every R<n> number
# the Rule cell leads with ("R1/R2", "R3, R4" give two), or "-" when the cell
# carries no leading R<n> id.
_rule_ids() {
  extract_l2 "$1" "## Requirements" | LC_ALL=C awk -F'|' '
    /^\|/ {
      n++
      if (n == 1) next
      line = $0; gsub(/[-:| \t]/, "", line)
      if (line == "") next
      v = $2; gsub(/^[ \t*`_]+/, "", v)
      if (!match(v, /^R[0-9]+/)) { print "-"; next }
      print substr(v, 2, RLENGTH - 1) + 0
      v = substr(v, RLENGTH + 1)
      while (match(v, /^[a-z]?[ \t]*[\/,&][ \t]*R[0-9]+/)) {
        id = substr(v, 1, RLENGTH)
        sub(/^.*R/, "", id)
        print id + 0
        v = substr(v, RLENGTH + 1)
      }
    }
  '
}

# _cited_rule_ids — reads text on stdin, prints every R<n> number it names,
# one per line. A match preceded by a letter, digit or "_" is not an id
# ("PR12", "XR3"). A range "R4-R9" / "R4–9" / "R4..R9" names every number in it.
# LC_ALL=C: macOS awk mixes byte RSTART with character substr() under a UTF-8
# locale and aborts on Korean text ("towc: multibyte conversion failure").
_cited_rule_ids() {
  LC_ALL=C awk '
    {
      s = $0
      while (match(s, /R[0-9]+/)) {
        pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
        num = substr(s, RSTART + 1, RLENGTH - 1) + 0
        s = substr(s, RSTART + RLENGTH)
        if (pre ~ /[A-Za-z0-9_]/) continue
        print num
        if (match(s, /^[a-z]?[ \t]*(-|–|—|\.\.)[ \t]*R?[0-9]+/)) {
          r = substr(s, RSTART, RLENGTH)
          sub(/^.*[^0-9]/, "", r)
          hi = r + 0
          for (k = num + 1; k <= hi && k - num <= 1000; k++) print k
        }
      }
    }
  '
}

# _first_decision_table <design.md> — data rows of the FIRST table under
# ## Decisions only; a later table in that section (alternatives, risks) is
# not a decision row and must not count as citing a Rule.
_first_decision_table() {
  extract_l2 "$1" "## Decisions" | awk '
    /^\|/ {
      started = 1
      n++
      if (n == 1) next
      line = $0; gsub(/[-:| \t]/, "", line)
      if (line == "") next
      print
      next
    }
    started { exit }
  '
}

check_requirements_covered() { # <plan-dir>
  analysis="$1/analysis.md"
  design="$1/design.md"
  [ -f "$analysis" ] || fail4 "analysis.md not found in $1"
  [ -f "$design" ] || fail4 "design.md not found in $1"
  has_heading "$analysis" "## Requirements" || fail4 "## Requirements section missing in $analysis"
  has_heading "$design" "## Decisions" || fail4 "## Decisions section missing in $design"
  rules=$(_rule_ids "$analysis")
  [ -n "$rules" ] || fail3 "## Requirements has no rule rows"
  unnumbered=$(printf '%s\n' "$rules" | grep -c '^-$' || true)
  [ "$unnumbered" -eq 0 ] || fail3 "$unnumbered ## Requirements row(s) have no leading R<n> id in the Rule cell"
  cited=$(_first_decision_table "$design" | _cited_rule_ids | sort -n -u)
  missing=""
  for id in $(printf '%s\n' "$rules" | sort -n -u); do
    printf '%s\n' "$cited" | grep -qx "$id" || missing="$missing R$id"
  done
  [ -z "$missing" ] || fail3 "Rule(s) named by no ## Decisions row:$missing"
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
    lint-surveyed) check_lint_surveyed "$plan_dir" ;;
    research-evidenced) check_research_evidenced "$plan_dir" ;;
    groundings-exist) check_groundings_exist "$plan_dir" "$wiki_root" ;;
    decision-rows-complete) check_decision_rows_complete "$plan_dir" ;;
    requirements-covered) check_requirements_covered "$plan_dir" ;;
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
