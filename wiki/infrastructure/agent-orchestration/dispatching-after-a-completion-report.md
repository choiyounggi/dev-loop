---
id: infrastructure-agent-orchestration-dispatching-after-a-completion-report
domain: infrastructure
category: agent-orchestration
applies_to: [orca, general]
confidence: field-tested
sources:
  - "Orca CLI bundled skill guide: `orca skills get --topic orchestration --full` (app 1.4.177, command schema v1)"
  - "`orca orchestration worker-start --help`, `orca terminal wait --help` (app 1.4.177)"
last_verified: 2026-08-12
related: [infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-session-completion-gates, infrastructure-agent-orchestration-shared-run-state, platforms-processes-non-interactive-cli-invocation]
---

# Reusing a Worker's Terminal for the Next Task After It Reports Completion

## When this applies

A worker reported completion (`worker_done`, a status write, an exit message) and
the orchestrator wants to hand that same terminal or runtime slot its next task.
Also when a start/dispatch call fails with a runtime-unavailable-class error
moments after a completion report, or when a task reaches a terminal `failed`
status without any worker having worked on it.

## Do this

1. **Treat the completion report as a claim about the work, not about the
   runtime.** The report settles the task and the dispatch; the terminal is
   released by a separate call. Between the two, the terminal is still owned by
   the finishing dispatch and rejects a new one.
2. **Gate the next start on an idle check of the target terminal**, then start:

   ```sh
   orca terminal wait --terminal "$HANDLE" --for tui-idle --timeout-ms 60000 --json
   orca orchestration worker-start --task "$NEXT_TASK" --terminal "$HANDLE" --json
   ```

   The guide states this directly: "Wait for `tui-idle` before dispatching."
3. **Decide each settled dispatch's next owner before waiting again**, so no
   terminal is left in the ambiguous middle state:

| After an accepted completion report | Do |
|-------------------------------------|----|
| The same agent has an immediate follow-up task | Read `worker.agent_terminal_handle` from `worker-show --dispatch <id> --json`, then `worker-start --task <next> --terminal <handle>` — this transfers cleanup ownership to the new dispatch |
| No follow-up for that agent | `worker-release --dispatch <id>` |
| The user asked to keep the terminal live for debugging | `worker-retain --dispatch <id>`, and release it later |

4. **Read the failed start's receipt instead of retrying it.** `worker-start`
   exits 0 only for `ready`; a failed or `outcome_unknown` start exits nonzero and
   returns `stage`/`failedStage`, `effects`, `residualResources`, and recovery
   commands. Fix the stage the receipt names, then start again.
5. **Retry the same task through a linked replacement dispatch**, naming
   placement explicitly, because retry does not inherit it:
   `worker-start --task <task> --retry-of <dispatch_id> --terminal <handle>`
   (or `--on`/`--worktree` plus `--agent`).
6. **Count the failures against the task.** After 3 consecutive failures on one
   task the dispatch context circuit-breaks and the task is marked `failed`. Blind
   retries spend that budget on the same unmet precondition; an idle check spends
   none of it.

## Edge cases

| Case | Then |
|------|------|
| The completion report arrives but the terminal never reaches idle | This is the settled-dispatch/live-terminal state, not a stall — hold the handle and let the release path own it; do not close the terminal to force it |
| The start receipt says `outcome_unknown` | `worker-stop --dispatch <id>` and inspect again, or `worker-abandon --dispatch <id>` while accepting that resources may still be live — abandon performs no remote, process, or filesystem action |
| The task already reached `failed` from the circuit breaker | Recovering it means an explicit `task-update`, or a new task carrying the same spec; a `--retry-of` dispatch does not un-fail a circuit-broken task |
| The target is a bare shell rather than an agent CLI | Omit `--inject`, dispatch for tracking, and send the prompt with `terminal send --text … --enter`; the idle gate still applies |
| `worker-release` returns `release_pending` or `release_unknown` | Follow the recovery action in the receipt; substituting `terminal close` closes a terminal whose ownership the orchestrator has not proven |
| The idle wait times out on a long-running agent | A timeout is a checkpoint, not a failure — coding tasks run 15–60 minutes; keep waiting rather than starting a competing dispatch |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Start the next task the moment the completion report lands | Run the terminal idle check first, then start | The report settles the task; the previous dispatch still owns the terminal, so the start fails on an occupied runtime |
| Re-run the identical `worker-start` after it failed | Read the receipt's `stage`/`effects`/`residualResources`, fix that, then start with `--retry-of <dispatch_id>` | Three consecutive failures on one task circuit-break it into `failed`, so a retry loop destroys the task it was meant to rescue |
| Let a `--retry-of` replacement pick its own placement | Repeat the intended `--on`/`--worktree` and `--agent`/`--terminal` choice on the retry | Retry links the attempt for provenance and deliberately does not inherit placement |
| Close the terminal yourself to free it for the next task | Transfer it with `worker-start --terminal <handle>` or hand it to `worker-release` | The release path preserves inspectable output first and closes only the exact terminal the settled dispatch owns |

## Sources

- Orca CLI bundled skill guide, `orca skills get --topic orchestration --full` (app 1.4.177, command schema v1) — "Wait for `tui-idle` before dispatching"; "After processing each accepted `worker_done`, choose the terminal's next owner before you acknowledge the Delivery or wait again… run `orca orchestration worker-start --task <next_task_id> --terminal <handle> --json` so Orca transfers cleanup ownership to the new Dispatch. Otherwise run `orca orchestration worker-release --dispatch <dispatch_id> --json`"; "After 3 consecutive failures on one task, the dispatch context circuit-breaks and the task is marked failed"; "It proves `failed` or `stopped`: start a replacement with `worker-start --task <task> --retry-of <id>` plus an explicit `--on`/`--worktree` and `--agent`/`--terminal` choice. Retry does not silently inherit placement"; "Treat a `check --wait` timeout or `{count:0}` as a checkpoint, not a worker failure"
- `orca orchestration worker-start --help` (app 1.4.177) — "The call exits 0 only for ready. Failed or outcome_unknown exits 1 and JSON includes stage/failedStage, setup, effects, residualResources, and recovery commands when needed"; `orca terminal wait --help` — `--for exit|tui-idle`; `orca orchestration task-update --help` — statuses `pending, ready, dispatched, completed, failed, blocked`
- Field observation 2026-08-06 (dev-loop orchestration run, two occurrences): follow-up dispatches issued to a worker's terminal immediately after its completion report both failed on an unavailable runtime and consumed a dispatch attempt; the same start succeeded on the first try once the terminal was confirmed idle first
