---
id: infrastructure-containers-entrypoint-log-capture
domain: infrastructure
category: containers
applies_to: [docker, kubernetes, bash]
confidence: verified
sources:
  - https://mywiki.wooledge.org/ProcessSubstitution
  - https://tiswww.case.edu/php/chet/bash/bashref.html
last_verified: 2026-07-15
related: [infrastructure-containers-image-builds, infrastructure-observability-logs-metrics-signals, platforms-shells-portable-shell-scripts]
---

# Log Loss from Process-Substituted tee in Container Entrypoint Scripts

## When this applies

A container's entrypoint bash script (running as PID 1) duplicates its output to
a file with `exec > >(tee -a "$LOG") 2>&1`, and log lines are missing: short jobs
capture nothing, long jobs lose the tail (the completion-summary lines).

## Do this

1. Capture the tee PID and wait for it in an EXIT trap. Bash runs process
   substitutions asynchronously and does not wait for them; `wait "$!"` on a
   process substitution is supported since bash 4.4. Outside a container the
   orphaned tee usually finishes anyway — as PID 1, the container is torn down
   the instant the script exits, killing tee before it flushes:

   ```bash
   exec > >(tee -a "$LOG") 2>&1
   TEE_PID=$!
   flush_logs() {
     exec 1>&- 2>&-   # close our ends so tee sees EOF
     wait "$TEE_PID"
   }
   trap flush_logs EXIT
   ```

2. For a script whose main work is a long foreground job, run that job as a
   background child and `wait` it before adding any TERM trap. Bash defers
   user traps until the foreground command completes — a TERM trap behind a
   foreground child never fires on `docker stop`, the grace period expires,
   and SIGKILL ends the container at exit 137 with nothing flushed. `wait`
   is interruptible by traps, so this shape reacts immediately:

   ```bash
   trap 'kill -TERM "$MAIN_PID" 2>/dev/null; wait "$MAIN_PID"; exit 143' TERM
   main_job & MAIN_PID=$!
   wait "$MAIN_PID"
   ```

   `exit 143` (128+15) reports the conventional SIGTERM status. For simple
   sequential scripts, no TERM trap is needed for the flush itself — bash runs
   the EXIT trap on an untrapped SIGTERM in non-interactive shells.

3. Verify by re-running the container several times and checking the log file
   for the final line each run — this failure is timing-dependent, so a single
   successful run proves nothing.

## Edge cases

| Case | Then |
|------|------|
| Base image bash is older than 4.4 (`wait "$!"` on a process substitution fails) | Use a named pipe: `mkfifo`, start `tee < pipe &` as a normal background job, `exec > pipe`, and `wait` its real PID |
| Script also traps other signals (INT, HUP) | End each handler with `exit 128+n`, so every trapped path reports its conventional signal code and reaches the EXIT trap |
| Logs must survive even a SIGKILL (OOMKill, forced deletion) | No trap runs on KILL — write to a mounted volume via unbuffered append (or ship lines as they are produced) instead of relying on exit-time flushing |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust `exec > >(tee -a f)` because it works in a terminal | Add the EXIT-trap wait before it runs as PID 1 | The shell never waits for process substitutions; a terminal leaves the orphan running to finish, a container kills it at PID 1 exit |
| Debug the missing lines as a tee buffering option problem | Reproduce with repeated short runs and add the trap | The writer is killed before flushing — buffering flags don't fix a killed process |
| Exit 0 from the TERM trap for a "clean" shutdown | `exit 143` (128+15) | Orchestrators and CI distinguish signalled termination from success by the 128+n convention |
| Add `trap 'exit 143' TERM` while the main job runs in the foreground | Background the job, `wait` it, and forward TERM from the trap (step 2) | Bash defers traps until the foreground command finishes — the trap never fires, the grace period ends in SIGKILL (exit 137), and nothing flushes |

## Sources

- https://mywiki.wooledge.org/ProcessSubstitution — process substitution "will continue to run when your script exits (unless you manage your child processes)"; since bash 4.4 it can be managed with `wait "$!"`
- https://tiswww.case.edu/php/chet/bash/bashref.html — exit status is 128+n for a command terminated by signal n; trap execution is deferred until the running foreground command completes
- Field reproduction (OrbStack container, 2026-07-15): without the trap the log captured the script output in 0 of 10 runs; with the EXIT-trap wait, 10 of 10
- Independent adversarial re-reproduction (docker bash 4.4 and 5.2 as PID 1, 2026-07-15): tail captured 1/10 without the trap vs 10/10 with it; untrapped `docker stop` ran the EXIT trap (exit 143); `trap 'exit 143' TERM` behind a foreground child was deferred until SIGKILL (exit 137, no flush)
