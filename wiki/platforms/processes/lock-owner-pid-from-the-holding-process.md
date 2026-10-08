---
id: platforms-processes-lock-owner-pid-from-the-holding-process
domain: platforms
category: processes
applies_to: [shell, macos, linux]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html
  - https://man7.org/linux/man-pages/man2/kill.2.html
  - https://man7.org/linux/man-pages/man2/flock.2.html
  - "Local reproduction 2026-10-08 (macOS, Darwin 25.1, /bin/sh): an acquire helper that wrote its own $$ left a PID that kill -0 reported dead right after acquire while the caller still ran"
  - "Field case 2026-10-08 (dev-loop scripts/flush-lock.sh, a TTL-plus-liveness flush lock)"
last_verified: 2026-10-08
related: [infrastructure-agent-orchestration-inherited-lock-ownership-in-a-spawned-session, backend-common-concurrency-distributed-locks, backend-common-jobs-scheduled-job-overlap, platforms-processes-background-services]
---

# Owner PID in a Shell Lock Written by a Helper Script

## When this applies

A shell lock (a `mkdir` lock directory, a pidfile, an owner file) records a PID
so a later caller can reclaim the lock once the holder is dead, and the lock is
taken by a helper script (`sh lock.sh acquire`) that the real worker calls.
Also when such a lock is reclaimed by a sibling while its holder is still
working, or its "holder is dead" branch never fires.

## Do this

1. **Record the PID of the process that lives for the whole guarded operation,
   and pass it into the helper explicitly.** Inside the helper, `$$` is the
   helper's own shell — POSIX: "the decimal process ID of the invoked shell" —
   and that shell exits right after writing the owner file. `kill -0` on it is
   then false from the first second, so a "past TTL and holder dead → reclaim"
   rule shrinks to TTL-only.

| How the worker uses the helper | PID to record |
|--------------------------------|---------------|
| A long-running script runs the helper as a child | The script's `$$`, passed as an argument (`lock.sh acquire --owner-pid "$$"`) |
| The helper is sourced (`. lock.sh`) into the long-lived shell | `$$` in the helper is already correct |
| Every step runs in a fresh shell (agent tool calls, CI steps, Makefile recipe lines) | No shell outlives the operation: pass the PID of the outermost process that does (the wrapper that spawned the run, exported through the environment), or drop the liveness check and rely on TTL plus refresh (step 3) |

2. **Test the liveness branch, not only the TTL branch.** Right after acquire,
   assert `kill -0 <recorded pid>` succeeds while the holder runs; after the
   holder exits, assert a past-TTL acquire reclaims. A suite that only checks
   "TTL expired → reclaimed" passes with a dead PID recorded.

3. **When the operation can outlive the TTL, refresh the owner record from the
   long-lived process** (a background keep-alive loop, or a refresh between
   steps) and check on each refresh that the record still names you — the same
   watchdog rule as [backend-common-concurrency-distributed-locks].

4. **Record the PID together with its start time** (`ps -o lstart= -p <pid>`)
   and compare both before treating the holder as alive. A recycled PID makes a
   dead holder look alive, and under "past TTL and dead" the lock then is never
   reclaimed.

## Edge cases

| Case | Then |
|------|------|
| `kill -0` fails with EPERM | kill(2) with signal 0 still runs "existence and permission checks": the process exists but belongs to another user. Treat it as alive, or test existence with `ps -p <pid>` |
| The lock directory is on a shared filesystem used by several hosts | A PID from another host means nothing locally — record the hostname, and treat a foreign-host holder as alive until the TTL |
| `flock` is available (util-linux on Linux) | Prefer it: the kernel drops the lock when all descriptors of the open file description close (flock(2)), so no PID bookkeeping is needed. See [infrastructure-agent-orchestration-inherited-lock-ownership-in-a-spawned-session] for passing the descriptor to children |
| The lock id is inherited from a parent run | The PID must be the parent's long-lived process too — the child session's helper shells are just as short-lived |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `printf '%s %s' "$RUNID" "$$" > owner` inside an acquire helper | Write the PID the caller passes in | The helper exits after writing; the lock silently degrades to TTL-only, and a run longer than the TTL is reclaimed while still working |
| Lengthen the TTL after a sibling reclaimed a live run | Record the right PID, and refresh from the long-lived process | A longer TTL only delays the same reclaim and slows recovery after a real crash |

## Sources

- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html — 2.5.2 Special Parameters: `$` "Expands to the shortest representation of the decimal process ID of the invoked shell"; in a subshell it keeps the current shell's value
- https://man7.org/linux/man-pages/man2/kill.2.html — "If sig is 0, then no signal is sent, but existence and permission checks are still performed"
- https://man7.org/linux/man-pages/man2/flock.2.html — the lock belongs to the open file description and is released when all its descriptors are closed
- Local reproduction 2026-10-08 (macOS, Darwin 25.1, `/bin/sh`): a helper doing `mkdir "$LOCK"` then writing `$$` to `$LOCK/owner` — `kill -0` on the recorded PID failed right after acquire while the calling shell was still running; the same helper given the caller's `$$` as an argument recorded a PID that `kill -0` found alive
- Field case 2026-10-08 (dev-loop `scripts/flush-lock.sh`, reclaim rule "age past TTL and recorded PID not alive"): `_write_owner` wrote the helper's `$$`; `kill -0` on the recorded PID found no process 225 s after acquire while the flush was still running, and two consecutive flush runs needed a 5-minute keep-alive loop to avoid reclaim
