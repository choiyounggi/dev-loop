---
id: infrastructure-agent-orchestration-control-signals-vs-primary-artifacts
domain: infrastructure
category: agent-orchestration
applies_to: [general, tmux, git-worktree]
confidence: verified
sources:
  - https://man.openbsd.org/tmux
  - https://code.claude.com/docs/en/hooks
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
last_verified: 2026-08-06
related: [infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-session-completion-gates, platforms-shells-command-text-inspected-before-execution, platforms-tools-harness-mediated-tool-results, debugging-methodology-hypothesis-testing, infrastructure-agent-orchestration-unattended-worker-questions]
---

# Deciding a Worker Is Done, Alive, or Dead from a Status File or Watcher Verdict

## When this applies

An orchestrator decides to restart, discard, merge, or keep waiting on a worker
based on a status file, a watch/monitor script's exit code, or a heartbeat; the
workers run on a substrate (tmux panes, a task runner, containers) whose liveness
model differs from what the monitor assumes; or a worker is reporting its own
progress by running a script that writes outside its worktree.

## Do this

1. **Treat every control signal as a hint that something changed, and confirm the
   claim against the primary artifact before acting.** The primary artifact is the
   thing the claim is about, not a record of it:

| Claim from the signal | Confirm with |
|-----------------------|--------------|
| "task complete" | `git log --oneline <branch>` and `git status` in that worktree — the commit exists or it does not |
| "worker dead" | The substrate's own liveness call (runtime/task API, `tmux has-session -t <exact-session>`, container inspect) *plus* whether new commits appeared since the last check |
| "worker produced file X" | `test -e`/`stat` on X |
| "nothing happened yet" | Worker log mtime; an idle-looking worker mid-run and a worker that never started look identical from the status file |

2. **Emit and consume status by an exact identifier the orchestrator assigned.**
   Have the worker write the run-scoped task id the orchestrator gave it, not an
   identifier it discovers from its environment. A discovered identifier can name
   a different process: `tmux display-message -p '#S'` run with `TMUX` unset does
   not fail — it resolves against the server's current/most-recently-used session
   and prints an unrelated session's name with exit 0.

3. **Verify the status write landed, in the same step that writes it.** After
   calling the status script, `stat` the status file itself and compare its
   mtime. A command blocked by a policy gate produces no side effect, and a
   guardrail scoped to an absolute path fires on the command *text* regardless of
   the command's purpose — including the orchestration harness's own scripts.

4. **When the status write was blocked, report the signal as un-emitted and hand
   it back to the orchestrator.** Say which path was refused and by which rule.
   The orchestrator can re-route the signal; a worker that retries or works around
   a path guardrail defeats the isolation the worktree exists to provide.

5. **Give a "dead worker" verdict a second, substrate-specific witness before
   acting on it.** Restarting or discarding live work is unrecoverable in a way
   that waiting one more interval is not.

## Edge cases

| Case | Then |
|------|------|
| Monitor exit code says dead, substrate says alive | Believe the substrate and keep waiting. Log the disagreement with both outputs — a monitor keyed on the wrong identifier repeats the verdict every interval |
| Status file is absent | Distinguish "never written" from "write blocked": check the worker's transcript for a gate/escalation message before assuming the worker never started |
| Worker ran the status script and saw no output | No output is not success. A blocked Bash command and a silent successful run are indistinguishable on stdout; only the file's existence separates them |
| An editor/Write tool succeeds where Bash was refused for the same path | The guardrail inspects Bash command text only, so the two channels disagree by design. Do not use the working channel to route around the rule — report it |
| Heartbeat is fresh but no commits in N intervals | Fresh heartbeat plus unchanged primary artifact is the stalled state, distinct from alive-and-progressing and from dead; handle it as its own case |
| The monitor is the only thing that can see the worker | Add the primary-artifact check to the monitor rather than trusting its verdict; a monitor with no artifact check cannot produce evidence |
| Several workers go quiet almost simultaneously: liveness checks pass, heartbeats stay fresh, diffs stop growing | Before restarting anything, search each worker's pane/terminal tail for the CLI's usage-limit marker (e.g. `You've hit your session limit · resets HH:MM`) — a usage-limit pause is idle waiting, not a crash, so every liveness probe passes. After the stated reset time, send a resume prompt that orders: re-verify state (`git status`, rerun the tests) → remaining definition-of-done → completion signal. A bare "continue" sent before the reset is consumed by the same limit message, and a resume without the state re-check makes the worker guess where it stopped |
| The next task is dispatched to the same terminal immediately after the worker's done signal and fails runtime-unavailable | The done message is the worker's report time, not the substrate's release time — the CLI is still tearing down its stop-hook chain and the previous dispatch still occupies the terminal. Wait for the substrate's own idle signal (e.g. `orca terminal wait --for tui-idle`) before dispatching; and when the failed dispatch consumed the task, create a new task from the same spec — the consumed one cannot be retried |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Restart a worker because the watch script exited "dead" | Run the substrate liveness call and `git log` on its branch first | The verdict can come from an identifier the worker picked up from its environment, naming a different process entirely |
| Let a worker resolve its own session/pane id for the status file | Pass the orchestrator-assigned task id into the worker and have it echo that back | Discovered identifiers are ambient state; assigned ids are the orchestrator's own namespace |
| Trust a status script's silence as "signal sent" | `stat` the status file after the call and report the mtime | A gate-blocked command exits without writing and without printing |
| Retry a blocked status write with a rewritten path | Report the block and the rule id to the orchestrator | The rule is protecting the shared checkout; a workaround reintroduces exactly the corruption it prevents |

## Sources

- https://man.openbsd.org/tmux — `has-session`, `display-message` behavior and session naming
- https://code.claude.com/docs/en/hooks — hook architecture and path guardrails
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — exit codes and output redirection
- Field evidence 2026-08-06 (Claude CLI workers under tmux/Orca orchestration): three workers paused simultaneously on one usage-limit reset — identical `You've hit your session limit · resets 01:10` marker in each terminal tail while every liveness check passed; a state-recheck resume prompt sent after the reset resumed all three exactly at their interrupted step (test re-run). Same run: two dispatches issued immediately after `worker_done` both failed `runtime_unavailable` and consumed their tasks; dispatches issued after a `tui-idle` wait succeeded first try
