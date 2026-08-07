---
id: testing-strategy-signal-delivery-to-a-process-under-test
domain: testing
category: strategy
applies_to: [general]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
  - https://www.gnu.org/software/bash/manual/bash.html#Signals
  - https://docs.python.org/3/library/subprocess.html#subprocess.Popen.send_signal
last_verified: 2026-08-07
related: [platforms-processes-non-interactive-cli-invocation]
---

# Signal Delivery to a Process Under Test

## When this applies

A test must exercise a program's SIGINT path (Ctrl-C shutdown, cleanup on
interrupt, "exits 0 on SIGINT" contract) and the harness starts the program
with `cmd &` from a shell script, then sends `kill -INT "$pid"`; the signal is
silently discarded, `wait` hangs until the harness timeout, and the failure
reads like a product bug.

## Do this

Spawn the process from a driver that controls signal dispositions instead of a
shell background job. In Python: `proc = subprocess.Popen([...])`, then
`proc.send_signal(signal.SIGINT)` and `proc.wait(timeout=...)`. `Popen`
children inherit the test process's dispositions, so SIGINT arrives with its
default action intact.

The mechanism: POSIX (§2.11 Signals and Error Handling) requires that when job
control is disabled — the state of every script, CI step, and hook shell — the
commands of an asynchronous list "shall inherit from the shell a signal action
of ignored (SIG_IGN) for the SIGINT and SIGQUIT signals". The kill succeeds,
the child discards the signal. Bash documents the same rule (§3.7.6 Signals).

| Case | Do |
|------|----|
| The harness language can spawn processes directly (Python, Node, Go) | Use its process API and send the signal to the child PID it returns |
| The harness must stay a shell script | `set -m` before the `&` — with job control enabled the background job gets default SIGINT/SIGQUIT (verified sh/bash) |
| The contract under test is generic graceful shutdown, not Ctrl-C specifically | Send SIGTERM — only SIGINT and SIGQUIT are special-cased; SIGTERM stays SIG_DFL in background jobs, so plain `kill "$pid"` from a script works |
| You need to prove which case you are in | Run `python3 -c "import signal; print(signal.getsignal(signal.SIGINT))"` as the background job: `1` (SIG_IGN) confirms the shell nulled the path |

## Edge cases

| Case | Then |
|------|------|
| The program installs its own SIGINT handler unconditionally at startup | The shell-`&` harness can still work — but you are now testing the handler, not delivery; keep the driver approach so the test also covers default-disposition consumers |
| The program is Python | CPython checks the inherited disposition at startup and does NOT install its KeyboardInterrupt handler over an inherited SIG_IGN — a Python child in a `&` job ignores Ctrl-C-class signals entirely |
| The same test passes when run by hand in a terminal but hangs in CI | Interactive shells run with job control on, scripts run with it off — that divergence is this page's trigger, not flakiness |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Raise the timeout or mark the SIGINT test flaky | Check the child's inherited disposition first (table above) | The wait never returns at any timeout — the signal was discarded, not delayed |
| Debug the program's shutdown code because the test hangs | Reproduce with `send_signal` from a driver before touching the product | The same binary that "hangs" under `kill -INT` on a `&` job exits cleanly when the signal actually arrives |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — §2.11: with job control disabled, asynchronous-list commands "shall inherit from the shell a signal action of ignored (SIG_IGN) for the SIGINT and SIGQUIT signals"
- https://www.gnu.org/software/bash/manual/bash.html#Signals — §3.7.6: "When job control is not in effect, asynchronous commands ignore SIGINT and SIGQUIT in addition to these inherited handlers"
- https://docs.python.org/3/library/subprocess.html#subprocess.Popen.send_signal — the driver-side delivery API
- Local reproduction 2026-08-07 (macOS, sh/bash/zsh): `sh -c '<print-disposition> & wait'` reports SIG_IGN for SIGINT in the background child and the default handler in the foreground; with `set -m` the background child reports the default handler; SIGTERM reports SIG_DFL in both. Field case same day: a server binary timed out (rc 143) under `kill -INT $pid; wait` from a script, and exited 0 immediately under `subprocess.Popen` + `send_signal(SIGINT)`
