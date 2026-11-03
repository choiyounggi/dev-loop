# Knowledge flush — 4 insight(s) (headless auto-flush run, claims 20261103-141924-81381)

12 queue rows were claimed this run: 4 ingested (all merged into existing pages,
no new page), 8 released. Nothing was dropped and nothing was folded into another
branch.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `4a4d2d93a546c007` — multi-turn `claude -p --input-format stream-json` child runs the user's side-effect Stop hooks every turn; off switches via `--settings` env | platforms | **ingested** — `platforms-processes-spawning-an-agent-cli-from-a-server` step 5 + edge row; pointer row in `platforms-shells-env-var-off-switches` (verified) |
| `b426bd7890dbefb1` — capture proxy under a gateway: chain upstream to `ANTHROPIC_BASE_URL`, not api.anthropic.com | platforms (hint: debugging) | **ingested** — same page: allow-list row, edge row, Instead-of row (verified) |
| `6ee0f099480423ae` — `CLAUDE_CODE_SUBAGENT_MODEL` does not move the built-in Explore subagent | platforms | **ingested** — edge row in `platforms-tools-per-call-subagent-effort` (verified) |
| `11f15aebd9a88007` — strip parent `CLAUDE_CODE_*` before spawning a child `claude` to observe it | platforms (hint: debugging) | **ingested (narrowed)** — allow-list row + field-observed edge row on the spawning page; the unconfirmed causes are not stated (field-tested part only) |
| `fc76dc4dfa08ecde` — Docker-gated schema validator: skip vs fail, known-bad document | testing | released — plausible overlap with open PRs #300 / #317 |
| `df1515d721c90d64` — gate CHECK timeout when one check runs the suite N times | testing | released — plausible overlap with open PR #317 |
| `63053db1289c8c67`, `ff1c87af4b580dfb`, `baa5d1ff9bb87683`, `97bbff78b9f5c7fc`, `850083307d5abc22`, `a3d296b1c4070ff3` | unknown | released unread — queue file not locatable in this run (see below) |

The headless sandbox blocked listing `~/.dev-loop/queue/` and `node -e`. Queue files
can only be opened by guessing session-id file names from `~/.claude/history.jsonl`.
Six rows were not found that way — most likely they come from headless child
`claude` sessions (the capture experiments), whose ids never reach the history file.
They were released (confirmed with `queue-claim.js list`, which printed all 8
released ids) for the manual skill to process. The `wiki_search` MCP tool was also
denied in this run, so the existing-layer check read index files and pages directly.

## Verified best-practice

**`4a4d2d93a546c007` — confidence: verified.** Claim: a child Claude Code that keeps
`HOME` runs the user's `Stop` hooks after every response, so a multi-turn stream-json
child repeats auto-publish/auto-PR hooks once per turn. A shell export of the hook's
off switch is overwritten by the user's `settings.json` `env`. `--settings
'{"env":{…}}'` outranks user settings and reaches hook processes.
- https://code.claude.com/docs/en/hooks — "Per turn" events are `UserPromptSubmit`,
  `Stop`, `StopFailure`; Stop runs when the main agent has finished responding and has
  no matcher. The docs do not say outright that this holds under
  `--input-format stream-json`; the field case covers that part.
- https://code.claude.com/docs/en/settings — precedence managed > command-line
  arguments (`--settings`) > local > project > user; a settings `env` value
  "overwrites the same variable exported in your shell" and applies to subprocesses;
  `--settings '{"disableAllHooks": true}'`; the Desktop-app / self-hosted-runner
  exception.
- Field case (session evidence, 2026-11-03, Claude Code 2.1.317): six Stop events in
  a six-turn session log; a probe Stop hook recorded `AUTO_VELOG_AUTODRAFT=0
  PROBE_X=from-settings`; dev-loop auto-flush printed only its notice in place of the
  user setting `DEV_LOOP_AUTOFLUSH=1`.
- Both doc lines came from web-search summaries of the pages; WebFetch is not
  allowed in this run, so no page was fetched.

**`b426bd7890dbefb1` — confidence: verified.** Claim: under an LLM gateway, the child
inherits `ANTHROPIC_AUTH_TOKEN`, a bearer credential only the gateway accepts; a
capture proxy forwarding to api.anthropic.com gets 401.
- https://code.claude.com/docs/en/llm-gateway-connect — `ANTHROPIC_BASE_URL` points at
  the gateway, `ANTHROPIC_AUTH_TOKEN` is sent as `Authorization: Bearer`; with a
  gateway configured, a 401's text comes from the gateway and `/login` does not fix it.
- Field case: first capture attempt 401 `authentication_error`; with the proxy
  upstream set to the parent's `ANTHROPIC_BASE_URL`, three 200 responses.

**`6ee0f099480423ae` — confidence: verified.** Claim: `CLAUDE_CODE_SUBAGENT_MODEL`
moved a general-purpose subagent but not Explore.
- https://code.claude.com/docs/en/sub-agents#choose-a-model — "Setting
  `CLAUDE_CODE_SUBAGENT_MODEL` by itself doesn't change the model the built-in
  Explore and Plan subagents run on"; the env var ranks below per-call and
  frontmatter `model`; `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (v2.1.257+) applies one
  model to all; a user/project subagent named `Explore` overrides the built-in.
