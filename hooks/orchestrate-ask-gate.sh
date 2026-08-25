#!/usr/bin/env bash
# dev-loop — PreToolUse(Bash) gate: an orchestrate run may not launch a worker
# until this session has actually put its human gate to the user as a CHOOSER
# (the AskUserQuestion tool), not as prose the user has to answer by typing.
#
# It forces /dev-loop:orchestrate to deliver Gate 1 the way the skill specifies:
#   1. task-split approval — asked with AskUserQuestion,
#   2. substrate (Orca vs tmux) — asked in that same call when Orca is detected,
# by requiring the evidence to exist in the session transcript BEFORE the first
# worker launch (launch-session.sh, orca-worker-start.sh, orca-spawn.sh).
#
# Scope is narrow: it only engages for those three plugin scripts, so any other
# Bash command in any repo passes untouched — this hook is global-install-safe.
# Worker sessions never launch workers, so the gate never fires inside one (a
# worker must NOT use AskUserQuestion; it escalates via ask-coordinator.sh).
#
# Claude Code PreToolUse stdin is nested JSON:
#   {"transcript_path":"...","tool_input":{"command":"..."}}
# Block message goes to stderr with exit code 2 (deny); allow is exit 0.
set +e

INPUT="$(cat)"

# Extract transcript path (line 1) + command (the rest) from the nested payload.
# A filesystem path never contains a newline, so line 1 is unambiguous even when
# the command is multi-line. Prefer node; fall back to jq so the gate does NOT
# fail open when node is absent.
PAYLOAD=""
if command -v node >/dev/null 2>&1; then
  PAYLOAD="$(printf '%s' "$INPUT" | node -e '
const fs=require("fs");let s="";try{s=fs.readFileSync(0,"utf8");}catch{}
let o={};try{o=JSON.parse(s);}catch{}
const ti=o.tool_input||o.toolInput||{};
const tp=String(o.transcript_path||o.transcriptPath||"").replace(/[\r\n]/g," ");
process.stdout.write(tp+"\n"+String(ti.command||""));
' 2>/dev/null)"
fi
if [ -z "$PAYLOAD" ] && command -v jq >/dev/null 2>&1; then
  PAYLOAD="$(printf '%s' "$INPUT" | jq -r '((.transcript_path // .transcriptPath) // "") + "\n" + ((.tool_input.command // .toolInput.command) // "")' 2>/dev/null)"
fi

TRANSCRIPT="$(printf '%s' "$PAYLOAD" | head -1)"
CMD="$(printf '%s' "$PAYLOAD" | tail -n +2)"

[ -n "$CMD" ] || exit 0

# Only care about an actually-executed worker launch (anchored at line start or a
# shell separator, so `cat .../launch-session.sh` and prose never trip it).
# An `NAME=value` env prefix and a `bash`/`sh` interpreter are both allowed to sit
# in front of the script path; a preceding word (`cat`, `less`, `grep`) is not.
LAUNCH_RE='(^|[;&|(]|&&|\|\|)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((bash|sh|zsh)[[:space:]]+)?[^[:space:];&|]*(launch-session|orca-worker-start|orca-spawn)\.sh([[:space:]]|$)'
printf '%s' "$CMD" | grep -Eq "$LAUNCH_RE"
[ $? -eq 0 ] || exit 0

# `--help` is not a launch.
printf '%s' "$CMD" | grep -Eq -- '(^|[[:space:]])(--help|-h)([[:space:]]|$)'
[ $? -eq 0 ] && exit 0

# Which substrate is this launch on? An Orca script proves the user chose Orca.
IS_ORCA=0
printf '%s' "$CMD" | grep -Eq '(orca-worker-start|orca-spawn)\.sh'
[ $? -eq 0 ] && IS_ORCA=1

# No transcript to inspect (older CLI, or a non-Claude caller such as a test
# harness driving the script directly) → nothing to verify; stay out of the way.
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

fail() {
  echo "dev-loop orchestrate gate: $1" >&2
  echo "" >&2
  echo "Gate 1 is a CHOOSER, not prose. Before launching any worker, put the" >&2
  echo "decision to the user with the AskUserQuestion tool — one call, the" >&2
  echo "recommended option first and labelled '(Recommended)':" >&2
  echo "  Q1 task split — approve as proposed / revise (say how) / abort" >&2
  echo "  Q2 substrate  — Orca / tmux   (REQUIRED when Orca was detected)" >&2
  echo "The task list, dependency graph, slot count and cost note stay in the" >&2
  echo "turn body as the briefing; the decision itself is the tool call." >&2
  echo "Then re-run this launch command." >&2
  exit 2
}

# 1) The gate itself: an AskUserQuestion tool call must exist in this session.
ASK_LINES="$(grep -F 'AskUserQuestion' "$TRANSCRIPT" 2>/dev/null | grep -E '"(name|toolName)"[[:space:]]*:[[:space:]]*"AskUserQuestion"')"
[ -n "$ASK_LINES" ] || fail "no AskUserQuestion has been asked in this session, so the user never got a chooser for the task split."

# 2) Substrate: whenever Orca is a real option, the user must have been asked
#    which substrate to use — a detected Orca always asks (no default, no
#    remembered choice). Proven by an AskUserQuestion whose payload names it.
NEEDS_SUBSTRATE=$IS_ORCA
if [ "$NEEDS_SUBSTRATE" -eq 0 ]; then
  DETECT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/skills/orchestrate/scripts/orca-detect.sh"
  if [ -f "$DETECT" ]; then
    sh "$DETECT" >/dev/null 2>&1
    [ $? -eq 0 ] && NEEDS_SUBSTRATE=1
  fi
fi
if [ "$NEEDS_SUBSTRATE" -eq 1 ]; then
  printf '%s' "$ASK_LINES" | grep -iq 'orca'
  [ $? -eq 0 ] || fail "Orca is available but no AskUserQuestion offered the substrate choice — a detected Orca always asks (Orca vs tmux)."
fi

exit 0
