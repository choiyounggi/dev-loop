# platforms — Domain Index

Route here for: OS-level differences that break code and scripts moving between
macOS, Linux, and Windows — shell portability, BSD-vs-GNU CLI flags, filesystem
case/line-ending/path behavior, file permissions and exec bits across
git/archives/containers, hidden environment inputs (timezone/locale, Unicode
normalization form in text and file names, per-context PATH resolution), keeping
processes alive as services or scheduled jobs, and
pinning toolchain versions across machines. Application logic stays in backend;
SQL stays in databases.

Match your situation to a "load when" line; load only matching pages.

## shells

| Page | Load when |
|------|-----------|
| [portable-shell-scripts](shells/portable-shell-scripts.md) | Writing a shell script that must run on more than one machine/OS/shell or in CI; a script that works locally fails elsewhere; choosing a shebang (bash vs sh); a bash script misbehaves in zsh or vice versa (unquoted vars, `=word`, array indexing); deciding how `set -euo pipefail` protects (and doesn't); building argument lists safely |
| [exit-status-vs-diagnostics](shells/exit-status-vs-diagnostics.md) | Wrapping a compiler/linter/validator in a gate (CI step, git hook, agent tool-use hook) that must surface warnings, not only failures; a gate reports clean on a file the tool complained about; choosing which stream to capture and in which redirection order |
| [option-like-argument-values](shells/option-like-argument-values.md) | Interpolating text you did not author (user input, model output, file contents, a message body) into a command as an operand; a call fails with "unknown flag"/"invalid option" on text that is correct as data; deciding where `--` belongs and what to do when a program ignores it |
| [env-var-off-switches](shells/env-var-off-switches.md) | Disabling part of a script from outside with an environment variable, or writing the switch that reads one; a feature you turned off keeps running silently; choosing between `${VAR:-default}` and `${VAR-default}`; passing a sentinel value when you cannot edit the script |
| [command-text-inspected-before-execution](shells/command-text-inspected-before-execution.md) | A hook, policy gate, allow-list, or audit rule blocked a command that is correct as written; composing a command that must satisfy such a gate first try; deciding whether to write a path literally or as `"$VAR"` in an inspected argument; a gate reports an argument missing or a file nonexistent though both are right; a gate must read a file your command creates; prose containing a dangerous-looking command (release notes, docs, fixtures) trips a text scanner |

## tools

| Page | Load when |
|------|-----------|
| [bsd-vs-gnu-cli](tools/bsd-vs-gnu-cli.md) | A command works on Linux but fails on macOS or vice versa (`date`, `sed -i`, `timeout`, `seq`, `grep -P`, `readlink`, `stat`); writing a script or CI step that must run on both userlands; deciding whether to install GNU coreutils on macOS or write POSIX-only |

## environment

| Page | Load when |
|------|-----------|
| [timezone-and-locale](environment/timezone-and-locale.md) | Date/time or text-processing code behaves differently across machines (passes locally, fails in CI or vice versa); a cron/scheduled job fires at the wrong hour or double-fires/skips around DST; reviewing code that formats, parses, or compares dates or strings; writing tests that touch time; building case-insensitive keys, sorted output, or number parsing that must agree across machines |
| [unicode-text-matching](environment/unicode-text-matching.md) | A grep/regex pattern over non-ASCII text (Korean/Japanese/accented Latin/emoji) returns zero hits on text you can see; writing a pattern that must match an inflected or precomposed word; a search or name comparison works on one machine and misses after the file crossed an OS/archive/editor boundary; deciding where to normalize (NFC/NFD) user-supplied text used as a key |
| [path-resolution](environment/path-resolution.md) | "command not found" though the tool is installed; a different version runs than the one installed; sudo/CI/cron/GUI apps/ssh can't find a command the interactive shell finds; two installations of the same tool conflict; deciding how a script should locate its correctness-critical tools |

## filesystems

| Page | Load when |
|------|-----------|
| [paths-case-and-line-endings](filesystems/paths-case-and-line-endings.md) | A repo moves between macOS/Windows/Linux and files disappear or collide; an import resolves locally but fails on Linux CI (casing); renaming only the case of a file; diffs show every line changed or a script dies with `bad interpreter: ^M` (CRLF); setting up `.gitattributes` line-ending policy; generating file names or paths that must be valid on Windows (reserved names, path length) |
| [permissions-and-exec-bits](filesystems/permissions-and-exec-bits.md) | "Permission denied" running a script that exists; a script loses its executable bit through git/Windows/zip/CI artifacts; surprise file-mode diffs in git (`core.fileMode`); docker bind-mount files root-owned or unreadable (host/container uid mismatch); pipeline stages can't read each other's artifacts (umask); setting up a shared directory for several users/daemons; reviewing file-permission handling in a repo or pipeline |

## processes

| Page | Load when |
|------|-----------|
| [background-services](processes/background-services.md) | Something must run persistently or on a schedule on a dev machine or server (daemon, watcher, cron-style job); a "started" process dies when the terminal/SSH/agent session ends; choosing nohup vs LaunchAgent vs systemd unit vs cron/timer; a job works in the terminal but fails under cron/launchd (minimal environment); wiring service logs and restart policy |
| [non-interactive-cli-invocation](processes/non-interactive-cli-invocation.md) | Calling a tool that can prompt (agent CLI, ssh, git, package manager) from a script, CI step, hook, or agent session, including with its own `-p`/`--print`/`--yes` flag; such a call produced no output and never returned; deciding whether a hang belongs to the client, the network, or the far-side service; choosing the stdin/timeout/fail-fast switches for an unattended call; a TTY-detecting tool changes its output format under automation |

## toolchains

| Page | Load when |
|------|-----------|
| [version-management](toolchains/version-management.md) | "Works on my machine" from tool-version drift; a project needs a pinned language/tool version (.nvmrc, .python-version, .tool-versions); making CI use the same versions as local; onboarding a machine reproducibly; a script/cron/CI step can't find a version-managed binary (shims absent in non-interactive shells); deciding where lockfiles fit in reproducibility |

## Planned (unseeded categories)

| Category | Will cover |
|----------|-----------|
| windows | PowerShell vs cmd specifics, WSL boundaries |
| linux | Distro packaging, container-host interactions |
