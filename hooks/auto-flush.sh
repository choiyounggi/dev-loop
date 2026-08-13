#!/usr/bin/env bash
# dev-loop — Stop hook: automatically flush the insight queue into a reviewed PR,
# with no manual /dev-loop:knowledge-flush needed.
#
# "Verified routing" needs an LLM (real search + dedup + layer/category decision),
# so a pure shell promote can't do it. This hook instead spawns a DETACHED,
# headless `claude` run of the knowledge-flush skill — which does the full
# research→verify→route→ingest→PR pipeline (the pre-flush-pr-gate still enforces
# the INGEST_REPORT) and opens ONE reviewed PR under the user's OWN gh identity.
# No auto-merge; the owner reviews every PR.
#
# Heavily guarded so it never spams or recurses:
#   - kill switch:   DEV_LOOP_AUTOFLUSH=0
#   - recursion:     skipped inside the headless flush run (DEV_LOOP_FLUSHING=1)
#                    and inside the flush checkout (~/.dev-loop/repo)
#   - rate limit:    at most once per DEV_LOOP_AUTOFLUSH_INTERVAL sec (default 3600)
#   - threshold:     only when >= DEV_LOOP_AUTOFLUSH_MIN pending items (default 3)
#   - single-flight: scripts/flush-lock.sh, an owner-token mkdir lock shared
#                    with skills/knowledge-flush/SKILL.md step 0 (issue #77).
#                    DEV_LOOP_FLUSH_LOCK_TTL sec before a crashed holder's lock
#                    is reclaimable (default 900). DEV_LOOP_CLAIM_TTL sec before
#                    a claimed-but-unfinished queue row (hooks/queue-claim.js)
#                    is reclaimable by another run (default 3600).
#                    DEV_LOOP_FLUSH_LOCK (lock path) and DEV_LOOP_FLUSH_RUN_ID
#                    (this run's id) are test/override seams, not user knobs.
#   - fail-safe:     if `claude`/`gh` are missing it silently no-ops; the manual
#                    /dev-loop:knowledge-flush skill still works.
set +e

# --- kill switch + recursion guards ---------------------------------------
[ "${DEV_LOOP_AUTOFLUSH:-1}" = "0" ] && exit 0
[ -n "${DEV_LOOP_FLUSHING:-}" ] && exit 0

INPUT="$(cat 2>/dev/null)"
# Skip re-entrant Stop events (e.g. the loop-gate re-prompting a managed session);
# only flush on a genuine session end.
printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
CWD="$(printf '%s' "$INPUT" | node -e 'let s="";try{s=require("fs").readFileSync(0,"utf8")}catch{};let o={};try{o=JSON.parse(s)}catch{};process.stdout.write(String(o.cwd||""))' 2>/dev/null)"
case "$(cd "${CWD:-$PWD}" 2>/dev/null && pwd)" in
  "$HOME/.dev-loop/repo"*) exit 0 ;;
esac

# --- prerequisites (fail-safe: no-op if missing) --------------------------
command -v claude >/dev/null 2>&1 || exit 0
command -v gh     >/dev/null 2>&1 || exit 0

DIR="$HOME/.dev-loop"
QUEUE="$DIR/queue"
[ -d "$QUEUE" ] || exit 0

# --- threshold: count PENDING rows (exclude the retired .processed.jsonl) --
# The literal '"status":"pending"' match already excludes "claimed" rows
# (hooks/queue-claim.js), so a live sibling run's in-flight claims cannot
# re-trip this threshold.
PENDING=0
for f in "$QUEUE"/*.jsonl; do
  case "$f" in *"/.processed.jsonl") continue ;; esac
  [ -f "$f" ] || continue
  n=$(grep -c '"status":"pending"' "$f" 2>/dev/null)
  PENDING=$((PENDING + ${n:-0}))
done
[ "$PENDING" -ge "${DEV_LOOP_AUTOFLUSH_MIN:-3}" ] || exit 0

# --- rate limit: at most once per interval --------------------------------
STAMP="$DIR/.last-autoflush"
INTERVAL_SEC="${DEV_LOOP_AUTOFLUSH_INTERVAL:-3600}"
INTERVAL_MIN=$(( INTERVAL_SEC / 60 )); [ "$INTERVAL_MIN" -lt 1 ] && INTERVAL_MIN=1
if [ -f "$STAMP" ] && [ -n "$(find "$STAMP" -mmin "-$INTERVAL_MIN" 2>/dev/null)" ]; then
  exit 0
fi

# --- single-flight lock (shared with skills/knowledge-flush/SKILL.md step 0
#     via scripts/flush-lock.sh — see issue #77) ---------------------------
# One run id for both the acquire below and the release in the backgrounded
# subshell, so release's owner-token check matches this run (DEV_LOOP_FLUSH_RUN_ID
# is exported here and inherited by the "(...) &" subshell further down).
RUNID="${DEV_LOOP_FLUSH_RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
export DEV_LOOP_FLUSH_RUN_ID="$RUNID"
sh "$(dirname "$0")/../scripts/flush-lock.sh" acquire >/dev/null 2>&1 || exit 0
touch "$STAMP" 2>/dev/null

# --- spawn the detached headless flush ------------------------------------
CLAUDE_BIN="$(command -v claude)"
PROMPT='Run the dev-loop:knowledge-flush skill now. Drain ~/.dev-loop/queue: for each pending insight research and verify the best-practice against real sources, check existing wiki layers for duplicates/links, ALSO check open knowledge/* PRs for overlapping candidates (fold into that branch or drop as pending-duplicate — never open a sibling duplicate PR), decide the target layer/category, run wiki-ingest, write the 4-section INGEST_REPORT (Verified best-practice / Existing-layer check with a "Pages read:" id list / Open-PR check / Routing decision), then open exactly ONE reviewed PR (label dev-loop:knowledge) under my own gh identity, passing --body-file with a LITERAL absolute path (never --body). Do NOT merge. If the queue is empty, do nothing.'

(
  DEV_LOOP_FLUSHING=1 nohup "$CLAUDE_BIN" -p "$PROMPT" \
    --permission-mode bypassPermissions \
    > "$DIR/autoflush.log" 2>&1
  sh "$(dirname "$0")/../scripts/flush-lock.sh" release >/dev/null 2>&1
) &
disown 2>/dev/null

exit 0
