---
id: infrastructure-containers-pid1-entrypoint-log-flush
domain: infrastructure
category: containers
applies_to: [containers, docker, kubernetes, bash]
confidence: verified
sources:
  - https://mywiki.wooledge.org/ProcessSubstitution
  - https://docs.docker.com/reference/cli/docker/container/stop/
  - https://www.man7.org/linux/man-pages/man7/pipe.7.html
  - https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html
  - https://petermalmgren.com/signal-handling-docker/
last_verified: 2026-07-15
related: [infrastructure-containers-resource-limits-and-probes, platforms-shells-portable-shell-scripts, infrastructure-observability-logs-metrics-signals]
---

# Container PID 1 Entrypoint: Flushing Piped Logs on Exit

## When this applies

A bash script runs as PID 1 (the container entrypoint) and duplicates its stdout
to a file with process substitution — `exec > >(tee -a "$LOG")`. Log lines are
lost when the container exits: short jobs lose everything, long jobs lose the tail
(the final summary lines).

## Do this

Process substitution `>(tee …)` runs in an **unwaited background subshell** — bash
does not reap it on exit. A container terminates the instant PID 1 exits, so the
`tee` is killed before it flushes its buffer. Make the entrypoint wait for the tee
to drain before it exits.

1. Capture the tee's PID on the line immediately after starting it (bash **4.4+**,
   where `$!` is set to the process-substitution PID):
   ```bash
   exec > >(tee -a "$LOG") 2>&1
   TEE_PID=$!
   ```
   Capture it right away — any other backgrounded job overwrites `$!`.
2. In an EXIT trap, close the write ends first so `tee` sees EOF, then wait for it:
   ```bash
   trap 'exec 1>&- 2>&-; wait "$TEE_PID"' EXIT
   ```
   Order matters — closing fds 1/2 delivers the pipe EOF that makes `tee` finish its
   last read and flush; the `wait` then blocks until it has exited.
3. Make container stop run the EXIT trap. On `docker stop`/pod termination, PID 1
   receives SIGTERM then (after the grace period) SIGKILL, and PID 1 **ignores**
   SIGTERM unless a handler is registered. Add `trap 'exit 143' TERM` (128+15) so a
   stop signal exits cleanly and fires the EXIT trap's flush.

## Edge cases

| Case | Then |
|------|------|
| bash < 4.4 | `$!` does not expose the process-substitution PID — start the writer explicitly through a named FIFO (`mkfifo`; `tee -a "$LOG" < "$FIFO" & TEE_PID=$!`) and redirect to the FIFO |
| Another child still holds a copy of fd 1/2 | Closing the fds only in the shell does not deliver EOF — `tee` blocks until every write end is closed; ensure children exit or close their fds first |
| Only the tail is missing (long jobs) vs everything (short jobs) | Same root cause — exit-before-flush; the fix (wait in EXIT trap) covers both |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `exec > >(tee …)` with no trap | Capture `TEE_PID=$!` and `wait` it in an EXIT trap after closing the fds | Bash never reaps the process-substitution subshell; PID 1 exit kills it mid-flush |
| Assume logs were captured because the completion line printed to the console | Wait for the tee in the EXIT trap | Console output and the tee's file buffer are independent; PID 1 exit discards the unflushed buffer |
| Rely on `docker stop` alone to end the script | Add `trap 'exit 143' TERM` | PID 1 ignores SIGTERM without a handler, so the EXIT trap (and its flush) never runs before SIGKILL |

## Sources

- https://mywiki.wooledge.org/ProcessSubstitution — process substitution runs in an unwaited subshell; bash 4.4+ sets `$!` to its PID so you can `wait`
- https://docs.docker.com/reference/cli/docker/container/stop/ — stop sends SIGTERM, then SIGKILL after the grace period
- https://www.man7.org/linux/man-pages/man7/pipe.7.html — a read sees EOF only once all write-end fds are closed
- https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html — a command killed by signal N exits 128+N (SIGTERM 15 → 143)
- https://petermalmgren.com/signal-handling-docker/ — PID 1 ignores SIGTERM unless a handler is registered; orphans reaped only if PID 1 waits
