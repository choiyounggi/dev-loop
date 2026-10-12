#!/usr/bin/env bash
# dev-loop — Stop hook: when insights are queued, either (opt-in) flush them
# into a reviewed PR, or (default) surface a one-line notice so the user can
# run /dev-loop:knowledge-flush themselves.
#
# "Verified routing" needs an LLM (real search + dedup + layer/category decision),
# so a pure shell promote can't do it. Opted in, this hook spawns a DETACHED,
# headless `claude` run of the knowledge-flush skill's research→verify→route→
# ingest step, writing files only — it has no git tool and no `gh pr create`
# at all. THIS script (never inside any Claude session's permission system)
# does every git/gh-write step itself with fixed arguments: repo prep before
# the spawn, then (only if the session left real changes and a valid result
# file) commit, push, and `gh pr create`, opening the ONE reviewed PR under
# the user's OWN gh identity. No auto-merge; the owner reviews every PR. The
# nested session keeps the user's normal permission checks — it is NOT given
# bypassPermissions, only an explicit --allowedTools/--disallowedTools pair
# scoped to exactly what its file-editing half of the pipeline calls.
#
# Default is OFF: starting another session and opening a PR without the user
# having said yes to that flush in this conversation is a privilege the Stop
# hook does not get to take on its own — only DEV_LOOP_AUTOFLUSH=1 (opt in)
# does. Off, this hook spawns and opens nothing; it only emits a non-blocking
# `systemMessage` notice (rate-limited the same as the opted-in flush would be)
# so the user can run the manual skill when they choose to.
#
# Heavily guarded so it never spams or recurses:
#   - opt-in:        DEV_LOOP_AUTOFLUSH=1 (exactly "1"; anything else, including
#                    unset or "0", is off — notice-only, never spawns)
#   - recursion:     skipped inside the headless flush run (DEV_LOOP_FLUSHING=1)
#                    and inside the flush checkout (~/.dev-loop/repo)
#   - rate limit:    at most once per DEV_LOOP_AUTOFLUSH_INTERVAL sec (default
#                    3600) — shared between the opted-in spawn and the
#                    default-off notice, so flipping the switch mid-window
#                    doesn't double up
#   - threshold:     only when >= DEV_LOOP_AUTOFLUSH_MIN pending items (default 3)
#   - single-flight: scripts/flush-lock.sh, an owner-token mkdir lock shared
#                    with skills/knowledge-flush/SKILL.md step 0 (issue #77).
#                    DEV_LOOP_FLUSH_LOCK_TTL sec before a crashed holder's lock
#                    is reclaimable (default 900). DEV_LOOP_CLAIM_TTL sec before
#                    a claimed-but-unfinished queue row (hooks/queue-claim.js)
#                    is reclaimable by another run (default 3600).
#                    DEV_LOOP_FLUSH_LOCK (lock path) and DEV_LOOP_FLUSH_RUN_ID
#                    (this run's id) are test/override seams, not user knobs.
#   - fail-safe:     if `claude`/`gh` are missing, the opted-in spawn silently
#                    no-ops; the manual /dev-loop:knowledge-flush skill still
#                    works either way.
set +e

# Literal helper path — no $(dirname)/".." computation (directory-validator
# UNPINNED_NPX: the executed program must be spellable, not derived at run
# time). CLAUDE_PLUGIN_ROOT is set by the Claude Code CLI in production; the
# string-trim fallback covers bats, which invokes this script by its real
# repo path without exporting it.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${BASH_SOURCE[0]%/hooks/*}}"
FLUSH_LOCK="$PLUGIN_ROOT/scripts/flush-lock.sh"

# --- recursion guards ------------------------------------------------------
[ -n "${DEV_LOOP_FLUSHING:-}" ] && exit 0

INPUT="$(cat 2>/dev/null)"
# Skip re-entrant Stop events (e.g. the loop-gate re-prompting a managed session);
# only flush on a genuine session end.
printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
CWD="$(printf '%s' "$INPUT" | node -e 'let s="";try{s=require("fs").readFileSync(0,"utf8")}catch{};let o={};try{o=JSON.parse(s)}catch{};process.stdout.write(String(o.cwd||""))' 2>/dev/null)"
case "$(cd "${CWD:-$PWD}" 2>/dev/null && pwd)" in
  "$HOME/.dev-loop/repo"*) exit 0 ;;
