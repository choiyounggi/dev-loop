# Session prompts — pick the set that matches your substrate

**tmux → §1–§4.** Injected via `tmux send-keys -l`: substitute `{...}`, then send as a
SINGLE line (no newlines).
**Orca → §O1–§O4.** NOT send-keys: each is the `--spec` body of one
`orca orchestration task-create`, one Task per task-phase, so it MAY span multiple
lines. Never tell an Orca worker to wait — it reports and ends its turn.

Tokens: `{TASK}` task id · `{STATUS_DIR}` abs path · `{SKILL}` orchestrate skill dir abs path ·
`{INTEG}` integration branch · `{BRANCH}` this session's branch · `{N}` rework round ·
`{ORCA_TASK_ID}` Orca Task id from `task-create` (§O only) ·
`{ORCA_DISPATCH_ID}` Orca Dispatch id from `orca-worker-start.sh` (§O only) — the
Dispatch is created *after* `task-create`, so on a task's first phase leave it
unsubstituted and the worker reads it from its own Orca dispatch context.

**tmux substrate.** §1–§4 — one line each, `send-keys -l`.

## tmux delivery — how §1–§4 reach a worker

§1 is injected by `launch-session.sh`, which owns the trust screen and the first
injection. Do not re-implement that path.

Every prompt after §1 — §2, §3, §4 — goes to the already-running session through
`send-prompt.sh`. Raw `send-keys` returns 0 as soon as the keys reach the pane,
which does not mean the worker took them: measured here, a prompt sent to a busy
worker sat queued and invisible for 55s while a Stop-hook chain drained.

```
sh {SKILL}/scripts/send-prompt.sh send  <session> "<the one-line prompt>"
sh {SKILL}/scripts/send-prompt.sh wait  <session> [timeout]
sh {SKILL}/scripts/send-prompt.sh state <session>
sh {SKILL}/scripts/send-prompt.sh keys  <session> <key>...
```

Branch on the exit code. stdout is exactly one token; stderr is advisory context
and must never be parsed.

| exit | `send` | `wait` | `state` | `keys` |
|------|--------|--------|---------|--------|
| 0 | delivered | picked-up | ready | sent |
| 3 | gone | gone | gone | gone |
| 4 | queued | — | busy | — |
| 5 | — | deadline expired | — | — |
| 7 | unconfirmed | — | — | — |

Shared codes: `1` usage · `2` invalid session name, prompt, or key (injection
guard / allowlist — nothing sent) · `6` tmux failed against a live session (for
`keys`: the send failed) · `127` tmux not found.

`keys` presses tmux key EVENTS in order — the way to answer an interactive
chooser or trust screen on a wedged worker. Allowlist exactly
`Up Down Left Right Enter Escape Tab Space 0-9 y n`; ALL keys are validated
before ANY is sent, so exit 2 means nothing was pressed.

Exit 4 is not a failure — the worker holds the prompt but is still mid-turn.
Follow it with `wait` (default 180s): exit 0 means the worker picked it up, exit 5
means it is still working, NOT that the prompt was lost. That distinction is the
whole point; do not retry a send on exit 5.

Exit 7 means the keys were written but the pane showed no reaction — treat it as
unknown and query `state`, never as success.

The queued/busy markers are the Claude CLI's own wording, not this repo's.
Override `LO_QUEUED_PATTERN` / `LO_BUSY_PATTERN` when a CLI release renames them.

Append the **tmux worker protocol** block below — together with the Subagent
block — to every §1–§4 prompt, flattened into the single sent line.

## (1) Plan — injected at session launch

You are the session for {TASK}. Treat .orchestration/briefs/{TASK}.md `<task_brief>` as authority — especially `<scope_boundaries>`, `<dependencies>`, and `<definition_of_done>`. Use the loop-implement skill but STOP after planning: run its step 2 with the bundled `wiki-plan` skill (make every design decision grounded in a `wiki/` page — record the decision->page map; leave nothing "as appropriate"), write the resulting implementation plan to .orchestration/plans/{TASK}.md, then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} plan_ready worktree=$PWD` and wait for an approval message. Do NOT write implementation code yet.

## (2) Implement — injected after plan approval

Approved. Implement .orchestration/plans/{TASK}.md via the loop-implement skill: respect `<effort_level>` (max 3 retries), write tests first, run them, self-review, and at step 6.5 you MUST call the test-quality-auditor subagent. Never touch anything in `<out_of_scope>`. Confirm EVERY `<definition_of_done>` item, then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} impl_done worktree=$PWD` and wait. Do not commit, push, or PR.

## (3) Rework — injected when review requests changes

Address the issues in .orchestration/reviews/{TASK}-r{N}.md via the loop-implement skill (re-run step 6.5 audit; never weaken or skip tests). Then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} impl_done worktree=$PWD` and wait.

## (4) Merge-prep — injected after final approval

Approved. Commit your changes on {BRANCH} with a conventional message (no push, no PR — the orchestrator merges into {INTEG} locally). Then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} done worktree=$PWD`. You may then stop.

## tmux worker protocol — REQUIRED block, append to every §1–§4 prompt above

[1] NEVER open a local interactive prompt and NEVER use the AskUserQuestion
    tool — no human is attached to this tmux session, so an interactive
    prompt blocks forever with nothing to show for it (the Orca set's rule
    [4], mirrored here).

[2] Blocking question — run
    `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/ask-coordinator.sh {TASK} "<question>" [options-csv]`
    (writes one pending question record — `questions/{TASK}.json`; a second
    call overwrites it), then WAIT at the REPL: the coordinator's answer
    arrives as a new prompt via send-prompt.sh. Do not poll, do not proceed
    on a guess.