- The docs strengthen the candidate: it said "Explore uses the parent model" for
  2.1.317 only; the ingested row states the documented mechanism and both fixes
  (FORCE, user `Explore`) and adds Plan.
- Field case: clean-environment capture — general-purpose request `model`
  `claude-sonnet-5-5`, Explore request `model` `claude-opus-5-5`.

**`11f15aebd9a88007` — confidence: field-tested (narrowed).** Claim: a child `claude`
started inside a session inherits `CLAUDE_CODE_*` variables and may behave
differently from a standalone run.
- https://code.claude.com/docs/en/plugin-hints — Claude Code sets `CLAUDECODE=1` in
  Bash-tool and hook commands and `CLAUDE_CODE_CHILD_SESSION=1` on v2.1.172+. That
  backs "the child sees itself as nested".
- The candidate's two observed effects were not both confirmed. "Subagent model not
  applied" is explained by `6ee0` (the request was an Explore subagent), so it is
  not cited as env inheritance. "Interactive session record not saved" stays as a
  field observation marked "cause not isolated". The directive itself (start the
  child under the existing step-1 `env -i` allow-list and record any variable kept)
  needs no new claim; it applies the page's existing allow-list rule.

## Existing-layer check

Pages read: platforms-processes-spawning-an-agent-cli-from-a-server, platforms-tools-per-call-subagent-effort, platforms-shells-env-var-off-switches

Indexes read: `INDEX.md`, `wiki/platforms/index.md` (full).

- **platforms-processes-spawning-an-agent-cli-from-a-server** — owns the child
  `claude` environment (allow-list of `PATH`/`HOME`/`CLAUDE_CODE_DISABLE_*`, cwd
  outside a work tree). `b426` and `11f1` are rows of that same allow-list table
  (gateway pair; parent `CLAUDECODE`/`CLAUDE_CODE_*`), and `4a4d` is the settings
  half of the same spawn decision (which hooks the child runs). Merged: trigger
  widened from "server" to "server, script, or another Claude Code session"; two
  allow-list rows; step 5 with a two-row Need/Do table; three edge rows; one
  Instead-of row; four doc sources + one field-case source; `related:` +
  `platforms-shells-env-var-off-switches`, `platforms-tools-per-call-subagent-effort`;
  `last_verified` 2026-11-03, `verified_model` claude-opus-5-5. Body is 110 lines
  (≤ 120). No conflict with existing directives: the allow-list rule already strips
  everything not named, the new rows only name two more variables explicitly.
