# Knowledge flush — 3 insight(s): 1 ingested, 2 dropped as in-flight duplicates

Queue drained: `~/.dev-loop/queue/f1a3ae46-….jsonl` (3 pending rows). One new page,
no existing page rewritten, one contradiction between two open PRs flagged in `log.md`.

## Verified best-practice

### A — ingested: a worker agent's in-band question reaches nobody

**Claim.** When an agent worker runs unattended and raises a question through its own
interactive question UI, no answer arrives. With a TTY (a tmux pane) the chooser waits
indefinitely while every liveness check passes; without a TTY the tool self-resolves with
empty answers and the agent proceeds as if answered. The channel a worker uses to ask its
coordinator for a decision therefore has to be out-of-band and durable.

**Sources checked and what each supports.**

| Source | Supports | Result |
|--------|----------|--------|
| https://github.com/anthropics/claude-code/issues/50728 | no-TTY branch | `AskUserQuestion` "auto-resolves immediately with empty answers", ~37 ms, before a `can_use_tool` callback or `PreToolUse` hook can intervene; agent receives `User has answered your questions: .` Environment: `claude-agent-sdk` 0.1.63, bundled CLI 2.1.114, Docker. **Closed as not planned** — the behaviour is not being changed, which is what makes the workaround durable knowledge |
| https://github.com/anthropics/claude-code/issues/29530 | no-TTY branch, second report | Same tool "does not render any interactive UI (question text, selectable options)" and returns empty (CLI 2.1.63). **Open**, labelled `bug`, `has repro` |
| https://man7.org/linux/man-pages/man1/tmux.1.html | the unblock mechanism | `send-keys` writes key events into a pane; named keys go without `-l` (with it tmux sends the literal characters) |
| dev-loop 1.4.2 `skills/orchestrate/scripts/` (read in this checkout) | the TTY branch + the remedy, as shipped behaviour | `orca-worker-stalled.sh` header records the measurement: three workers held a live PTY on an interactive prompt for **75 minutes** with byte-identical diffs while every alive/dead check passed, and `lastOutputAt` was "measured and rejected" because a TUI repaints its spinner. `ask-coordinator.sh` is the durable channel (atomic `questions/<task>.json`, refuses task names with `/`, `.`, `..`); `watch-status.sh` surfaces it as its own exit code; `send-prompt.sh keys` validates every key against the allowlist `Up Down Left Right Enter Escape Tab Space 0-9 y n` before sending any, one `send-keys` per key. `SKILL.md` supplies the "at 600 s and 900 s both workers proceeded on a conservative assumption" measurement |
| Field observation, this session (`lo-4-qag1`) | the re-send step | 30-minute stall on a numbered chooser; two rounds of number-then-Enter (selection, then confirmation) cleared it; the prompt queued in the input line before the chooser opened was never submitted and the phase advanced only after it was re-sent |

**Confidence: `verified`.** Two published issues with reproductions cover the no-TTY branch;
the TTY branch and the remedy are backed by shipped code plus its own recorded measurements.
The one part resting on this session alone — that answering the chooser leaves a previously
queued prompt unsubmitted — is written as a single `Do this` step and attributed to the field
observation in `Sources`, not asserted as doc-backed.

### B — dropped: `worktree_escape` escalating on read-only cross-worktree access

Not ingested, and the candidate's framing is **wrong**. It claimed the rule "fires `ask` even on
read-only access". Read against the rule source (`plugins/guardrails/hooks/bash-guard.sh`,
`worktree_escape`, groundwork checkout): after stripping the worker's own worktree path and any
configured `allowPaths`, a surviving `$main_root/` mention fires **only if** a write verb
(`rm|mv|cp|tee|mkdir|touch|install|dd`) or a redirect to an absolute path also matches — and the
two tests are matched independently over the whole command string. A bare `grep`/`awk`/`git status`
read does not fire; a read sharing a command line with any write verb does. That is exactly what
open PR #51 already documents, so the candidate adds nothing and would re-introduce a wrong mechanism.

### C — dropped: Orca dispatch-binding failure taxonomy

Not ingested. The candidate's content (check for the idle prompt before binding; `runtime_unavailable`
= the turn's tail still occupies the terminal, wait and bind a *new* unit; `agent_unconfigured` = the
agent process is dead, close the terminal and create a new worker-mode agent; always pass the worktree
with the terminal) is carried by open PRs #51 and #47 in equal or better form, with the same field
evidence. Verified only far enough to confirm the overlap.

## Existing-layer check

Routed via `INDEX.md` → `infrastructure` (its route line already names multi-agent orchestration:
worker liveness signals, shared run state, tmux pane delivery, completion gates, worktree-isolated
workers) → `wiki/infrastructure/index.md` → the `agent-orchestration` category. Every page in that
category whose "load when" line could overlap was opened in full, plus the one cross-domain page the
no-TTY branch touches.

Pages read: infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-shared-run-state, platforms-processes-non-interactive-cli-invocation