**Orca substrate.** §O1–§O4 — one `--spec` per task-phase, delivered by Orca. Not
send-keys: a `--spec` MAY span multiple lines. Each phase is a separate Task, so no
prompt here says "wait" — the worker reports and ends its turn.

## (O1) Plan — `--spec` of the plan Task

You are the worker session for {TASK}. Treat .orchestration/briefs/{TASK}.md
`<task_brief>` as authority — especially `<scope_boundaries>`, `<dependencies>`, and
`<definition_of_done>`. Use the loop-implement skill but STOP after planning: run its
step 2 with the bundled `wiki-plan` skill (make every design decision grounded in a
`wiki/` page — record the decision->page map; leave nothing "as appropriate"), write the
resulting implementation plan to .orchestration/plans/{TASK}.md, then run
`STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} plan_ready worktree=$PWD`
and report exactly once:
`orca orchestration send --type worker_done --subject "plan_ready: {TASK}" --body "<what the plan decides, what remains>" --task-id {ORCA_TASK_ID} --dispatch-id {ORCA_DISPATCH_ID} --outcome succeeded --files-modified ".orchestration/plans/{TASK}.md" --json`
(a failure is `--outcome failed`, never failure encoded only in prose).
Then END YOUR TURN. Do NOT write implementation code yet.

## (O2) Implement — `--spec` of the implement Task

Approved. Implement .orchestration/plans/{TASK}.md via the loop-implement skill: respect
`<effort_level>` (max 3 retries), write tests first, run them, self-review, and at step
6.5 you MUST call the test-quality-auditor subagent. Never touch anything in
`<out_of_scope>`. Confirm EVERY `<definition_of_done>` item, then run
`STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} impl_done worktree=$PWD`
and report exactly once:
`orca orchestration send --type worker_done --subject "impl_done: {TASK}" --body "<what changed, what remains>" --task-id {ORCA_TASK_ID} --dispatch-id {ORCA_DISPATCH_ID} --outcome succeeded --files-modified "<csv>" --json`
(a failure is `--outcome failed`, never failure encoded only in prose).
Then END YOUR TURN. Do not commit, push, or PR — the orchestrator merges.

## (O3) Rework — `--spec` of the rework Task

Address the issues in .orchestration/reviews/{TASK}-r{N}.md via the loop-implement skill
(re-run step 6.5 audit; never weaken or skip tests). Then run
`STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} impl_done worktree=$PWD`
and report exactly once:
`orca orchestration send --type worker_done --subject "impl_done: {TASK} r{N}" --body "<what changed since r{N}, what remains>" --task-id {ORCA_TASK_ID} --dispatch-id {ORCA_DISPATCH_ID} --outcome succeeded --files-modified "<csv>" --json`
(a failure is `--outcome failed`, never failure encoded only in prose). Then END YOUR TURN.

## (O4) Merge-prep — `--spec` of the merge-prep Task

Approved. Commit your changes on {BRANCH} with a conventional message (no push, no PR —
the orchestrator merges into {INTEG} locally). Then run
`STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} done worktree=$PWD`
and report exactly once:
`orca orchestration send --type worker_done --subject "done: {TASK}" --body "<the commit subject + what shipped>" --task-id {ORCA_TASK_ID} --dispatch-id {ORCA_DISPATCH_ID} --outcome succeeded --files-modified "<csv>" --json`
(a failure is `--outcome failed`, never failure encoded only in prose). Then END YOUR TURN.

## Orca worker protocol — REQUIRED block, append to every §O prompt above

[1] Status stays durable — keep calling `{SKILL}/scripts/status-update.sh` at every
    phase, exactly as the tmux path does. The status files remain the re-entry state;
    the messages below sit on top of them, never instead of them.

[2] Report the phase exactly once — the `--type worker_done` send written into your §O
    prompt. One `worker_done` settles this Task, so plan / implement / rework are
    separate Tasks. `--outcome failed` is how a failure is reported.

[3] Forward a guardrails block instead of stalling on it — when a command is denied with
    an escalation notice, send
    `orca orchestration send --type escalation --subject "guardrails <rule>" --body "<command + why>" --task-id {ORCA_TASK_ID} --dispatch-id {ORCA_DISPATCH_ID} --json`.

[4] Blocking question — `orca orchestration ask --question "<q>" --timeout-ms <n> --json`,
    then end your turn. Never open a local interactive prompt: no human is attached to
    this session, so it blocks until the window expires with nothing to show for it.

[5] `{ORCA_DISPATCH_ID}` is created by `orca-worker-start.sh`, after `task-create`. If the
    orchestrator left it unsubstituted, use the dispatch id Orca gave you in this
    dispatch's own context.

[6] The Subagent usage protocol block below is REQUIRED for §O prompts too — append it.

---

## Subagent usage protocol — REQUIRED block, append to every task prompt above

[1] Test-quality audit — in loop-implement step 6.5 (after self-review, before
    "done"), you MUST call the `test-quality-auditor` subagent via the Agent tool,
    passing the brief, the diff (`git diff`), and the test file path(s).
    - VERDICT: PASS -> emit the impl_done / done signal.
    - VERDICT: FAIL -> address REASONS by strengthening tests/code (NEVER weaken
      or delete tests), increment rework count, and loop back to step 3.
    This agent is bundled with loop-orchestrator — assume it is always available.

[2] Exploration (optional) — if a large task needs token savings, you may delegate
    exploration to the core Agent tool generically. Do NOT depend on a specific
    agent name (it varies per environment).

[3] Forbidden — do not call any agent by name other than `test-quality-auditor`.
    Others (e.g. a code-reviewer) may not exist in the user's environment and will
    fail silently.