- **platforms-tools-per-call-subagent-effort** — its Sources already cite the
  sub-agents model order and `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`, and an edge row
  covers FORCE. The Explore/Plan exemption was missing. Merged as one edge row,
  one doc source line, one field-case line; "When this applies" gained the
  "subagent model does not move" trigger; `last_verified` 2026-11-03.
- **platforms-shells-env-var-off-switches** — its trigger "a feature you turned off
  keeps running" matches `4a4d`'s shell-export symptom. Added one pointer edge row
  to the spawning page's step 5 and a `related:` id; no directive change there.
- `platforms-processes-non-interactive-cli-invocation` and
  `platforms-tools-deny-rules-under-bypassed-permissions` were judged from their
  index lines only (stdin/timeouts; permission deny rules) — different triggers,
  not opened, not edited.

Reviewer note: the repo's bats directive-count test (the "directive count" in
earlier log entries) was not run here — Bash is limited to the queue and `gh pr
list` in this headless run. Step 5 is a new numbered directive on the spawning
page; bump the count if that test fails.

## Open-PR check

Open `knowledge/*` heads at flush time (`gh pr list --repo choiyounggi/dev-loop
--state open --json number,headRefName --search "head:knowledge/"`): #324, #319,
#318, #317, #315, #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298,
#293. This headless run cannot `git diff` them; overlap was judged from each PR's
title, changed-file list and report body (`gh pr list ... --json
number,title,files,body`).

| Row | Overlapping open PR | Verdict |
|-----|---------------------|---------|
| `4a4d2d93a546c007` | None. No open PR edits `spawning-an-agent-cli-from-a-server.md`, `env-var-off-switches.md`, or any hooks/settings-precedence page. #300 edits `platforms/tools/deny-rules-under-bypassed-permissions.md` (permission deny rules — different trigger); #299 edits `command-text-inspected-before-execution.md` (PreToolUse gates on command text) | new |
| `b426bd7890dbefb1` | None by trigger. #298 adds `backend/common/llm/gateway-model-alias-resolution.md`, which is about LiteLLM model aliases (`/model/info`), not gateway auth or proxy chaining | new |
| `6ee0f099480423ae` | None. No open PR edits `per-call-subagent-effort.md` or any subagent-model page | new |
| `11f15aebd9a88007` | None by trigger. #309 adds `tmux-server-environment-at-start.md` (tmux copies the client env into the server at start) — env inheritance, but a different mechanism and trigger | new |
| `fc76dc4dfa08ecde` | #300 and #317 edit `testing/quality/checks-that-cannot-pass.md` (#300 also `tests-that-cannot-fail.md`); a skipped or always-valid validator is their theme. Same verdict as runs #318/#319/#324 | released (pending duplicate) |
| `df1515d721c90d64` | #317 ("self-matching gate CHECKs … done-gates") edits `checks-that-cannot-pass.md` and `completion-predicates.md`; a check killed by its timeout reads as a check that cannot pass. Same verdict as run #324 | released (pending duplicate) |
| 6 unread rows | not compared (unread) | released |

## Routing decision

- `4a4d2d93a546c007`, `b426bd7890dbefb1`, `11f15aebd9a88007` →
  `platforms` / `processes` → merged into
  `wiki/platforms/processes/spawning-an-agent-cli-from-a-server.md`. `b426` and
  `11f1` carried a `debugging` hint, but their directives are about how to build
  a child process's environment, which this page owns. The diagnosis (401, missing
  transcript) is only the symptom.
- `6ee0f099480423ae` → `platforms` / `tools` → merged into
  `wiki/platforms/tools/per-call-subagent-effort.md` (the page that already holds
  the subagent model order and `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`).
- Pointer only: `wiki/platforms/shells/env-var-off-switches.md` (one edge row).
- `wiki/platforms/index.md` load-when lines extended for all three pages. No new
  page, category or domain, so `INDEX.md` was not edited.
- `log.md` has one entry appended for this run.

## Local-layer candidates

none
