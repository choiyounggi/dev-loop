<!-- Orchestrator -> worker prompts (orchestrate Phases 3-4).

     Each numbered section is delivered as ONE line: launch-session.sh (tmux) and
     `terminal send` / a dispatch `--spec` (Orca) all take a single-line prompt.
     Keep the substitutions on one line — a newline submits the prompt early and
     the rest is lost.

     Substitutions used below:
       <task>        task id, also the status-file name and the tmux session name
       <status-dir>  absolute path to .orchestration/status
       <scripts>     absolute path to this plugin's skills/orchestrate/scripts
       <round>       rework round number (1-based)
-->

## §1 — plan

Read briefs/<task>.md in full, then run the dev-loop loop-implement skill for it and STOP after planning: write the plan to plans/<task>.md, then run `STATUS_DIR=<status-dir> sh <scripts>/status-update.sh <task> plan_ready planPath=plans/<task>.md`. Do not start implementing. <subagent-protocol> <lifecycle>

## §2 — implement

Implement plans/<task>.md with the dev-loop loop-implement skill, tests first, staying inside this worktree and only in the affected files listed in briefs/<task>.md; when every done criterion in the brief passes, run `STATUS_DIR=<status-dir> sh <scripts>/status-update.sh <task> impl_done`. If you cannot finish, run the same command with `failed error="<one line>"` instead of reporting success. <subagent-protocol> <lifecycle>

## §3 — rework

Read reviews/<task>-r<round>.md and fix every point it raises without weakening or deleting any existing test; re-run the task's verify command, then run `STATUS_DIR=<status-dir> sh <scripts>/status-update.sh <task> impl_done reworkCount=<round>`. If a point is wrong, say so in the status `error=` field rather than silently skipping it. <subagent-protocol> <lifecycle>

## `<subagent-protocol>` block

Append this to every prompt above. It keeps the self-grading guard intact:

> Before you report impl_done, get the bundled test-quality-auditor agent to audit your own diff and tests, and fix whatever it returns; the session that wrote the code does not grade its own tests.

## `<lifecycle>` block

**tmux substrate** — nothing extra. The status file is the only channel; the
orchestrator polls it with `watch-status.sh`, and a guardrails `ask` that gets
escalated is picked up from `.orchestration/escalations/`.

**Orca substrate** — append this as well, filling in the ids the dispatch gave
you. The status file stays the durable re-entry state; these messages are what
actually wake the coordinator (see orchestrate's O1-O5):

> Report exactly once when this phase is done: `orca orchestration send --type worker_done --subject "<short status>" --body "<what changed, what remains>" --task-id <task_id> --dispatch-id <dispatch_id> --outcome succeeded|failed --files-modified "<a,b>" --json`. If a command is denied with a guardrails escalation notice, do not stall — send it up: `orca orchestration send --type escalation --subject "guardrails <rule>" --body "<command + why>" --task-id <task_id> --dispatch-id <dispatch_id> --json`. If you are blocked on a decision only the coordinator can make, ask and wait: `orca orchestration ask --question "<q>" --timeout-ms <n> --json`. After reporting, end your turn and idle — do not poll.
