# Knowledge flush — 3 insight(s)

Queue drained: `~/.dev-loop/queue/3b771258-….jsonl`, 3 pending candidates, all
orchestration/harness-platform. **2 ingested here, 1 folded into PR #64.**

## Verified best-practice

### C1 — a worker paused by a provider usage limit *(folded into PR #64, not in this PR)*

**Claim.** When several workers billed to one account go quiet at once, look for the
`You've hit your … limit · resets …` marker before classifying the stall; wait for the
stated reset, then resume with a prompt that names the state re-check, the remaining
done-criteria, and the completion signal.

**Sources checked.**
- `https://code.claude.com/docs/en/errors` — the three marker forms appear **verbatim**
  (`You've hit your session limit · resets 3:45pm`, `… weekly limit · resets Mon 12:00am`,
  `… Opus limit · resets 3:45pm`); "Claude Code **blocks further requests** until the reset
  time"; "The session and weekly limits are **shared across all models**, so switching models
  doesn't restore access"; "The Opus limit **applies only to Opus requests**".
- `https://code.claude.com/docs/en/costs` — "a per-seat allowance that resets on a rolling
  five-hour window and a weekly window… shared with Claude chat and Cowork", and "a single
  burst of heavy activity, such as a large workflow fanout, can exhaust the weekly allowance".
  This is the mechanism behind a *synchronized* multi-worker stop.
- `https://github.com/anthropics/claude-code/issues/5977` — the "continue"-loses-context
  failure the re-orient prompt exists to prevent (closed as duplicate).
- `https://github.com/anthropics/claude-code/issues/36320` — auto-resume is still an open
  feature request, so the orchestrator owns the re-drive.

**Confidence: verified.** The candidate's marker string matched official docs exactly, and
the docs added a correction the field observation did not have: an *Opus* limit **is** cleared
by `/model`, while session/weekly limits are not.

### C2 — reusing a worker's terminal after its completion report

**Claim.** `worker_done` settles the task, not the terminal; gate the next `worker-start`
on `orca terminal wait --for tui-idle`, and recover a failed start through a new/linked
dispatch rather than re-running it, because 3 consecutive failures circuit-break the task.

**Sources checked — read live from the installed CLI this session, not from memory:**
- `orca skills get --topic orchestration --full` — "Wait for `tui-idle` before dispatching"
  (line 377); "After processing each accepted `worker_done`, choose the terminal's next owner
  before you acknowledge the Delivery or wait again… `worker-start --task <next_task_id>
  --terminal <handle>` so Orca transfers cleanup ownership to the new Dispatch. Otherwise run
  `orca orchestration worker-release`" (line 242); "After 3 consecutive failures on one task,
  the dispatch context circuit-breaks and the task is marked failed" (line 176); "Treat a
  `check --wait` timeout or `{count:0}` as a checkpoint, not a worker failure" (line 146).
- `orca orchestration worker-start --help` — "The call exits 0 only for ready. Failed or
  outcome_unknown exits 1 and JSON includes stage/failedStage, setup, effects,
  residualResources, and recovery commands"; "--retry-of links the replacement attempt but
  does not inherit placement".
- `orca terminal wait --help` — `--for exit|tui-idle` confirmed.

**Confidence: verified** (official tool guide + reproducible `--help` output, plus a
2026-08-06 field reproduction: two dispatches issued immediately after `worker_done` both
failed `runtime_unavailable` and consumed an attempt; both succeeded after an idle check).

### C3 — a classifier denies a tool call the agent was told to make

**Claim.** Read the denial as one of four tiers; only `soft_deny` is cleared by an `allow`
entry or by the user naming the exact action in their next message. Write permission/`autoMode`
config at **user** scope.

**Sources checked.**
- `https://code.claude.com/docs/en/auto-mode-config` — confirmed **verbatim**: the four-tier
  precedence; "Explicit user intent overrides the remaining soft blocks: if the user's message
  directly and specifically describes the exact action Claude is about to take, the classifier
  allows it even when a `soft_deny` rule matches"; "General requests don't count as explicit
  intent"; "The classifier doesn't read `autoMode` from project settings in
  `.claude/settings.json` or `.claude/settings.local.json`… Before v2.1.207, the classifier
  also read `.claude/settings.local.json`"; the `"$defaults"` splice and what omitting it
  discards; `classifyAllShell` (v2.1.193+); the `Blocked by classifier` fixed reason (v2.1.208+)
  and `defaults --label`; `/permissions` → **Recently denied** → `r`.
- `https://github.com/anthropics/claude-code/issues/58222` — *"Auto-mode classifier blocks
  authorized operator workflows"*, closed as **not planned** (state re-checked via the API this
  session).
- `https://github.com/anthropics/claude-code/issues/64128` — *"`allow` rules silently ignored…
  self-modification block contradicts documented escape hatch"*, closed as **not planned**.

**Confidence: verified.** Note the page deliberately does **not** adopt the candidate's stronger
directive ("fresh explicit consent makes the same edit pass"). The 2026-08-09 field observation
varied **two** variables at once — settings scope *and* consent — so it cannot isolate consent as
the cause, and the docs say the classifier ignores project-scoped `autoMode` entirely. The page
records the observation as supporting the documented precedence, and keeps the reported
self-modification denials (which persisted *despite* prior-turn authorization) as an edge case.

## Existing-layer check

