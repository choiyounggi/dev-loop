---
id: platforms-processes-non-interactive-cli-invocation
domain: platforms
category: processes
applies_to: [macos, linux]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man1/nohup.1.html
  - https://man.openbsd.org/ssh.1
  - https://man.openbsd.org/ssh_config.5
  - https://man7.org/linux/man-pages/man1/timeout.1.html
last_verified: 2026-07-30
related: [platforms-processes-background-services, platforms-shells-portable-shell-scripts, debugging-methodology-reproduce-first]
---

# Invoking an Interactive-Capable CLI From a Script, Hook, or Agent

## When this applies

You are calling a tool that can prompt (a coding-agent CLI, `ssh`, `git`, a package
manager, an installer) from a script, CI step, hook, or agent session; or such a
call produced no output and never returned, and you are deciding whether the tool,
the network, or the far-side service is at fault.

## Do this

1. **Close stdin and pass the tool's own non-interactive switch — both, not either.**
   A `-p`/`--print`/`--quiet` flag suppresses *rendering*; it does not promise the
   tool never reads stdin. When stdin is still a terminal, any prompt the flag
   didn't cover (a permission confirmation, a passphrase, a host-key question)
   blocks forever with zero bytes written. This is why `ssh -n` exists — it
   "Redirects stdin from /dev/null (actually, prevents reading from stdin)" and
   "must be used when ssh is run in the background" — and why `nohup` does it for
   you: "If standard input is a terminal, redirect it from an unreadable file."

| Case | Do |
|------|----|
| One-shot call whose output you need in this step | `cmd … </dev/null` plus the tool's non-interactive flag |
| Call that must outlive the session | `nohup cmd … </dev/null >"$LOG" 2>&1 & disown` ([platforms-processes-background-services]) |
| Tool authenticates over the network | Add the tool's fail-fast switch so a missing credential errors instead of prompting: `ssh -o BatchMode=yes`, `GIT_TERMINAL_PROMPT=0`, `DEBIAN_FRONTEND=noninteractive` |
| Any unattended call | Wrap in a timeout so a block fails loudly: `timeout <secs> cmd …` (on macOS, `gtimeout` — see [platforms-tools-bsd-vs-gnu-cli]) |

2. **Give the call a deadline rather than watching it.** `timeout` will "Start
   COMMAND, and kill it if still running after DURATION", exiting 124 when that
   fires — a distinguishable signal that the call blocked, instead of an agent turn
   that hangs until something else kills it.

3. **When it still hangs, locate the boundary before blaming either side.** Zero
   output is compatible with two very different faults: the request never left the
   client, or the far side never answered. Split them with evidence from the far
   side — the server/gateway access log for that source IP and time window, or a
   packet/connection count:

| Observation at the far side | Conclusion | Next action |
|-----------------------------|------------|-------------|
| No request recorded in the window | The call never got that far — it is blocked locally (stdin, auth prompt, DNS, proxy) | Re-run with `</dev/null` and a timeout; inspect the client's own debug/verbose log |
| Request recorded, no response or a slow one | The far side owns it | Take the latency/error question to the service |

4. **Re-run the identical command with stdin closed as the first diagnostic step.**
   If a `</dev/null` run returns immediately, the hang was a prompt, and no
   investigation of the far side is warranted.

## Edge cases

| Case | Then |
|------|------|
| Tool needs input you intend to supply | Feed it from a file or heredoc (`cmd <input.txt`), never leave it on the inherited terminal — an unfed prompt and a fed one are indistinguishable from the caller |
| Tool detects a TTY and changes output format (color codes, progress bars, pagers) | Closing stdin is not enough; also disable the pager/color explicitly (`GIT_PAGER=cat`, `--no-color`) so parsers see stable text |
| The call must run under a supervisor or scheduler | Services get no terminal at all, so the prompt fails differently there than in your shell — verify by log, not by launch exit code ([platforms-processes-background-services]) |
| Wrapper CLI shells out to a second binary that prompts | Redirecting the wrapper's stdin covers the child only if the child inherits it; confirm with a timeout run before trusting the wrapper's own flags |
| Hang reproduces even with stdin closed and a timeout | Treat it as a real far-side or network fault and continue from the boundary evidence in step 3 |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust a `--print`/`-p` flag to make a call safe for unattended use | Add `</dev/null` and a timeout alongside the flag | The flag governs output; a prompt the flag does not cover still reads the inherited terminal and blocks with no output |
| Conclude "the model/gateway/service is slow or broken" from a call that produced nothing | Check the far side's log for the request first | A locally blocked call leaves no trace there, so a hang with no logged request is evidence about the client, not the service |
| Watch a hung foreground call and cancel it by hand | Bound it with `timeout` and read exit 124 as "blocked" | Manual cancellation loses the distinction between slow and stuck, and burns the whole wait |
| Debug the hang by re-running it the same way | Re-run it with stdin closed as the first variation | Closing stdin is a one-token change that either fixes it or eliminates the largest class of cause |

## Sources

- https://man7.org/linux/man-pages/man1/nohup.1.html — "If standard input is a terminal, redirect it from an unreadable file" — detaching a command includes taking its terminal stdin away
- https://man.openbsd.org/ssh.1 — `-n` "Redirects stdin from /dev/null (actually, prevents reading from stdin). This must be used when ssh is run in the background"
- https://man.openbsd.org/ssh_config.5 — `BatchMode=yes` disables "user interaction such as password prompts and host key confirmation requests", "useful in scripts and other batch jobs where no user is present"
- https://man7.org/linux/man-pages/man1/timeout.1.html — "Start COMMAND, and kill it if still running after DURATION"; exit status 124 "if COMMAND times out, and --preserve-status is not specified"

## Field context

Distilled from a 2026-07 session that ran an agent CLI with its non-interactive
`--tools` flag in the foreground: two runs hung (300 s and 150 s) with zero bytes
of output. The gateway access log showed **no request from that host** in either
window, which ruled out the model and the gateway; the same command launched with
stdin taken from `/dev/null` completed its tool call immediately. The far-side-log
check in step 3 is the field-derived part of this page; the stdin rules in step 1
are the documented behavior the incident rediscovered.
