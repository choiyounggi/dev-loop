---
id: platforms-processes-non-interactive-cli-invocation
domain: platforms
category: processes
applies_to: [macos, linux]
confidence: verified
sources:
  - https://www.gnu.org/software/coreutils/manual/html_node/nohup-invocation.html
  - https://man.openbsd.org/ssh
  - https://man.openbsd.org/ssh_config
  - https://git-scm.com/docs/git
  - https://man7.org/linux/man-pages/man1/timeout.1.html
last_verified: 2026-07-31
related: [platforms-processes-background-services, platforms-tools-bsd-vs-gnu-cli, platforms-shells-portable-shell-scripts, debugging-methodology-hypothesis-testing, infrastructure-agent-orchestration-pane-delivery-confirmation]
---

# Invoking a Prompt-Capable CLI from a Script or Agent Harness

## When this applies

Calling a CLI that is able to prompt (agent CLIs, `ssh`, `git`, package managers)
from a script, CI step, hook, or agent harness — including when you passed its own
non-interactive flag (`-p`, `--print`, `--yes`). Also when such a call hangs with no
output and no error and you must decide whether the client, the network, or the
remote service is at fault.

## Do this

1. **Detach fd 0 at the call site**: `cmd </dev/null` — the redirect is the
   unconditional guarantee, plus the tool's own stdin-detach flag where it has one
   (`ssh -n` "prevents reading from stdin … must be used when ssh is run in the
   background"). GNU `nohup` adds this **only when fd 0 is already a terminal**, so
   in a CI step or hook where fd 0 is a pipe, write the redirect explicitly. A
   non-interactive flag controls the tool's output and prompt *policy*; it does not
   guarantee the tool never reads standard input.
2. **Close the tool's prompt channel separately** — detaching stdin makes a prompt
   fail rather than answer it: `ssh -o BatchMode=yes` ("user interaction such as
   password prompts and host key confirmation requests will be disabled", plus
   `-o StrictHostKeyChecking=accept-new` for a first-contact host key),
   `GIT_TERMINAL_PROMPT=0` for git's credential prompts, `DEBIAN_FRONTEND=noninteractive`
   for apt.
3. **Bound every such call with a timeout** (`timeout` / `gtimeout` —
   [platforms-tools-bsd-vs-gnu-cli] owns the macOS gap) so a blocked read fails the
   step (exit 124) instead of hanging the pipeline.
4. **Write output to a file**, so "0 bytes produced" is recorded evidence rather
   than a memory of a blank terminal.
5. **Split client from server before blaming the remote side**, using the server's
   own access/gateway log for your source IP and time window:

| Observation | Conclusion |
|-------------|------------|
| No request logged on the server for that window | The request never reached the server's logged surface: either a local block (fd 0, auth prompt, lock) or a pre-log rejection (DNS, TLS, an intermediate proxy). Separate the two by retrying the same endpoint with a minimal client (`curl -v`) from the same host |
| Request logged, response slow or 5xx | Server side — take it to the service's latency/error path |
| Request logged and answered fast, client still produced nothing | The client blocked *after* the response — inspect the client's own output handling |

## Edge cases

| Case | Then |
|------|------|
| The tool genuinely needs input on stdin (a piped prompt) | Feed it from a file or heredoc (`cmd <prompt.txt`) so fd 0 is a file and never the terminal |
| Target is not GNU coreutils (macOS/BSD `nohup`) | Redirect explicitly: `nohup cmd 0>/dev/null >"$LOG" 2>&1 &` — the stdin redirect is a GNU extension |
| Tool detects a TTY and changes output (color codes, progress bars, a pager) | Closing stdin is not enough — also disable the pager/color (`GIT_PAGER=cat`, `--no-color`) so parsers see stable text |
| Wrapper CLI shells out to a second binary that prompts | Redirecting the wrapper's stdin covers the child only if the child inherits it — confirm with a timeout run before trusting the wrapper's own flags |
| Still hangs with stdin closed and nothing in the server log | Look for a non-stdin block: a lockfile, a keychain/credential prompt that only resolves in a GUI session, or a missing binary ([platforms-environment-path-resolution]) |
| The process must outlive the session | [platforms-processes-background-services] owns detach/supervision choice |
| Output arrives only after the process exits | The tool buffers when fd 1 is not a TTY — read the log after exit, or use the tool's line-buffered/streaming flag |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Raise the client timeout because the call "is just slow" | Re-run with `</dev/null` under `timeout`, then check the server log for arrival | A blocked read on fd 0 never emits a request; more waiting cannot produce one |
| Conclude the model/gateway/network is broken from a client-side hang | Confirm the request appears in the server's log first, then re-test the same endpoint with `curl -v` | Absence in the log narrows the fault to your side of the logged surface (invocation, DNS, TLS, proxy) and saves restarting healthy remote services |
| Rely on `--print` / `-p` / `--yes` alone to make a call non-interactive | Pass the flag AND redirect stdin from `/dev/null` | The flag is the tool's intent; the redirect is the guarantee |

## Sources

- https://www.gnu.org/software/coreutils/manual/html_node/nohup-invocation.html — "If standard input is a terminal, redirect it … Make the substitute file descriptor unreadable, so that commands that mistakenly attempt to read from standard input can report an error"; GNU extension, portable form `0>/dev/null`. The terminal precondition is why the explicit redirect is the guarantee
- https://man.openbsd.org/ssh — `-n` "Redirects stdin from /dev/null (actually, prevents reading from stdin). This must be used when ssh is run in the background"; the same entry notes it "does not work if ssh needs to ask for a password or passphrase" — a stdin detach, not a prompt suppressor
- https://man.openbsd.org/ssh_config — `BatchMode=yes`: "user interaction such as password prompts and host key confirmation requests will be disabled"; `StrictHostKeyChecking=accept-new` adds new host keys without permitting changed ones
- https://git-scm.com/docs/git — `GIT_TERMINAL_PROMPT`: "If this Boolean environment variable is set to false, git will not prompt on the terminal (e.g., when asking for HTTP authentication)"
- https://man7.org/linux/man-pages/man1/timeout.1.html — "Start COMMAND, and kill it if still running after DURATION"; exit status 124 "if COMMAND times out"
- Field context: a 2026-07 session ran an agent CLI with its non-interactive `--tools` flag in the foreground; two runs hung (300 s, 150 s) with zero output. The gateway access log showed **no request from that host** in either window (ruling out the model and gateway); the same command with stdin taken from `/dev/null` completed immediately