esac

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

# --- rate limit: at most once per interval (shared by both paths below) ----
STAMP="$DIR/.last-autoflush"
INTERVAL_SEC="${DEV_LOOP_AUTOFLUSH_INTERVAL:-3600}"
INTERVAL_MIN=$(( INTERVAL_SEC / 60 )); [ "$INTERVAL_MIN" -lt 1 ] && INTERVAL_MIN=1
if [ -f "$STAMP" ] && [ -n "$(find "$STAMP" -mmin "-$INTERVAL_MIN" 2>/dev/null)" ]; then
  exit 0
fi

# --- default OFF: notice only, never spawns, never blocks Stop -------------
if [ "${DEV_LOOP_AUTOFLUSH:-}" != "1" ]; then
  touch "$STAMP" 2>/dev/null
  printf '{"systemMessage":"dev-loop: %s insight(s) queued — run /dev-loop:knowledge-flush to review them."}\n' "$PENDING"
  exit 0
fi

# --- opted in from here down: same guards as before, plus scoped permissions -
# fail-safe: no-op if missing
command -v claude >/dev/null 2>&1 || exit 0
command -v gh     >/dev/null 2>&1 || exit 0

touch "$STAMP" 2>/dev/null

# --- single-flight lock (shared with skills/knowledge-flush/SKILL.md step 0
#     via scripts/flush-lock.sh — see issue #77) ---------------------------
# One run id for both the acquire below and the release in the backgrounded
# subshell, so release's owner-token check matches this run (DEV_LOOP_FLUSH_RUN_ID
# is exported here and inherited by the "(...) &" subshell further down).
RUNID="${DEV_LOOP_FLUSH_RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
export DEV_LOOP_FLUSH_RUN_ID="$RUNID"
sh "$FLUSH_LOCK" acquire >/dev/null 2>&1 || exit 0

