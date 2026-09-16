#!/bin/sh
# emit-gaps.sh <plan-dir>
#
# Records every [no-wiki] decision row in <plan-dir>/design.md's ## Decisions
# table: one gap line in log.md, one insight-queue candidate per row.
# Idempotent; never changes the gate verdict.
# Judge/side-effect split: plan-gate.sh judges, this script records (issue #193).
#
# Env:
#   DEV_LOOP_LOG_MD    log.md path (default: $PLUGIN_ROOT/log.md)
#   DEV_LOOP_QUEUE_DIR insight queue dir (default: $HOME/.dev-loop/queue)
#
# Exit codes:
#   0 ok   (stdout "ok", even when a write failed — warnings go to stderr)
#   2 usage (stderr usage line)
#   4 design.md or its "## Decisions" heading missing (stdout "fail")
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT_DEFAULT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT_DEFAULT}"

[ $# -eq 1 ] || { echo "usage: emit-gaps.sh <plan-dir>" >&2; exit 2; }
plan_dir=$1
feature=$(basename -- "$plan_dir")
design="$plan_dir/design.md"

if [ ! -f "$design" ]; then
  echo "fail"
  echo "emit-gaps: design.md not found in $plan_dir" >&2
  exit 4
fi
if ! grep -qF -- '## Decisions' "$design"; then
  echo "fail"
  echo "emit-gaps: ## Decisions section missing in $design" >&2
  exit 4
fi

# extract_l2 <file> <heading> — lines strictly between an exact "## <heading>"
# line and the next "## " line (or EOF). Copied from plan-gate.sh verbatim
# (do not source plan-gate.sh — it runs main() on load).
extract_l2() {
  awk -v hdr="$2" '
    $0 == hdr { flag=1; next }
    flag && /^## / { exit }
    flag { print }
  ' "$1"
}

# _decision_rows <design.md> — prints only data rows of ## Decisions table.
# Copied from plan-gate.sh verbatim.
_decision_rows() {
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

# _research_rows <analysis.md> — same shape, for the ## Research table.
_research_rows() {
  extract_l2 "$1" "## Research" | awk '
    /^\|/ {
      n++
      if (n == 1) next
      line = $0; gsub(/[-:| \t]/, "", line)
      if (line == "") next
      print
    }
  '
}

field() { # <row-line> <field-number> -> trimmed pipe-delimited cell
  printf '%s' "$1" | awk -F'|' -v n="$2" '{print $n}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

research=none
analysis="$plan_dir/analysis.md"
if [ -f "$analysis" ] && grep -qF -- '## Research' "$analysis"; then
  research_rows=$(_research_rows "$analysis")
  if [ -n "$research_rows" ]; then
    old_ifs=$IFS
    IFS='
'
    set -- $research_rows
    IFS=$old_ifs
    research=""
    for r in "$@"; do
      q=$(field "$r" 2)
      s=$(field "$r" 3)
      if [ -z "$research" ]; then
        research="$q ($s)"
      else
        research="$research; $q ($s)"
      fi
    done
  fi
fi

n=0
la=0
ls=0
qa=0
qs=0

have_node=1
command -v node >/dev/null 2>&1 || have_node=0
qdir=${DEV_LOOP_QUEUE_DIR:-$HOME/.dev-loop/queue}
log=${DEV_LOOP_LOG_MD:-$PLUGIN_ROOT/log.md}

rows=$(_decision_rows "$design")
old_ifs=$IFS
IFS='
'
set -- $rows
IFS=$old_ifs

for row in "$@"; do
  id=$(field "$row" 2)
  decision=$(field "$row" 3)
  choice=$(field "$row" 4)
  wiki=$(field "$row" 5)
  rejected=$(field "$row" 6)
  [ "$wiki" = "[no-wiki]" ] || continue
  n=$((n + 1))
  case $id in
    D*) ;;
    *) id="D$id" ;;
  esac

  trigger="Planning $feature: deciding $decision (no owning wiki page)"
  directive="$choice"
  why="wiki-plan Phase B found no wiki page for this decision; rejected alternative: $rejected"
  evidence="plans/$feature/design.md $id; analysis.md Research: $research"
  content=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s' \
    '★ Insight ─────────────────────────────────────' \
    "trigger: $trigger" \
    "directive: $directive" \
    "why: $why" \
    "evidence: $evidence" \
    "domain: " \
    "tags: plan-gap, $feature" \
    '─────────────────────────────────────────────')

  # --- queue write (first; D6) ---
  if [ "$have_node" -eq 0 ]; then
    echo "emit-gaps: warning: node not found on PATH — queue candidate for $feature/$id skipped" >&2
    qs=$((qs + 1))
  elif ! mkdir -p "$qdir" 2>/dev/null; then
    echo "emit-gaps: warning: could not create queue dir $qdir — candidate for $feature/$id skipped" >&2
    qs=$((qs + 1))
  else
    out=$(node -e '
      const [content, trigger, directive, why, evidence, feature, cwd] = process.argv.slice(1);
      const crypto = require("crypto");
      const path = require("path");
      const norm = content.replace(/\s+/g, " ").trim().toLowerCase();
      const hash = crypto.createHash("sha256").update(norm).digest("hex").slice(0, 16);
      const json = JSON.stringify({
        hash,
        sessionId: "plan-gaps",
        repo: path.basename(cwd),
        cwd,
        trigger,
        directive,
        why,
        evidence,
        domain: "",
        tags: ["plan-gap", feature],
        extra: "",
        content,
        harvestedAt: new Date().toISOString(),
        status: "pending",
      });
      process.stdout.write(hash + "\t" + json);
    ' "$content" "$trigger" "$directive" "$why" "$evidence" "$feature" "$PWD")
    hash=$(printf '%s' "$out" | cut -f1)
    json=$(printf '%s' "$out" | cut -f2-)
    if grep -qF "\"hash\":\"$hash\"" "$qdir/plan-gaps.jsonl" "$qdir/.processed.jsonl" 2>/dev/null; then
      qs=$((qs + 1))
    elif printf '%s\n' "$json" >> "$qdir/plan-gaps.jsonl" 2>/dev/null; then
      qa=$((qa + 1))
    else
      echo "emit-gaps: warning: could not write $qdir/plan-gaps.jsonl for $feature/$id" >&2
      qs=$((qs + 1))
    fi
  fi

  # --- log write (second; D6) ---
  key="gap | $feature/$id:"
  if [ ! -f "$log" ]; then
    echo "emit-gaps: warning: log.md not found at $log — gap line for $feature/$id not written" >&2
    ls=$((ls + 1))
  elif grep -qF -- "$key" "$log"; then
    ls=$((ls + 1))
  elif [ ! -w "$log" ]; then
    echo "emit-gaps: warning: log.md not writable at $log — gap line for $feature/$id not written" >&2
    ls=$((ls + 1))
  elif printf '%s\n' "## [$(date +%Y-%m-%d)] gap | $feature/$id: $decision — $choice" >> "$log" 2>/dev/null; then
    la=$((la + 1))
  else
    echo "emit-gaps: warning: could not write $log for $feature/$id" >&2
    ls=$((ls + 1))
  fi
done

echo "emit-gaps: $feature: $n [no-wiki] row(s), log +$la (skipped $ls), queue +$qa (skipped $qs)" >&2
echo ok
exit 0
