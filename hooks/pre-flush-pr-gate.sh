#!/usr/bin/env bash
# dev-loop — PreToolUse(Bash) gate: a knowledge-flush PR may not be opened until
# the mandatory pre-PR pipeline has been done and evidenced.
#
# It forces /dev-loop:knowledge-flush to actually:
#   1. research + verify the best-practice against real sources,
#   2. check existing wiki layers for duplicates / links to connect,
#   3. decide the target layer + category (or justify a new category),
# by requiring an INGEST_REPORT with those three sections filled BEFORE the PR.
#
# Scope is narrow: it only engages for knowledge-flush PRs (detected by a
# knowledge/* head branch, the dev-loop:knowledge label, or an INGEST_REPORT
# body-file). Any other `gh pr create` in any repo passes untouched — this hook
# is global-install-safe.
#
# Claude Code PreToolUse stdin is nested JSON: {"tool_input":{"command":"..."}}.
# Block message goes to stderr with exit code 2 (deny); allow is exit 0.
set +e

INPUT="$(cat)"

# Extract the command string from the nested tool_input. Prefer node; fall back
# to jq so the gate does NOT fail open (allow everything) when node is absent.
CMD=""
if command -v node >/dev/null 2>&1; then
  CMD="$(printf '%s' "$INPUT" | node -e '
const fs=require("fs");let s="";try{s=fs.readFileSync(0,"utf8");}catch{}
let o={};try{o=JSON.parse(s);}catch{}
const ti=o.tool_input||o.toolInput||{};
process.stdout.write(String(ti.command||""));
' 2>/dev/null)"
fi
if [ -z "$CMD" ] && command -v jq >/dev/null 2>&1; then
  CMD="$(printf '%s' "$INPUT" | jq -r '(.tool_input.command // .toolInput.command) // ""' 2>/dev/null)"
fi

[ -n "$CMD" ] || exit 0

# Only care about an actually-executed `gh pr create` (anchor on line start or a
# shell separator, so prose / substrings do not trip it).
printf '%s' "$CMD" | grep -Eq '(^|[;&|]|&&|\|\|)[[:space:]]*gh[[:space:]]+pr[[:space:]]+create' || exit 0

# Is this a knowledge-flush PR? Detect ONLY from markers in the command itself,
# never from ambient repo/branch state — otherwise an unrelated `gh pr create` in
# another project would be gated once a flush checkout is on a knowledge/* branch.
# The flush skill always emits all three markers, so command-only detection is
# both sufficient and side-effect-free.
IS_FLUSH=0
printf '%s' "$CMD" | grep -Eq -- '--head[[:space:]=]+knowledge/' && IS_FLUSH=1
printf '%s' "$CMD" | grep -Eq -- 'dev-loop:knowledge' && IS_FLUSH=1
printf '%s' "$CMD" | grep -Eq -- 'INGEST_REPORT' && IS_FLUSH=1
[ "$IS_FLUSH" -eq 1 ] || exit 0

# Locate the --body-file path referenced by the command. Portable (grep/sed only,
# no node) so the enforcement path never depends on node being installed.
BODY_FILE="$(printf '%s' "$CMD" | grep -oE -- "--body-file[= ]+[^ '\"\`]+" | head -1 | sed -E 's/^--body-file[= ]+//')"

fail() {
  echo "dev-loop knowledge-flush gate: $1" >&2
  echo "" >&2
  echo "A knowledge-flush PR must carry an INGEST_REPORT proving the pre-PR" >&2
  echo "pipeline ran. Write the report FIRST (a separate step, not a heredoc" >&2
  echo "in this same command — PreToolUse evaluates before the command runs)," >&2
  echo "then create the PR with --body-file pointing at it. Required sections:" >&2
  echo "  ## Verified best-practice   (real sources + how you verified)" >&2
  echo "  ## Existing-layer check     (pages checked; duplicates/links found)" >&2
  echo "  ## Routing decision         (target domain/category, or new-category rationale)" >&2
  exit 2
}

[ -n "$BODY_FILE" ] || fail "no --body-file found on the gh pr create command."
# Expand a leading ~ if present.
case "$BODY_FILE" in "~"/*) BODY_FILE="$HOME/${BODY_FILE#~/}" ;; esac
[ -f "$BODY_FILE" ] || fail "body file '$BODY_FILE' does not exist yet."

miss=""
grep -q '## *Verified best-practice' "$BODY_FILE" || miss="$miss 'Verified best-practice'"
grep -q '## *Existing-layer check'   "$BODY_FILE" || miss="$miss 'Existing-layer check'"
grep -q '## *Routing decision'       "$BODY_FILE" || miss="$miss 'Routing decision'"

# Each section must have real content, not just a header (guard empty stubs):
# require at least ~40 non-header, non-blank characters in the body.
CONTENT_CHARS="$(grep -vE '^\s*(#|$)' "$BODY_FILE" | tr -d '[:space:]' | wc -c | tr -d ' ')"

[ -z "$miss" ] || fail "INGEST_REPORT is missing required section(s):$miss."
[ "${CONTENT_CHARS:-0}" -ge 40 ] || fail "INGEST_REPORT sections look empty — fill them with real findings."

exit 0
