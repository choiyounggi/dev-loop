---
id: testing-strategy-real-cli-spot-check-for-new-execution-paths
domain: testing
category: strategy
applies_to: [general]
confidence: field-tested
sources:
  - "Field evidence, a Rust multi-worker orchestration repo (commits e761ed3, b25ff04, 656d763 and HANDOFF.md §5 item 19), verified by direct git show / read against the checkout 2026-09-08"
last_verified: 2026-09-08
related: [testing-strategy-test-level-choice, testing-mocking-what-to-mock, infrastructure-agent-orchestration-worktree-isolated-workers, qa-process-completion-claims]
---

# A New Real-CLI Execution Path Whose Deterministic Suite Is Green but Never Run for Real

## When this applies

You add a new execution path that drives a real CLI process or real external
environment (a `RealCli` worker mode, a real-subprocess adapter) alongside an
existing deterministic/scripted/fake path, and the deterministic test suite
for it is fully green.

## Do this

1. **Treat a green deterministic suite as evidence about the scripted double
   only.** Write and run one real-CLI spot check — an ignored/manually invoked
   integration test, or a manual run — that actually exercises the real process
   for every new such path, run by the coordinator or a human, before relying
   on the path in an unattended run.
2. **Target the spot check at what a scripted/faked double cannot model**:
   process spawn preconditions (working directory existence, binary
   resolution) and shared-resource lifetime (semaphore/pool permit scope held
   across the path's whole lifetime vs. released per use).
3. **When the spot check finds a defect, add a deterministic regression test
   for the specific mechanism** (e.g. a unit test for the cwd-creation
   helper) so the fix has ongoing coverage — and keep the manual spot check as
   the gate for the *next* new real-path addition. The deterministic
   regression proves this one fix, not that the class of defect is closed for
   future paths.

| Failure class | Why a deterministic/scripted suite cannot see it |
|----------------|----------------------------------------------------|
| Spawn precondition (missing cwd → ENOENT) | The scripted double never calls the real spawn syscall, so a directory that was never created never fails |
| Shared-resource lifetime (a semaphore permit held for a whole runner's life instead of one turn, under a hard concurrency limit) | The fake/scripted path either doesn't route through the real pool, or completes fast enough that the limit is never actually contended |

## Edge cases

| Case | Then |
|------|------|
| The real spot check is expensive (real API cost, long runtime) | Run it once per new execution path, not per commit; gate it behind an ignore/manual-only marker so CI stays deterministic while the coordinator retains the one-time obligation |
| The spot check passes on the first try | Keep it as ignored integration coverage for the specific path, and still require the same one-time manual run for the *next* new real path — passing today does not retire the obligation for future additions |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ship a new real-CLI/real-environment execution path on a fully green deterministic/scripted suite | Have the coordinator manually run one real-CLI spot check against it first | An ENOENT spawn failure from a never-created cwd, and a semaphore-permit-scope deadlock, were both undetectable in principle by the deterministic suite in the field case and were found only by running the real path |

## Sources

- Field evidence (a Rust multi-worker orchestration repo, commit `e761ed3` "create RealCli worker cli-cwd before spawn (ENOENT hang)", verified by `git show` 2026-09-08): the `RealCli` arm pointed the worker config's cwd at a directory never created, so `Command::current_dir` failed every worker's CLI spawn with ENOENT; every worker reported blocked and the run hung forever under a zero escalation timeout. Commit message: "Found by the coordinator's real-CLI spot check"
- Same repo, commits `b25ff04` and `656d763` ("scope HarnessPool permit to a single turn" / "scope RealCli worker pool permit to a turn, not the runner"): a pool permit was held for a worker's whole runner lifetime; with the default limit-2 pool, only 2 of 5 workers could ever start, stalling the run. Commit message: "a latent M5 deadlock the coordinator's real-CLI spot check found twice"
- Same repo, HANDOFF.md §5 item 19 (verified by direct read): both defects passed the deterministic (`Scripted`) suite and surfaced only in a real-CLI two-sprint run; the recorded rule is "when a new `RealCli` path is created, the coordinator manually runs one real-CLI spot check"