Routed both ingested candidates via `INDEX.md` → **infrastructure** (multi-agent orchestration)
and **platforms** (agent-harness tooling), then read every page in those categories whose
"load when" line overlaps.

Pages read: infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-dispatching-after-a-completion-report, platforms-tools-agent-permission-classifier-denials, platforms-tools-harness-mediated-tool-results, platforms-tools-bsd-vs-gnu-cli, platforms-tools-version-keyed-artifact-cache, platforms-shells-command-text-inspected-before-execution, platforms-processes-driving-a-tui-in-a-tmux-pane

**Overlaps and what happened.**

| Candidate | Nearest existing page | Verdict |
|---|---|---|
| C2 | `control-signals-vs-primary-artifacts` covers *is the worker alive/done/dead*; `session-completion-gates` covers *blocking a session from ending* | Neither covers reusing a **settled dispatch's terminal**. New page. |
| C3 | `harness-mediated-tool-results` covers a harness returning **substitute content**; `command-text-inspected-before-execution` covers a **rule-based text gate** | Neither covers a **model-based** second gate with tiered escapes. New page, cross-linked to both. |
| C1 | see Open-PR check | Folded into PR #64. |

**Correction worth flagging to the reviewer.** Both ingested pages already existed as
**untracked files in the shared flush checkout** (`~/.dev-loop/repo`) — drafted by an earlier
flush session that never committed or PR'd them. `git log origin/main -- <path>` returns
nothing for both, and no open `knowledge/*` head contains either. That is almost certainly why
these two candidates were still `pending` in the queue. This PR commits them for the first
time; I re-verified every cited source from scratch (see above) rather than trusting the drafts,
and refreshed `last_verified` to 2026-08-12.

**Conflicts flagged:** none. Neither page contradicts an existing directive.

**Related-links added (both ways, per wiki-ingest step 7):** `session-completion-gates` →
`dispatching-after-a-completion-report`; `harness-mediated-tool-results` and
`command-text-inspected-before-execution` → `agent-permission-classifier-denials`. Reciprocal
links into `control-signals-vs-primary-artifacts`, `pane-delivery-confirmation`,
`shared-run-state`, and `worktree-isolated-workers` were **deliberately skipped**: PRs #47, #51,
and #64 are all editing exactly those `related:` lines, and adding a fourth edit guarantees a
merge conflict. The forward links from the new pages already resolve, so no invariant is broken.

**Pre-existing lint finding, left alone (not introduced here):**
`wiki/mobile/release/staged-rollout-and-hotfix.md` has `related: [mobile-performance-startup-time]`,
which resolves to no page on `main`.

**Invariants re-checked after the edit:** every `related:` id and inline `[page-id]` in the two
new pages resolves; both new pages are listed in their domain `index.md`; both bodies are 72
lines (≤120); `log.md` appended.

## Open-PR check

Listed all 20 open `knowledge/*` PRs and diffed each head's `wiki/` against `main`
(7 of them are fork PRs whose heads are not on `origin` — those were fetched via
`pull/<n>/head`, which is why a naive `git fetch origin <branch>` shows them as empty).

Heads touching either target area: **#64, #47, #51** (`agent-orchestration`); **none**
touch `platforms/tools/`.

| Candidate | Overlapping head | Verdict |
|---|---|---|
| C1 usage-limit stall | **#64** — its new `unattended-worker-questions.md` already carries the case as one row of its stall-classification table (*"A usage-limit or re-auth notice → Idle waiting, not a crash; resume after the stated reset"*) | **fold** |
| C2 dispatch-after-completion | #47 / #51 touch `control-signals` and `worktree-isolated-workers`; neither adds terminal-reuse content | **new** |
| C3 classifier denial | none | **new** |

**Fold executed, not just noted.** Pushed to `knowledge/choiyounggi-20260808-004155` (PR #64):
a new `usage-limit-paused-workers.md` (73 body lines) plus that branch's index row, the
reciprocal `related:` link, and its `log.md` entry; #64's one-line row now points at the page
instead of being duplicated here. Commented on #64 explaining the fold. **No sibling duplicate
PR was opened for C1.**

While doing this I noticed my first fold commit had swept the two untracked leftover drafts
into #64 via `git add wiki/`. That commit was amended and force-pushed, so **#64's diff is back
to its own scope plus the one folded page** — worth a glance when you review it.

## Routing decision

| Insight | Target | New category? |
|---|---|---|
| C1 usage-limit stall | `infrastructure/agent-orchestration/usage-limit-paused-workers` — **on PR #64's branch** | No |
| C2 dispatch-after-completion | `infrastructure/agent-orchestration/dispatching-after-a-completion-report` — **this PR** | No |
| C3 classifier denial | `platforms/tools/agent-permission-classifier-denials` — **this PR** | No |

**Domain re-routing.** All three candidates carried the harvested hint `domain: platforms`.
C1 and C2 were re-routed to **infrastructure**, whose `INDEX.md` line explicitly owns
"multi-agent orchestration (worker liveness signals, shared run state, tmux pane delivery,
completion gates, worktree-isolated workers)"; `platforms` owns OS/shell/tool-invocation
differences, which is where C3 belongs (`tools`, alongside `harness-mediated-tool-results` —
both are about an agent harness altering what a tool call does).

No new category was needed: `agent-orchestration` and `platforms/tools` both already exist and
cover these triggers.

## Queue

All 3 rows retired to `~/.dev-loop/queue/.processed.jsonl` (2 ingested, 1 folded); the session
file is now empty and removed.
