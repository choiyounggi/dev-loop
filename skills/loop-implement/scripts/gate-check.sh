#!/usr/bin/env bash
# gate-check.sh — deterministic gates-ledger checker for loop-implement.
#
# A gates ledger (templates/gates.md) makes "done" machine-checkable: each
# gate is a checkbox whose proof is a command (CHECK:) plus a success token
# (EXPECT:) plus recorded EVIDENCE. The agent never grades itself — this
# script runs the commands and writes the evidence. A checked box whose
# evidence still reads "pending" is a claim without proof and counts as
# WORSE than unchecked (state CLAIMED).
#
# Ledger format (one file per task, .dev-loop/gates/<task>.md):
#   - [ ] G1: <observable outcome>
#     CHECK: <shell command>
#     EXPECT: <substring that must appear in combined output>
#     EVIDENCE: pending
#   - [ ] G2: <manual outcome no command can decide>
#     EVIDENCE: pending
#   ABANDON: G2 <non-empty reason>
#
# Rules: a runnable gate has BOTH CHECK and EXPECT (one without the other is
# a parse error); a manual gate has neither. Gate ids must be unique within
# a file. A ledger with no gates, a duplicate id, an ABANDON with a blank
# reason or an unknown id is an error, not completion.
#
# Usage:
#   gate-check.sh --status <file>...   parse + report; never executes CHECK
#   gate-check.sh --run    <file>...   execute runnable gates' CHECK from the
#                                      current directory, rewrite checkbox +
#                                      EVIDENCE in place (atomic tmp+mv)
#
# A runnable gate is MET only when its CHECK exits 0 AND its EXPECT substring
# appears in the combined stdout+stderr. CHECK is bounded by
# GATE_CHECK_TIMEOUT seconds (default 120) via a perl alarm.
#
# Exit codes: 0 all gates MET or ABANDONED; 1 unmet gates remain; 2 usage or
# parse error.
#
# Bash 3.2 compatible (macOS): no mapfile, no associative arrays.
set -u

MODE="${1:-}"
shift 2>/dev/null || true

if [ "$MODE" != "--status" ] && [ "$MODE" != "--run" ]; then
  echo "usage: gate-check.sh --status|--run <gates.md>..." >&2
  exit 2
fi
if [ "$#" -eq 0 ]; then
  echo "gate-check: no ledger files given" >&2
  exit 2
fi

TIMEOUT="${GATE_CHECK_TIMEOUT:-120}"
TOTAL_UNMET=0
TOTAL_MET=0
TOTAL_ABANDONED=0
PARSE_ERROR=0

# run_check <command> -> combined output on stdout; exit status preserved.
# perl alarm gives a portable timeout (macOS has no `timeout`). The alarm is
# set before exec and survives it; the replaced bash has no ALRM handler, so
# expiry kills it with SIGALRM -> exit 142 (128+14). GNU timeout's 124 is
# also recognized in case CHECK wraps `timeout` itself.
run_check() {
  perl -e '
    alarm shift @ARGV;
    exec "/bin/bash", "-c", $ARGV[0];
  ' "$TIMEOUT" "$1" 2>&1
}

# truncate_line <text> — one decisive evidence line, bounded.
truncate_line() {
  printf '%s' "$1" | tr '\n' ' ' | cut -c1-200
}

