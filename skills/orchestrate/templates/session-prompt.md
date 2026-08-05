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

## (1) Plan — injected at session launch

You are the session for {TASK}. Treat .orchestration/briefs/{TASK}.md `<task_brief>` as authority — especially `<scope_boundaries>`, `<dependencies>`, and `<definition_of_done>`. Use the loop-implement skill but STOP after planning: run its step 2 with the bundled `wiki-plan` skill (make every design decision grounded in a `wiki/` page — record the decision->page map; leave nothing "as appropriate"), write the resulting implementation plan to .orchestration/plans/{TASK}.md, then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} plan_ready worktree=$PWD` and wait for an approval message. Do NOT write implementation code yet.

## (2) Implement — injected after plan approval

Approved. Implement .orchestration/plans/{TASK}.md via the loop-implement skill: respect `<effort_level>` (max 3 retries), write tests first, run them, self-review, and at step 6.5 you MUST call the test-quality-auditor subagent. Never touch anything in `<out_of_scope>`. Confirm EVERY `<definition_of_done>` item, then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} impl_done worktree=$PWD` and wait. Do not commit, push, or PR.

## (3) Rework — injected when review requests changes

Address the issues in .orchestration/reviews/{TASK}-r{N}.md via the loop-implement skill (re-run step 6.5 audit; never weaken or skip tests). Then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} impl_done worktree=$PWD` and wait.

## (4) Merge-prep — injected after final approval

Approved. Commit your changes on {BRANCH} with a conventional message (no push, no PR — the orchestrator merges into {INTEG} locally). Then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} done worktree=$PWD`. You may then stop.

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
