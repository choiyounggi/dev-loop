---
id: platforms-processes-background-services
domain: platforms
category: processes
applies_to: [macos, linux]
confidence: verified
sources:
  - https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
  - https://man7.org/linux/man-pages/man5/systemd.service.5.html
  - https://man7.org/linux/man-pages/man5/crontab.5.html
  - https://man7.org/linux/man-pages/man1/nohup.1.html
  - https://man7.org/linux/man-pages/man1/loginctl.1.html
last_verified: 2026-07-10
related: [platforms-toolchains-version-management, platforms-shells-portable-shell-scripts]
---

# Keeping a Process Running Beyond the Terminal Session

## When this applies

Something must run persistently or on a schedule on a developer machine or server
(daemon, watcher, scheduled job); or a process you "started" dies when the
terminal, SSH connection, or agent session ends.

## Do this

A process started from a shell dies with the session unless detached. Choose the
mechanism by required lifetime:

| Case | Do |
|------|----|
| Quick detach from a terminal, best-effort lifetime (dies at reboot) | `nohup cmd >"$LOG" 2>&1 & disown` |
| Persistent user-level service on macOS | launchd LaunchAgent: plist in `~/Library/LaunchAgents` with `Label`, `ProgramArguments`, `KeepAlive`; load with `launchctl` |
| Persistent service on Linux | systemd user unit with `Restart=on-failure`; `systemctl --user enable --now <unit>` |
| Scheduled runs on macOS | launchd `StartCalendarInterval` in the plist — cron on macOS is legacy |
| Scheduled runs on Linux | crontab entry or a systemd timer unit |
| Must run before login / as root | LaunchDaemon in `/Library/LaunchDaemons` (macOS) or a system systemd unit (Linux) instead of the user-level variants |

Then apply all four of these regardless of mechanism:

1. **Minimal environment.** cron and launchd run jobs without your interactive
   environment — no rc files, no user PATH. Write absolute paths for every binary
   and declare needed env vars inside the unit/plist/crontab line. This is the #1
   cause of "works in my terminal, fails in cron".
2. **Explicit logs.** Services have no terminal: set `StandardOutPath`/
   `StandardErrorPath` in the plist, `StandardOutput=`/journal in systemd, or
   `>>"$LOG" 2>&1` on the crontab line. A service without a log sink fails silently.
3. **Supervisor restart, not watchdog scripts.** Use `KeepAlive` (launchd) or
   `Restart=on-failure` (systemd) for crash recovery.
4. **Verify by observing, not by launch exit code.** After starting, confirm with
   `launchctl list | grep <label>`, `systemctl --user status <unit>`, or by tailing
   the log — the start command succeeding does not mean the process stayed up.

## Edge cases

| Case | Then |
|------|------|
| Job works in a terminal, fails under cron/launchd | Environment gap. Reproduce with `env -i /bin/sh -c '<command>'`; fix by absolute-pathing binaries and exporting env in the unit |
| Service runs a version-manager-installed binary (nvm node, pyenv python) | Shims and lazy-loaders need rc files that services never load — invoke the real binary's absolute path (see platforms-toolchains-version-management) |
| Process started as an agent-harness background task (e.g. run_in_background) must outlive the session | The harness kills its background tasks when the session ends — detach with `nohup … & disown` or promote to a service unit |
| Linux user service must survive logout | `loginctl enable-linger <user>` — user units otherwise stop when the last session closes |
| Scheduled job sometimes double-runs or overlaps its previous run | Make the job idempotent and take a lockfile (`flock`) at the top |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Keep a terminal or tmux pane open as "deployment" | A supervised service unit (LaunchAgent / systemd) | Survives logout and reboot, and carries a restart policy |
| Write a `while true; do app; done` restart wrapper | `KeepAlive` / `Restart=on-failure` | The supervisor already handles crash loops, backoff, and status reporting |
| Debug a failing cron job by running it in your shell | Run it under `env -i` or the supervisor itself and read the job's log | Your shell's environment hides exactly the failures the minimal environment causes |

## Sources

- https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html — LaunchAgent plists, KeepAlive, StartCalendarInterval
- https://man7.org/linux/man-pages/man5/systemd.service.5.html — `Restart=on-failure` semantics
- https://man7.org/linux/man-pages/man5/crontab.5.html — cron-set environment (SHELL/HOME/LOGNAME), overridable in the crontab
- https://man7.org/linux/man-pages/man1/nohup.1.html — run a command immune to hangups
- https://man7.org/linux/man-pages/man1/loginctl.1.html — `enable-linger` keeps user services running while logged out
