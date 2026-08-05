---
id: infrastructure-orchestration-control-signals-vs-primary-artifacts
domain: infrastructure
category: orchestration
applies_to: [general, tmux, git-worktree]
confidence: verified
sources:
  - https://man.openbsd.org/tmux
  - https://code.claude.com/docs/en/hooks
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
last_verified: 2026-08-05
related: [infrastructure-orchestration-shared-run-state, platforms-shells-command-text-inspected-before-execution, platforms-tools-harness-mediated-tool-results, debugging-methodology-hypothesis-testing]
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

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Restart a worker because the watch script exited "dead" | Run the substrate liveness call and `git log` on its branch first | The verdict can come from an identifier the worker picked up from its environment, naming a different process entirely |
| Let a worker resolve its own session/pane id for the status file | Pass the orchestrator-assigned task id into the worker and have it echo that back | Discovered identifiers are ambient state; assigned ids are the orchestrator's own namespace |
| Trust a status script's silence as "signal sent" | `stat` the status file after the call and report the mtime | A gate-blocked command exits without writing and without printing |
| Retry a blocked status write with a rewritten path | Report the block and the rule id to the orchestrator | The rule is protecting the shared checkout; a workaround reintroduces exactly the corruption it prevents |

## Sources

- https://man.openbsd.org/tmux — target-session resolution: "if a session is omitted, the current session is used if available; if no current session is available, the most recently used is chosen" — so a session-name query from outside any session still returns a name. Reproduced 2026-08-05: `env -u TMUX tmux display-message -p '#S'` printed an unrelated session name with exit 0
- https://code.claude.com/docs/en/hooks — a `PreToolUse` hook runs "Before a tool call executes. Can block it"; a blocked call never executes, so it leaves no side effect
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — command text is expanded by the shell when it processes the line, so a gate reading the unexecuted string matches on literal paths irrespective of the command's purpose

## Field context

Two verdicts from the same orchestration run, 2026-08-04/05. (1) A watch script
returned exit 3 ("dead worker") three times; each time the substrate's own
liveness check returned alive and `git log` showed real commits on the task
branch. Cause: the worker's status script resolved its session via
`tmux display-message -p '#S'`, which returned unrelated session names
(`lo-14/15/16-npmcli`), so the monitor was polling the wrong session's existence.
(2) A worker running the orchestrator's `status-update.sh` with the status
directory pointing at the main checkout was refused by a `worktree_escape`
guardrail (`plugins/guardrails/hooks/bash-guard.sh`), which fires when a linked
worktree's command text names the main root together with a write verb —
independent of the command's purpose. The status directory was then empty
(`total 0`) while the orchestrator kept polling. A Write-tool write to the same
path succeeded, confirming the block is Bash-command-text-scoped, not a
filesystem permission.
