---
id: testing-strategy-long-lived-processes-under-bats
domain: testing
category: strategy
applies_to: [bats, bash, posix]
confidence: verified
sources:
  - https://bats-core.readthedocs.io/en/stable/writing-tests.html
  - https://bats-core.readthedocs.io/en/v1.3.0/writing-tests.html
  - https://github.com/bats-core/bats-core/issues/530
  - https://www.gnu.org/software/bash/manual/bash.html#Command-Substitution
last_verified: 2026-10-29
related: [testing-strategy-calls-that-must-not-block, testing-strategy-signal-delivery-to-a-process-under-test, testing-mocking-destructive-operations-on-shared-daemons, testing-quality-tests-that-cannot-fail, platforms-processes-tmux-server-environment-at-start]
---

# Long-Lived Processes Started From a bats Test

## When this applies

A bats test, its `setup`, or a helper it calls starts a process that outlives
the command: a daemon, a `&` job, a server that a CLI forks for you (`tmux
new-session` starting a tmux server, an ssh ControlMaster, a dev server). Also
when a bats run prints every test result and then never exits, or hangs with no
failure output.

## Do this

1. **Close fd 3 on every command that may leave a process behind**:
   `tmux -S "$sock" new-session -d -s t 3>&-`, `my_daemon & 3>&-`. bats writes
   its own TAP output to file descriptor 3 and waits until every holder of fd 3
   has closed it. A child that inherited fd 3 holds it for its whole life, so
   bats looks frozen after the last test. The bats docs give this fix:
   `command_name 3>&-`.
2. **Still stop the process in `teardown`.** Closing fd 3 only lets bats exit;
   the process keeps running. `teardown` runs when an assertion fails too, so
   the stop belongs there, not at the end of the test body.
3. **Give the process a private address** (`tmux -L`/`-S` socket, a temp port,
   a temp pidfile) and have teardown act only on that address. Then teardown
   cannot reach a process the developer already runs
   ([testing-mocking-destructive-operations-on-shared-daemons]).
4. **Call helpers that record that address bare (`start_server`), not inside
   `$(...)`.** Command substitution runs in a subshell, so variables the helper
   sets never reach the test's shell, and teardown sees an empty name. The
   substitution also waits for its stdout pipe to close, so a daemon that
   inherited the pipe stalls the test.

| Where the process starts | Do |
|--------------------------|----|
| Test body or `setup` | `3>&-` on the start command, stop it in `teardown` |
| `setup_file` | `3>&-` is not enough. Issue #530 reports bats still waiting for such processes after the tests finish. Stop them in `teardown_file` |
| Inside the code under test (the script you test forks it) | Close fd 3 on the call into that code (`run my_script 3>&-`), or make the code close inherited descriptors before it daemonizes |

## Edge cases

| Case | Then |
|------|------|
| Teardown reads variables like `SOCK`/`PID` that a caller could also export | Set them to empty at the end of `setup`, and have teardown act only when they are non-empty. An inherited value can then never send teardown to another server, and tests that start nothing skip the stop |
| The required tool (tmux, docker) is missing on the machine | Decide whether the case fails or skips, and match the rest of the suite. A start helper that asserts the binary exists (`[ -n "$REAL_TMUX" ]`) turns a silent pass into a red test |
| The run already hangs and you need to find the holder | `lsof -p <bats pid>` lists its fds. Then check which surviving child process still has the same pipe open as fd 3 (`lsof -d 3`) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Raise the CI timeout because bats "hangs after the last test" | Find the child holding fd 3 and add `3>&-` to its start command | bats waits on fd 3, not on a timer, so no timeout ends the wait cleanly |
| Kill the server at the end of the test body | Kill it in `teardown` | A failed assertion before that line skips the kill |
| Capture a start helper's output with `$(start_server)` | Call it bare and let it set variables | The subshell drops the variables, and the inherited pipe blocks the substitution |

## Sources

- https://bats-core.readthedocs.io/en/stable/writing-tests.html — section "File descriptor 3 (read this if Bats hangs)": a background child inherits fd 3, which can make bats appear frozen
- https://bats-core.readthedocs.io/en/v1.3.0/writing-tests.html — same section: close fd 3 explicitly for commands that may launch long-running children, for example `command_name 3>&-`
- https://github.com/bats-core/bats-core/issues/530 — "bats waits for bg processes in `setup_file` even when FD3 is closed"
- https://www.gnu.org/software/bash/manual/bash.html#Command-Substitution — command substitution runs the command in a subshell
- Field case 2026-10-29 (a bats suite for a tmux launcher script that starts a private tmux server): a helper called as `$(...)` to return the socket path left teardown with no socket name, and the run hung on fd 3. Calling the helpers bare and adding `3>&-` to every command that may start the server fixed both. Sources above were read through web-search summaries in a headless run