for FILE in "$@"; do
  if [ ! -f "$FILE" ]; then
    echo "PARSE $FILE: not a file" >&2
    PARSE_ERROR=1
    continue
  fi

  # ---- pass 1: parse into parallel "arrays" (newline-joined records) ----
  # Record per gate: id|checked|check|expect|evidence  (| is forbidden in ids)
  IDS=""            # space-separated gate ids, in order
  ABANDONED_IDS=""  # space-separated abandoned ids
  ERRORS=""
  CUR_ID=""; CUR_CHECKED=""; CUR_CHECK=""; CUR_EXPECT=""; CUR_EVIDENCE=""
  GATES_TMP=$(mktemp)

  flush_gate() {
    [ -z "$CUR_ID" ] && return 0
    if { [ -n "$CUR_CHECK" ] && [ -z "$CUR_EXPECT" ]; } || \
       { [ -z "$CUR_CHECK" ] && [ -n "$CUR_EXPECT" ]; }; then
      ERRORS="$ERRORS gate $CUR_ID needs both CHECK and EXPECT or neither;"
    fi
    case " $IDS " in
      *" $CUR_ID "*) ERRORS="$ERRORS duplicate id $CUR_ID;" ;;
    esac
    IDS="$IDS $CUR_ID"
    printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
      "$CUR_ID" "$CUR_CHECKED" "$CUR_CHECK" "$CUR_EXPECT" "$CUR_EVIDENCE" >> "$GATES_TMP"
    CUR_ID=""; CUR_CHECKED=""; CUR_CHECK=""; CUR_EXPECT=""; CUR_EVIDENCE=""
  }

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "- [ ] "*|"- [x] "*)
        flush_gate
        rest="${line#- \[?\] }"
        CUR_ID="${rest%%:*}"
        case "$line" in "- [x] "*) CUR_CHECKED=1 ;; *) CUR_CHECKED=0 ;; esac
        case "$CUR_ID" in
          *" "*|"") ERRORS="$ERRORS malformed gate line: $(truncate_line "$line");" ; CUR_ID="" ;;
        esac
        ;;
      "  CHECK: "*|"    CHECK: "*)
        CUR_CHECK="${line#*CHECK: }" ;;
      "  EXPECT: "*|"    EXPECT: "*)
        CUR_EXPECT="${line#*EXPECT: }" ;;
      "  EVIDENCE:"*|"    EVIDENCE:"*)
        CUR_EVIDENCE="${line#*EVIDENCE:}"
        CUR_EVIDENCE="${CUR_EVIDENCE# }" ;;
      "ABANDON: "*)
        ab="${line#ABANDON: }"
        ab_id="${ab%% *}"
        ab_reason="${ab#"$ab_id"}"
        ab_reason="$(printf '%s' "$ab_reason" | sed 's/^ *//;s/ *$//')"
        if [ -z "$ab_id" ] || [ -z "$ab_reason" ]; then
          ERRORS="$ERRORS ABANDON needs an id and a non-empty reason;"
        else
          ABANDONED_IDS="$ABANDONED_IDS $ab_id"
        fi
        ;;
    esac
  done < "$FILE"
  flush_gate

  if [ ! -s "$GATES_TMP" ]; then
    ERRORS="$ERRORS no gates found;"
  fi
  # Every abandoned id must name a real gate.
  for ab_id in $ABANDONED_IDS; do
    case " $IDS " in
      *" $ab_id "*) : ;;
      *) ERRORS="$ERRORS ABANDON references unknown gate $ab_id;" ;;
    esac
  done

  if [ -n "$ERRORS" ]; then
    echo "PARSE $FILE:$ERRORS" >&2
    PARSE_ERROR=1
    rm -f "$GATES_TMP"
    continue
  fi

  # ---- pass 2 (--run only): execute runnable, non-abandoned gates and ----
  # ---- rewrite checkbox + EVIDENCE atomically.                        ----
  if [ "$MODE" = "--run" ]; then
    REWRITE_TMP=$(mktemp)
    RESULTS_TMP=$(mktemp)   # id \x1f met(0/1) \x1f evidence-line

    while IFS=$'\x1f' read -r gid gchecked gcheck gexpect gevidence; do
      case " $ABANDONED_IDS " in *" $gid "*) continue ;; esac
      [ -z "$gcheck" ] && continue   # manual gate: never auto-run
      out=$(run_check "$gcheck"); code=$?
      if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -qF -- "$gexpect"; then
        decisive=$(printf '%s\n' "$out" | grep -F -- "$gexpect" | head -1)
        printf '%s\x1f1\x1fexit=0 matched: %s\n' "$gid" "$(truncate_line "$decisive")" >> "$RESULTS_TMP"
      elif [ "$code" -eq 124 ] || [ "$code" -eq 142 ]; then
        printf '%s\x1f0\x1fexit=%s timeout after %ss\n' "$gid" "$code" "$TIMEOUT" >> "$RESULTS_TMP"
      else
        why="no-match"; [ "$code" -ne 0 ] && why="exit=$code"
        printf '%s\x1f0\x1f%s: %s\n' "$gid" "$why" "$(truncate_line "$out")" >> "$RESULTS_TMP"
      fi
    done < "$GATES_TMP"

    # Rewrite the ledger: flip checkbox + replace EVIDENCE for executed gates.
    US=$(printf '\x1f')
    lookup_result() { awk -F"$US" -v id="$1" '$1==id{print; exit}' "$RESULTS_TMP"; }
    ACTIVE_ID=""
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "- [ ] "*|"- [x] "*)
          rest="${line#- \[?\] }"
          ACTIVE_ID="${rest%%:*}"
          res=$(lookup_result "$ACTIVE_ID")
          if [ -n "$res" ]; then
            met=$(printf '%s' "$res" | cut -d$'\x1f' -f2)
            box=" "; [ "$met" = "1" ] && box="x"
            printf -- '- [%s] %s\n' "$box" "$rest" >> "$REWRITE_TMP"
          else
            printf '%s\n' "$line" >> "$REWRITE_TMP"
          fi
          ;;
        "  EVIDENCE:"*|"    EVIDENCE:"*)
          res=$(lookup_result "$ACTIVE_ID")
          if [ -n "$res" ]; then
            ev=$(printf '%s' "$res" | cut -d$'\x1f' -f3)
            indent="${line%%EVIDENCE:*}"
            printf '%sEVIDENCE: %s\n' "$indent" "$ev" >> "$REWRITE_TMP"
          else
            printf '%s\n' "$line" >> "$REWRITE_TMP"
          fi
          ;;
        *)
          printf '%s\n' "$line" >> "$REWRITE_TMP"
          ;;
      esac
    done < "$FILE"
    mv "$REWRITE_TMP" "$FILE"
    rm -f "$RESULTS_TMP" "$GATES_TMP"

    # Re-parse the rewritten file for reporting by falling through to the
    # status logic below on fresh state.
    GATES_TMP=$(mktemp)
    CUR_ID=""; CUR_CHECKED=""; CUR_CHECK=""; CUR_EXPECT=""; CUR_EVIDENCE=""
    IDS=""
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "- [ ] "*|"- [x] "*)
          flush_gate
          rest="${line#- \[?\] }"
          CUR_ID="${rest%%:*}"
          case "$line" in "- [x] "*) CUR_CHECKED=1 ;; *) CUR_CHECKED=0 ;; esac
          ;;
        "  CHECK: "*|"    CHECK: "*)   CUR_CHECK="${line#*CHECK: }" ;;
        "  EXPECT: "*|"    EXPECT: "*) CUR_EXPECT="${line#*EXPECT: }" ;;
        "  EVIDENCE:"*|"    EVIDENCE:"*)
          CUR_EVIDENCE="${line#*EVIDENCE:}"; CUR_EVIDENCE="${CUR_EVIDENCE# }" ;;
      esac
    done < "$FILE"
    flush_gate
  fi

  # ---- report state per gate ----
  while IFS=$'\x1f' read -r gid gchecked gcheck gexpect gevidence; do
    state=""
    case " $ABANDONED_IDS " in
      *" $gid "*)
        state="ABANDONED"; TOTAL_ABANDONED=$((TOTAL_ABANDONED + 1)) ;;
    esac
    if [ -z "$state" ]; then
      pending=0
      case "$gevidence" in ""|pending|pending*) pending=1 ;; esac
      if [ "$gchecked" = "1" ] && [ "$pending" = "1" ]; then
        state="CLAIMED"     # checked box, no evidence: a claim, not proof
        TOTAL_UNMET=$((TOTAL_UNMET + 1))
      elif [ "$gchecked" = "1" ]; then
        state="MET"; TOTAL_MET=$((TOTAL_MET + 1))
      else
        state="UNMET"; TOTAL_UNMET=$((TOTAL_UNMET + 1))
      fi
    fi
    echo "$state $FILE:$gid"
  done < "$GATES_TMP"
  rm -f "$GATES_TMP"
done

if [ "$PARSE_ERROR" -eq 1 ]; then
  echo "SUMMARY met=$TOTAL_MET unmet=$TOTAL_UNMET abandoned=$TOTAL_ABANDONED parse-errors=yes"
  exit 2
fi
echo "SUMMARY met=$TOTAL_MET unmet=$TOTAL_UNMET abandoned=$TOTAL_ABANDONED"
[ "$TOTAL_UNMET" -gt 0 ] && exit 1
exit 0