# --- integrity check: hash .git/hooks/* + .git/config, so a tampered hook or
#     rewritten remote (however it got there) can never reach the trusted
#     git commit/push/pr-create step below. shasum -a 256, not sha256sum —
#     the former ships with macOS, the latter needs homebrew coreutils. -----
git_integrity_hash() { # $1 = repo path
  { for f in "$1"/.git/hooks/*; do [ -f "$f" ] && shasum -a 256 "$f"; done
    for f in "$1/.git/config" "$1/.git/config.worktree" "$1/.git/info/attributes"; do
      [ -f "$f" ] && shasum -a 256 "$f"
    done
  } 2>/dev/null | sort | shasum -a 256 | awk '{print $1}'
}

# --- the boundary moves here: THIS script runs every git command and
# `gh pr create` with fixed arguments, outside any Claude session's
# permission system entirely. A second reviewer finding on the first fix
# was that scoping git by *subcommand* (`Bash(git -C <repo>:*)`) is still a
# losing game — `git -C <repo> -c alias.x='!sh -c evil' x`,
# `fetch --upload-pack=<cmd>` / `push --receive-pack=<cmd>`,
# `log --output=<any path>`, `rebase --exec`, `submodule foreach`, and
# `bisect run` all execute an arbitrary program through an allowed-looking
# `git` prefix (same lesson as the regex shell lexer: a subcommand denylist/
# allowlist never closes). So the nested session below gets NO git tool at
# all and no `gh pr create` — it only edits files; this trusted script does
# every git/gh-write operation itself, with a fixed command shape per call.
REPO="$DIR/repo"
BR="knowledge/autoflush-$RUNID"
CLAUDE_BIN="$(command -v claude)"
GH_BIN="$(command -v gh)"

(
  abort() { # $1 = reason, logged; always releases the lock before returning
    printf 'autoflush: %s\n' "$1" >> "$DIR/autoflush.log" 2>/dev/null
    sh "$FLUSH_LOCK" release >/dev/null 2>&1
    exit 0
  }

  # --- repo prep: clone if missing, else fetch + reset to origin/main, then
  #     a fresh branch — the same commands skills/knowledge-flush/SKILL.md
  #     step 1 documents for the manual, human-approved path, just run here
  #     as plain bash instead of inside a Claude session. ------------------
  if [ -d "$REPO/.git" ]; then
    git -C "$REPO" fetch origin >/dev/null 2>&1 || abort "git fetch origin failed — skipping this flush"
    git -C "$REPO" checkout main >/dev/null 2>&1 || abort "git checkout main failed — skipping this flush"
    git -C "$REPO" reset --hard origin/main >/dev/null 2>&1 || abort "git reset --hard origin/main failed — skipping this flush"
  else
    mkdir -p "$DIR"
    git clone https://github.com/choiyounggi/dev-loop.git "$REPO" >/dev/null 2>&1 || abort "git clone failed — skipping this flush"
  fi
  if [ -z "$(git -C "$REPO" config user.email 2>/dev/null)" ]; then
    GH_USER="$("$GH_BIN" api user -q .login 2>/dev/null)"
    if [ -n "$GH_USER" ]; then
      git -C "$REPO" config user.name "$GH_USER"
      git -C "$REPO" config user.email "${GH_USER}@users.noreply.github.com"
    fi
  fi
  git -C "$REPO" checkout -B "$BR" >/dev/null 2>&1 || abort "git checkout -B $BR failed — skipping this flush"

  HOOKS_BEFORE="$(git_integrity_hash "$REPO")"
  RESULT_FILE="$DIR/autoflush-result.json"
  rm -f "$RESULT_FILE"

  # --- the nested session: file edits only. No git, no gh pr create. It
  # keeps gh pr list / gh api user / the two pinned scripts / the export
  # line for the read-only overlap check and queue bookkeeping, but it
  # never touches scripts/flush-lock.sh itself in this headless run — THIS
  # script holds the lock for the whole flush, including the commit/push/PR
  # step after the session exits, so a release from inside the session
  # would free it too early. Edit(/$DIR/**) alone would reach $REPO/.git/**
  # too (the exact hook-injection attack the reviewer flagged), so a
  # --disallowedTools entry carves that out — Claude Code's deny rules win
  # over a matching allow rule (see the PR for the proof).
  PROMPT="Run the dev-loop:knowledge-flush skill's candidate pipeline now. The wiki checkout is already prepared for you at the literal path $REPO, on a fresh branch. You have NO git access at all in this run — never attempt any git command, not even a read-only one; edit files there directly with the Edit/Write tool instead.

Drain ~/.dev-loop/queue: claim pending candidates with node $PLUGIN_ROOT/hooks/queue-claim.js claim, and for each one research and verify the best-practice against real sources (WebSearch), check existing wiki layers for duplicates/links (Read + wiki_search), and check for overlapping open PRs with gh pr list --repo choiyounggi/dev-loop --state open --json number,headRefName --search \"head:knowledge/\". This headless run cannot git-diff those PRs' content the way the manual /dev-loop:knowledge-flush skill can, so if ANY open knowledge/* PR exists, treat every candidate whose domain/trigger plausibly overlaps as a pending duplicate and release its claim with node $PLUGIN_ROOT/hooks/queue-claim.js release <id> instead of ingesting it — never fold into another branch in this headless run; only the manual skill path does that.

For every other candidate, decide the target layer/category, run wiki-ingest's file edits (merge-before-create, sourced, positive-guidance) inside $REPO, and write the 4-section INGEST_REPORT (Verified best-practice / Existing-layer check with a \"Pages read:\" id list / Open-PR check / Routing decision) to $REPO/.dev-loop/INGEST_REPORT.md. Retire every claimed row (ingested, dropped-as-duplicate, or dropped-as-unverifiable) the same way the skill always does.

When you are done, if you ingested at least one insight, write the file $DIR/autoflush-result.json containing exactly {\"title\": \"<short PR title>\", \"body_file\": \"$REPO/.dev-loop/INGEST_REPORT.md\"} — a process outside this session reads that file and does the commit/push/PR with those two values as literal arguments. If you ingested nothing (empty queue, or every candidate was dropped), do NOT write that file at all.

Plugin root is literally: $PLUGIN_ROOT — use this exact path, never \${CLAUDE_PLUGIN_ROOT} or a variable, when referencing hooks/queue-claim.js. You do not need scripts/flush-lock.sh or gh api user — the process that launched you already holds the flush lock for this entire run, including the commit/push/PR step after you exit, and already set the checkout's git identity."
  ALLOWED_TOOLS="Bash(export DEV_LOOP_FLUSH_RUN_ID=*),Bash(sh $PLUGIN_ROOT/scripts/flush-lock.sh:*),Bash(node $PLUGIN_ROOT/hooks/queue-claim.js:*),Bash(gh api user:*),Bash(gh pr list --repo choiyounggi/dev-loop:*),Read,Edit(/$DIR/**),Skill,WebSearch,mcp__plugin_dev-loop_dev-loop-wiki__wiki_search"
  DISALLOWED_TOOLS="Edit(/$REPO/.git/**)"

  DEV_LOOP_FLUSHING=1 nohup "$CLAUDE_BIN" -p "$PROMPT" \
    --permission-mode default \
    --allowedTools "$ALLOWED_TOOLS" \
    --disallowedTools "$DISALLOWED_TOOLS" \
    > "$DIR/autoflush.log" 2>&1

  # --- independent, trusted-side re-check: even though the Edit deny rule
  # above should have blocked a hook/config write, never rely on a single
  # layer against a prompt-injected session — if .git/hooks or .git/config
  # changed AT ALL while the session ran, never commit what it produced. ---
  HOOKS_AFTER="$(git_integrity_hash "$REPO")"
  if [ "$HOOKS_BEFORE" != "$HOOKS_AFTER" ]; then
    abort ".git/hooks or .git/config changed during the flush session — aborting without committing"
  fi

  # --- validate the result file before trusting it enough to commit/push/PR.
  # title/body_file are DATA read out of JSON here — passed to git/gh below
  # as literal, individually-quoted arguments, never eval'd and never
  # concatenated into a string a shell re-parses. ---------------------------
  TITLE=""
  BODY_FILE=""
  if [ -f "$RESULT_FILE" ]; then
    TITLE="$(node -e '
      try {
        const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
        process.stdout.write(typeof r.title === "string" ? r.title : "");
      } catch {}
    ' "$RESULT_FILE" 2>/dev/null)"
    BODY_FILE="$(node -e '
      try {
        const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
        process.stdout.write(typeof r.body_file === "string" ? r.body_file : "");
      } catch {}
    ' "$RESULT_FILE" 2>/dev/null)"
  fi

  CHANGED="$(git -C "$REPO" status --porcelain 2>/dev/null)"
  if [ -z "$CHANGED" ]; then
    abort "no working-tree changes after the flush — nothing to commit"
  fi
  if [ -z "$TITLE" ]; then
    abort "missing/invalid $RESULT_FILE or empty title — not opening a PR"
  fi
  if [ -z "$BODY_FILE" ] || [ ! -f "$BODY_FILE" ]; then
    abort "body_file missing or does not exist — not opening a PR"
  fi
  RESOLVED_BODY="$(realpath "$BODY_FILE" 2>/dev/null)"
  RESOLVED_DIR="$(realpath "$DIR" 2>/dev/null)"
  case "$RESOLVED_BODY" in
    "$RESOLVED_DIR"/*) ;;
    *) abort "body_file resolves outside $DIR — not opening a PR" ;;
  esac

  # --- commit/push/PR: fixed shape, data passed as single arguments -------
  git -C "$REPO" add -A -- . \
    && git -C "$REPO" commit -m "knowledge: ingest insight(s) via autoflush ($RUNID)" >/dev/null 2>&1 \
    && git -C "$REPO" push -u origin "$BR" >/dev/null 2>&1 \
    && "$GH_BIN" pr create --repo choiyounggi/dev-loop --head "$BR" --title "$TITLE" --body-file "$RESOLVED_BODY" --label dev-loop:knowledge >/dev/null 2>&1 \
    || printf 'autoflush: add/commit/push/pr-create step failed\n' >> "$DIR/autoflush.log" 2>/dev/null

  sh "$FLUSH_LOCK" release >/dev/null 2>&1
) &
disown 2>/dev/null

exit 0
