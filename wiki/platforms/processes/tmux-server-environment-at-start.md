---
id: platforms-processes-tmux-server-environment-at-start
domain: platforms
category: processes
applies_to: [tmux, macos, linux]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man1/tmux.1.html
  - https://man.openbsd.org/tmux.1
last_verified: 2026-10-29
related: [platforms-processes-driving-a-tui-in-a-tmux-pane, platforms-processes-spawning-an-agent-cli-from-a-server, testing-strategy-long-lived-processes-under-bats, testing-data-test-data-and-isolation]
---

# Environment a tmux Server Copies When It Starts

## When this applies

A script or launcher runs `tmux new-session` (or any tmux command that can
start a server) from a process whose environment holds values that later panes
must not see: run-scoped variables of a harness or plugin, session ids,
credentials, test switches. Also when a pane sees a variable on one machine and
not on another, or a variable you exported before launching never shows up in
the pane.

## Do this

1. **Know the copy rule.** When the server starts, tmux copies the starting
   client's whole environment into the server's *global environment*. Every
   window created later merges the global environment with its session
   environment, and session values win. The copy happens once, at server
   start, and never again. Panes created by *other* callers on the same server
   inherit it too.
2. **Strip the variables on the call that can start the server, every time**:
   `env -u SECRET -u RUN_ID tmux -L "$sock" new-session -d …`, or build the
   environment from an allow-list (`env -i PATH="$PATH" HOME="$HOME" … tmux …`).
   Do it whether or not a server seems to be running. `tmux has-session` cannot
   tell "no server" from "no such session", and a server can exit between the
   check and the start.
3. **Pass the values a pane does need explicitly.** Use `new-session -e
   VAR=value`, which sets a session variable. Or export the value in the
   command the pane runs.
4. **Expect an already-running server to ignore your current environment.** A
   later `new-session` adds only the names listed in the `update-environment`
   option to the session environment. Anything else you exported after the
   server started never reaches new panes.

| Situation | Do |
|-----------|----|
| The launcher may be the first tmux call on the machine | Strip on that call (step 2) |
| Panes must get a value the launcher holds | `new-session -e VAR=value`, not "leave it in the environment" |
| A value must stay out of child processes but stay visible to tmux formats | `set-environment -h` marks it hidden; hidden variables are not passed to new processes |
| Tests must not touch the developer's server | Use a private socket (`-L name` or `-S path`) so the test starts its own server with the stripped environment |

## Edge cases

| Case | Then |
|------|------|
| You strip only when `has-session` reports no server | A race and the ambiguous exit status reopen the leak. Stripping on an existing server changes nothing, so strip unconditionally |
| You run `set-environment -g -u VAR` after starting | Until that line runs, the value is live in the global environment. The command also deletes a value a user set on a server your script did not start |
| A caller's variable name is not a valid shell name (`LO_A-B`) | A shell `unset` cannot remove it. Field measurement on macOS: `/bin/sh` passed such a name through to the child, `dash` dropped it. Strip with `env -u` or an `env -i` allow-list, and test it on the shell your launcher actually uses |
| Variables the user's own tools read (a guard plugin's audit-log path) are in the strip set | They no longer reach panes started by this launcher. A worker on an already-running server never had them either, so stripping does not make this worse. Pass any that are needed with `-e` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on `new-session -e` to keep a variable out | Strip it from the environment of the starting call | `-e` sets a session value; the server still copies the whole client environment into the global one |
| Debug "the variable is missing in the pane" in the launcher | Check whether the server was already running (`tmux -L <sock> list-sessions`) and read `show-environment -g` | The pane gets what the server copied at start, not what the launcher has now |

## Sources

- https://man7.org/linux/man-pages/man1/tmux.1.html — section GLOBAL AND SESSION ENVIRONMENT: at server start tmux copies the environment into the global environment; each session has a session environment; a new window merges the two, with session values taking precedence; `update-environment` updates the session environment from the client when a session is created or attached; hidden variables (`-h`) are not passed to new processes
- https://man.openbsd.org/tmux.1 — `new-session -e VARIABLE=value` sets an environment variable for the newly created session
- Field context 2026-10-29 (tmux 3.7b, macOS; a launcher script that starts agent workers in tmux): the plan's research quoted the 3.7b man page and the server-start loop in `tmux.c`, which calls `environ_put` on every `environ` entry into `global_environ`. It chose `env -u` on the one server-starting call and rejected a conditional strip, `set-environment -g -u`, and `new-session -e` for the reasons in the edge-case rows. The man-page text was re-checked here through a web-search summary. The tmux.c source was not re-read
