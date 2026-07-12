# Session prompts — one line each, injected via `tmux send-keys -l`

Substitute `{...}` then send as a SINGLE line (no newlines). Tokens:
`{TASK}` task id · `{STATUS_DIR}` abs path · `{SKILL}` orchestrate skill dir abs path ·
`{INTEG}` integration branch · `{BRANCH}` this session's branch.

## (1) Plan — injected at session launch

You are the session for {TASK}. Treat .orchestration/briefs/{TASK}.md `<task_brief>` as authority — especially `<scope_boundaries>`, `<dependencies>`, and `<definition_of_done>`. Use the loop-implement skill but STOP after planning: run its step 2 with the bundled `wiki-plan` skill (make every design decision grounded in a `wiki/` page — record the decision->page map; leave nothing "as appropriate"), write the resulting implementation plan to .orchestration/plans/{TASK}.md, then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} plan_ready worktree=$PWD` and wait for an approval message. Do NOT write implementation code yet.

## (2) Implement — injected after plan approval

Approved. Implement .orchestration/plans/{TASK}.md via the loop-implement skill: respect `<effort_level>` (max 3 retries), write tests first, run them, self-review, and at step 6.5 you MUST call the test-quality-auditor subagent. Never touch anything in `<out_of_scope>`. Confirm EVERY `<definition_of_done>` item, then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} impl_done worktree=$PWD` and wait. Do not commit, push, or PR.

## (3) Rework — injected when review requests changes

Address the issues in .orchestration/reviews/{TASK}-r{N}.md via the loop-implement skill (re-run step 6.5 audit; never weaken or skip tests). Then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} impl_done worktree=$PWD` and wait.

## (4) Merge-prep — injected after final approval

Approved. Commit your changes on {BRANCH} with a conventional message (no push, no PR — the orchestrator merges into {INTEG} locally). Then run `STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} done worktree=$PWD`. You may then stop.

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
