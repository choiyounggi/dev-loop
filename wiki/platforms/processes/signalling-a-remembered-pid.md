---
id: platforms-processes-signalling-a-remembered-pid
domain: platforms
category: processes
applies_to: [macos, linux, claude-code]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man2/pidfd_send_signal.2.html
  - https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/proc_internal.h
  - https://man7.org/linux/man-pages/man8/lsof.8.html
  - https://code.claude.com/docs/en/how-claude-code-works
  - https://nextjs.org/docs/app/guides/ai-agents
  - https://unpkg.com/next@16.3.8/dist/server/lib/start-server.js
  - "macOS pgrep(1) and ps(1) man pages, Darwin 25.1"
  - "Field case 2026-10-07 (a dev-loop worker resumed with claude --resume)"
last_verified: 2026-10-08
related: [security-incident-response-process-identity-by-path-and-hash, infrastructure-agent-orchestration-autonomous-decision-rulings, platforms-processes-background-services]
---

# Signalling a PID Remembered From Earlier

## When this applies

You are about to `kill` (or otherwise signal) a PID you did not look up just
now: one in a resumed agent session's history (`claude --resume` and
`--continue` reopen the old conversation), a log line, a pidfile, or a tool's
own lock file (`next dev` writes its PID to `.next/dev/lock`). For example, a
resumed worker stops the dev servers or watchers it started before a restart.

## Do this

1. **Look the process up again from a live property, right before the
   signal.**

| What you know about the process | Look it up with |
|---------------------------------|-----------------|
| The port it listens on | `lsof -nP -iTCP:<port> -sTCP:LISTEN -t` (prints PIDs only) |
| A distinctive part of its command line | `pgrep -f '<pattern>'` |

2. **Confirm each PID's identity before signalling it, with a property that
   differs between sessions.** At launch, record `ps -o lstart=,command= -p <pid>`
   for the process that actually listens (look it up as in step 1): a process
   can rename itself, so the listener's command is what `ps` showed then, not
   what you typed. Before the signal, all of these must hold:

| Check | Command | Must match |
|-------|---------|------------|
| Start time | `ps -o lstart= -p <pid>` | The `lstart` recorded at launch, exactly |
| Command | `ps -o command= -p <pid>` | The command recorded at launch |
| Working directory | `lsof -a -p <pid> -d cwd -Fn` (the `n` line) | Your own checkout or worktree path |

   A PID that fails any row, or shows no process at all, is not yours: report
   that process as gone and send no signal. With no launch record, the working
   directory row is the one that separates your server from a sibling
   worktree's server running the same command.

3. **When you resume a worker, put the rule in the resume prompt:** "PIDs in
   your history are stale; find processes by port or command and confirm them
   with `ps` before any kill." A resumed session reads its old tool output as
   current facts.

## Edge cases

| Case | Then |
|------|------|
| You use `pkill -f <pattern>` instead of `kill <pid>` | macOS `pgrep`/`pkill` skip their own process and its ancestors by default (`-a` includes them), so the caller's shell is not matched; a sibling session's process with a matching command line still is, so list the matches with `pgrep -f` and run step 2 on each first |
| The tool records its own PID (`.next/dev/lock` holds PID, port and URL) | Treat that file as a remembered PID and confirm it with step 2. Running `next dev` again while a server is up prints the running server's URL and PID with a command to stop it |
| The listener renames itself (Next.js sets `process.title` to `next-server (v<version>)`) | Every session's dev server shows the same command, so the command row cannot tell them apart; rely on the working directory and the recorded `lstart` |
| The PID is your own process or one of its ancestors (`$$`, `$PPID`, upward) | Stop and report it: a recycled number can land on the session's own tree, and signalling it ends the session |
| Linux, and the launcher kept a pidfd from launch | Signal through `pidfd_send_signal`; the descriptor stays bound to the original process, so a recycled number cannot be hit |
| macOS | PIDs wrap after `PID_MAX` 99999 in XNU, so a remembered PID can name a new process: apply steps 1 and 2 before every signal |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run `kill <pid>` with a PID copied from the transcript after a resume | Find the process by port or command (step 1) and confirm it with the step-2 table | A recycled number reaches whatever process holds it now; in the field case the resumed worker's CLI exited right after such a `kill`, twice |
| Kill whatever holds the port after checking only its command | Also compare its working directory with yours (step 2) | Another session's server on the same port can run the identical command |

## Sources

- https://man7.org/linux/man-pages/man2/pidfd_send_signal.2.html — NOTES: with a PID as the target, "the sender may accidentally send a signal to the wrong process if the originally intended target process has terminated and its PID has been recycled for another process"
- https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/proc_internal.h — `#define PID_MAX 99999`
- https://man7.org/linux/man-pages/man8/lsof.8.html — `-t` "produce terse output comprising only process identifiers (without a header)"; "to list only network files with TCP state LISTEN, use: -iTCP -sTCP:LISTEN"; `-n` and `-P` skip host-name and port-name lookups
- https://code.claude.com/docs/en/how-claude-code-works — "Resuming a session with `claude --continue` or `claude --resume` reopens it under the same session ID and appends new messages to the existing conversation."
- https://nextjs.org/docs/app/guides/ai-agents — "`next dev` also writes its PID, port, and URL to `.next/dev/lock`. If you run `next dev` while another development server is already running for the project, the command prints the existing server's URL and PID, along with a command to stop it."
- macOS man pages (Darwin 25.1): pgrep(1) "-a Include process ancestors in the match list. By default, the current pgrep or pkill process and all of its ancestors are excluded"; ps(1) "lstart The exact time the command started"
- https://unpkg.com/next@16.3.8/dist/server/lib/start-server.js — line 180 sets `process.title = \`next-server (v${"16.3.8"})\`` with no condition (16.4.0: line 177, same form)
- Local check 2026-10-08 (macOS, Darwin 25.1): `ps -o pid=,lstart=,command= -p $$` printed the PID, start time and full command; `pgrep -f` with a pattern that appeared only in its parent shell's command line printed nothing (exit 1); `lsof -a -p $$ -d cwd -Fn` printed the shell's working directory on its `n` line
- Field case 2026-10-07 (a dev-loop worker in a Next.js project, resumed with `claude --resume`): the resumed session's last tool call was a `kill` of two PIDs it had started before the restart; the CLI exited at once, and the same happened after the next resume. Which process held each number at that moment was not recoverable, so the case shows the risk the pidfd man page describes without proving which process was hit
