---
id: infrastructure-agent-orchestration-inherited-lock-ownership-in-a-spawned-session
domain: infrastructure
category: agent-orchestration
applies_to: [general, shell, claude-code]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man2/flock.2.html
  - https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/locks/ReentrantLock.html
  - https://www.gnu.org/software/make/manual/html_node/Job-Slots.html
last_verified: 2026-09-18
related: [backend-common-concurrency-distributed-locks, backend-common-jobs-scheduled-job-overlap, infrastructure-agent-orchestration-shared-run-state, testing-data-test-data-and-isolation]
---

# Lock Ownership Inherited by a Spawned Session

## When this applies

A session, script, or agent is about to acquire a single-flight lock whose
owner is identified by a run id, and the session was started by a hook, a cron
wrapper, or a parent process that may already hold that lock on the session's
behalf. Also when an acquire reports the lock as held within seconds of the
session starting, or an instruction says "generate a fresh run id, then acquire".

## Do this

1. **Read the environment for an inherited owner id before generating one.**
   A parent that holds the lock hands its identity down through the environment
   (`DEV_LOOP_FLUSH_RUN_ID`, `MAKEFLAGS --jobserver-auth=`, a `*_RUN_ID` /
   `*_OWNER` variable). Run `env | grep -iE 'RUN_ID|OWNER|LOCK'` first and, when
   a value is present, acquire under it: a re-entrant lock returns at once for
   the owner it already knows (`ReentrantLock`: "returns immediately if the
   current thread already owns the lock"), and a fresh id makes the same lock
   see its own parent as a stranger.

2. **Carry that one id through every later lock call in the run.** Each step of
   a skill or pipeline runs in its own shell, so nothing carries between steps by
   itself. Record the id the moment you resolve it and prefix every `acquire`,
   `refresh`, and `release` with it; a release under a different id is refused
   as a foreign caller and the lock leaks until its TTL.

3. **Compare the reported holder to your own identity before calling the lock
   busy.** "Held by X, N seconds old" is only a foreign holder when X differs
   from the id your environment carries:

| Acquire result | Holder id | Do |
|----------------|-----------|----|
| `held <id> <age>s`, `<age>` within seconds of your own start | Equals the inherited env id | Re-run the acquire under the inherited id; expect `already-owned` |
| `held <id> <age>s` | Differs from every id in your env | A separate run is live — stop as the instruction says; report holder and age |
| `held`, no inherited id in the env | — | Foreign holder; stop and report |
| `acquired` / `already-owned` | — | Proceed; note which one you got — `already-owned` means a parent will also release, so your own release must use the same id |

4. **When you are the parent that spawns the worker, export the owner id into
   the child's environment and release once.** Acquire, `export <VAR>=<id>`,
   spawn, and release in the same process (or a subshell that inherited the
   export) after the child exits. The child's step-0 acquire then lands on the
   re-entrant branch, and only one identity ever releases.

## Edge cases

| Case | Then |
|------|------|
| The lock is `flock`/`fcntl` on a file rather than an id in an owner file | Inheritance follows the open file description, not the process: an fd inherited by `fork`/`dup` shares the parent's lock, but a fresh `open()` of the same path is an independent descriptor and "may be denied by a lock that the calling process has already placed" (flock(2)) — reuse the inherited fd (pass it down, e.g. `flock -n 9` with `9<>lock` opened once in the parent) instead of re-opening the path |
| GNU make sub-make | The parent passes the jobserver through `MAKEFLAGS` (`--jobserver-auth=`, "only the last instance is relevant"); a recipe that invokes `$(MAKE)` without `+`/`$(MAKE)` in the command loses it and the child runs with its own `-j1` — same mechanism: inherit the token from the environment, do not mint a new pool |
| Your acquire wrapper defaults the id to `<timestamp>-$$` when the env var is empty | That default is what shadows the inherited id; treat an empty env var as "I am the root of this run" only after `env` confirms nothing was exported |
| The parent already released (child outlived its wrapper) | The re-entrant acquire fails with "held" only if a *new* holder appeared; an absent lock is simply re-acquired under the inherited id, and your release still matches |
| Test suite for the lock wrapper | Add a case that exports the owner id, acquires in a subshell, and asserts `already-owned` — and one that exports a *different* id and asserts `held` (see [testing-data-test-data-and-isolation] for keeping exported ids out of unrelated tests) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Generate `RUNID="$(date +%s)-$$"` because the instruction says "generate a fresh id" | `RUNID="${INHERITED_VAR:-$(date +%s)-$$}"` after checking `env` | The instruction assumes you are the root of the run; a spawned session is not, and the fresh id turns a re-entrant lock into a self-deadlock |
| Conclude "another flush/run is active" from `held … 11s` and stop | Compare the holder id with your env first | A holder younger than your own session that matches your env is your parent, not a competitor |
| Wait or poll for the held lock to clear | Resolve identity (above); when it is truly foreign, stop and report | The holder that matches your env is waiting on *you* — polling it deadlocks both sides until the TTL |

## Sources

- https://man7.org/linux/man-pages/man2/flock.2.html — locks are bound to the open file description; `fork`/`dup` descriptors share the lock, while a second `open()` of the same file is independent and "may be denied by a lock that the calling process has already placed via another file descriptor"
- https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/locks/ReentrantLock.html — "owned by the thread last successfully locking, but not yet unlocking it"; `lock()` "will return immediately if the current thread already owns the lock"
- https://www.gnu.org/software/make/manual/html_node/Job-Slots.html — the parent make passes jobserver access to children "through the environment … in the `MAKEFLAGS` environment variable" via `--jobserver-auth=`; "only the last instance is relevant"
- Reproduction 2026-09-17 (dev-loop `scripts/flush-lock.sh`, headless session spawned by `hooks/auto-flush.sh`): `acquire` under a freshly generated id → `held 20260917-224552-43083 11s`, exit 3; the same command under the inherited `DEV_LOOP_FLUSH_RUN_ID` → `already-owned 20260917-224552-43083`, exit 0. `auto-flush.sh` exports the id before spawning the session and releases after it exits; the wrapper's re-entrant branch compares the owner-file id to `$DEV_LOOP_FLUSH_RUN_ID`
