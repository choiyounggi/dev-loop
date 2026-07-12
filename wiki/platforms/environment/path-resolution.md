---
id: platforms-environment-path-resolution
domain: platforms
category: environment
applies_to: [macos, linux]
confidence: field-tested
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/command.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/hash.html
  - https://man7.org/linux/man-pages/man7/environ.7.html
  - https://www.sudo.ws/docs/man/sudoers.man/
last_verified: 2026-07-10
related: [platforms-toolchains-version-management, platforms-processes-background-services]
---

# The Wrong Binary (or None) Resolving From PATH

## When this applies

"command not found" though the tool is installed; a DIFFERENT version runs than
the one you installed; sudo, CI, or cron can't find a command your shell finds;
two installations of the same tool conflict. (PATH/sudo/hash mechanics are
doc-backed; the GUI-app and ssh rows are field-tested practice.)

## Do this

The shell resolves a bare command name by scanning `PATH` left-to-right and
executing the first match. Diagnose before theorizing: run `command -v <cmd>`
and `type <cmd>` — they show what will ACTUALLY run, including when it is an
alias, shell function, or builtin rather than the binary you expect.

Two installations / wrong version:

| Case | Do |
|------|----|
| brew/user-installed tool shadowed by a system binary (or vice versa) | `command -v` reveals which wins; fix by reordering `PATH` in the shell init of the context that runs it, or invoke the absolute path |
| You just installed/moved a binary but the OLD one still runs | `hash -r` — the shell remembers resolved locations and reuses them until told to forget or until `PATH` is reassigned |
| A version manager's tool resolves interactively but not in scripts/cron/CI | Shims sit first in `PATH` only where the manager's rc hook ran — [platforms-toolchains-version-management] owns that case |

Each execution context has its OWN `PATH` — set it where that context reads it:

| Context | Do |
|---------|----|
| sudo | sudoers `secure_path` replaces `PATH` for the command, so `sudo cmd` resolves differently than `cmd`. Use `sudo env PATH="$PATH" cmd`, the absolute path, or add the directory to `secure_path` in sudoers deliberately |
| cron / launchd / systemd services | Daemon-spawned jobs get a minimal `PATH`, no rc files — [platforms-processes-background-services] owns the fix (absolute paths, env in the unit) |
| GUI apps (Finder/Dock-launched editors, IDEs, their integrated terminals' parents) | They inherit the login session's environment, not your shell rc — set the tool path in the app's own settings/env definition, or launch the app from a terminal so it inherits that shell |
| `ssh host cmd` (non-interactive) | A non-interactive shell reads different startup files than your interactive login, so rc-set `PATH` entries are absent — use absolute paths or source the needed setup in the command |

Scripts must not depend on the caller's `PATH` for correctness-critical tools:
resolve once at the top and fail loud —

```sh
TOOL="$(command -v tool)" || { echo "tool not found in PATH" >&2; exit 1; }
```

— or pin the absolute path outright. Automation (hooks, agents, daemons) pins
binaries; interactive convenience is the only place bare names are safe.

## Edge cases

| Case | Then |
|------|------|
| `command -v` shows an alias/function, not a binary | You are debugging the wrong thing — `type <cmd>` names the kind; bypass with `command <cmd>` or the absolute path to test the real binary |
| `PATH` reordered in the rc file but the running shell still resolves the old one | Rc edits apply to NEW shells; `exec $SHELL -l` or open a fresh terminal, then `hash -r` |
| Same command, different result under `env -i sh -c 'cmd'` | The difference is your interactive environment — reproduce daemon/CI behavior this way before blaming the machine |
| An empty entry or `.` in `PATH` | Current-directory lookup: a file named like a common command in the cwd gets executed — remove the entry and use `./name` for local scripts |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `export PATH=...` lines to every rc file until it works | Identify which context runs the command (interactive shell, sudo, cron, GUI app, ssh) and set `PATH` in THAT context's init point once | Shotgun exports mask the real resolution order and drift apart across files |
| `which cmd` for debugging resolution | `type cmd` / `command -v cmd` | `which` is an external binary that scans `PATH` — it cannot see the aliases, functions, and builtins your shell will run first |
| Calling a bare tool name in a hook/daemon/agent script | Resolve to `TOOL="$(command -v tool)"` with a fail-loud check, or hardcode the absolute path | The caller's `PATH` is not yours; silent resolution to a different or missing binary corrupts the run |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — command search: no-slash names resolved via `PATH` in order; shells may remember locations until `PATH` is reassigned
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/command.html — `command -v` prints the pathname/alias/function/builtin the shell would use
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/hash.html — `hash -r` forgets all remembered utility locations
- https://man7.org/linux/man-pages/man7/environ.7.html — `PATH`: colon-separated directory prefixes searched for executables
- https://www.sudo.ws/docs/man/sudoers.man/ — `secure_path` value replaces `PATH` for sudo-run commands (with default `env_reset`)
