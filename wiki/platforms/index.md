# platforms — Domain Index

Route here for: OS-level differences that break code and scripts moving between
macOS, Linux, and Windows — shell portability, BSD-vs-GNU CLI flags, filesystem
case/line-ending/path behavior, file permissions and exec bits across
git/archives/containers, hidden environment inputs (timezone/locale, per-context
PATH resolution), keeping processes alive as services or scheduled jobs, and
pinning toolchain versions across machines. Application logic stays in backend;
SQL stays in databases.

Match your situation to a "load when" line; load only matching pages.

## shells

| Page | Load when |
|------|-----------|
| [portable-shell-scripts](shells/portable-shell-scripts.md) | Writing a shell script that must run on more than one machine/OS/shell or in CI; a script that works locally fails elsewhere; choosing a shebang (bash vs sh); a bash script misbehaves in zsh or vice versa (unquoted vars, `=word`, array indexing); deciding how `set -euo pipefail` protects (and doesn't); building argument lists safely |

## tools

| Page | Load when |
|------|-----------|
| [bsd-vs-gnu-cli](tools/bsd-vs-gnu-cli.md) | A command works on Linux but fails on macOS or vice versa (`date`, `sed -i`, `timeout`, `seq`, `grep -P`, `readlink`, `stat`); writing a script or CI step that must run on both userlands; deciding whether to install GNU coreutils on macOS or write POSIX-only |

## environment

| Page | Load when |
|------|-----------|
| [timezone-and-locale](environment/timezone-and-locale.md) | Date/time or text-processing code behaves differently across machines (passes locally, fails in CI or vice versa); a cron/scheduled job fires at the wrong hour or double-fires/skips around DST; reviewing code that formats, parses, or compares dates or strings; writing tests that touch time; building case-insensitive keys, sorted output, or number parsing that must agree across machines |
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

## toolchains

| Page | Load when |
|------|-----------|
| [version-management](toolchains/version-management.md) | "Works on my machine" from tool-version drift; a project needs a pinned language/tool version (.nvmrc, .python-version, .tool-versions); making CI use the same versions as local; onboarding a machine reproducibly; a script/cron/CI step can't find a version-managed binary (shims absent in non-interactive shells); deciding where lockfiles fit in reproducibility |

## Planned (unseeded categories)

| Category | Will cover |
|----------|-----------|
| windows | PowerShell vs cmd specifics, WSL boundaries |
| linux | Distro packaging, container-host interactions |