| Page read | Overlap with insight A | Verdict |
|-----------|------------------------|---------|
| `…-pane-delivery-confirmation` | Owns "did the keystroke land" — busy indicator vs pane diff, serialising sends. Says nothing about *why* the target is waiting or who is supposed to answer | Adjacent, not a home. Linked both ways; step 4's "busy indicator → keep waiting" row defers to it |
| `…-control-signals-vs-primary-artifacts` | Owns done/alive/dead verdicts and has a stalled-third-state row (fresh heartbeat + unchanged artifact) | Adjacent. The wedged-on-a-question case is one cause of that state, referenced from the new page's edge cases; linked both ways |
| `…-shared-run-state` | Owns the layout of the run's shared directories (`status`, `briefs`, `escalations`) and run-id namespacing | Adjacent — the `questions/` record is a sibling of those. The new page defers path layout to it rather than restating; linked both ways |
| `…-worktree-isolated-workers` | Brief/output contract and guardrail direction. No question-channel content | No overlap |
| `platforms-processes-non-interactive-cli-invocation` | Covers a prompt-capable CLI being *invoked* from a script (detach fd 0, close the prompt channel, bracketed-paste submit). Its concern is the harness's invocation; ours is a question raised mid-turn by a worker already running | No overlap; one-way `related:` link added from the new page |

**Merge-before-create judgement.** No existing page carries the trigger "a worker asked a question
and nobody is there". The three adjacent pages each own one slice (delivery, liveness verdict, state
layout) and splitting this insight across all three would violate one-case-per-page in each of them.
New page created, all three linked bidirectionally.

**Conflicts flagged.** One, and it is between two *open PRs*, not with merged content: #47's
`worktree-isolated-workers` row says the guardrail's read/write asymmetry is version-dependent and
that "a conservative rule treats any cross-worktree path reference … reads included"; #51's row says
reads still pass alone and fire only alongside a write verb or absolute redirect. Reading the rule
source settles it in #51's favour (see "B — dropped" above). Recorded in `log.md` as a
`contradiction` entry for resolution at merge time; nothing overwritten here.

**Links added.** `related:` now bidirectional between the new page and `…-pane-delivery-confirmation`,
`…-control-signals-vs-primary-artifacts`, `…-shared-run-state`; one-way to
`…-session-completion-gates` and `platforms-processes-non-interactive-cli-invocation`.

## Open-PR check

`gh pr list` is unusable here (the ambient `gh` token returns HTTP 401 on the GraphQL API), so open
PRs were listed through the GitHub MCP REST endpoint and every knowledge head was fetched and diffed
locally: `git fetch origin <head>` then `git diff origin/main FETCH_HEAD -- wiki/`.

Open `knowledge/*` heads at flush time (11): #62, #61, #58, #57, #56, #55, #52, #51, #50, #49, #47.
(#63 is `feat/role-model-selection`, not a knowledge PR.)

| Candidate | Overlapping open head(s) | Verdict |
|-----------|--------------------------|---------|
| A — unattended worker questions | none. Every open head's `wiki/` diff was grepped for `menu` / `interactive` / `send-keys` / `prompt-capable`; the only hits are `related:` id lists and an unrelated job-control row in #57 | **new** — ingested |
| B — `worktree_escape` on read-only access | **#47** (`worktree-isolated-workers` edge row + a field-evidence source line with the same Wave-2 `awk`/`grep`/`git status` evidence) and **#51** (same page, mechanism-accurate rows plus a local reproduction) | **drop** — pending duplicate, twice over, and the candidate's own wording is the mechanism #51 corrects. Nothing unique to fold; the correction that *is* new (the rule source settles #47 vs #51) is recorded in `log.md` rather than pushed into either branch |
| C — Orca dispatch-binding taxonomy | **#51** (`pane-delivery-confirmation`: four new edge rows — bind only at the idle prompt, `runtime_unavailable` → wait and bind a fresh unit, `agent_unconfigured` → replace the agent, pass the worktree with the terminal — plus an `Instead of` row) and **#47** (`control-signals`: the done-signal-is-not-release-time row) | **drop** — pending duplicate with nothing new |

No sibling duplicate PR was opened, and nothing was pushed to another contributor's branch.

## Routing decision

| Insight | Target | New category? |
|---------|--------|---------------|
| A | `infrastructure` / `agent-orchestration` / **new page** `unattended-worker-questions.md` (id `infrastructure-agent-orchestration-unattended-worker-questions`) | No — `agent-orchestration` already exists and its scope line in `INDEX.md` covers worker liveness signals and tmux pane delivery. This is a sixth page in it |
| B | none (retired) | — |
| C | none (retired) | — |

`applies_to: [tmux, general]` — the detect/unblock half is multiplexer-specific, the
channel-design half is not. Domain index gained a "load when" row for the new page; `log.md`
gained one `ingest` entry and one `contradiction` entry.

Files changed: `wiki/infrastructure/agent-orchestration/unattended-worker-questions.md` (new, 76 body
lines), `wiki/infrastructure/index.md`, three `related:` back-links, `log.md`.
