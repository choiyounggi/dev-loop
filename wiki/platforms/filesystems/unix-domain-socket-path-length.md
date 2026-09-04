---
id: platforms-filesystems-unix-domain-socket-path-length
domain: platforms
category: filesystems
applies_to: [macos, linux, node, general]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man7/unix.7.html
  - https://nodejs.org/api/net.html
  - macOS SDK `sys/un.h` — `char sun_path[104];`
last_verified: 2026-09-04
related: [platforms-filesystems-paths-case-and-line-endings, infrastructure-agent-orchestration-worktree-isolated-workers, platforms-processes-non-interactive-cli-invocation]
---

# A Unix Domain Socket Bind Failing Only Inside a Deep Worktree Path

## When this applies

Binding or listening on a unix domain socket (an IPC test, a dev-server
socket) fails with "Failed to listen", `listen EINVAL`, `ENAMETOOLONG`, or
"AF_UNIX path too long" only when run from inside a git worktree
(`.worktrees/<task>/...`) or another deeply nested directory, while the
identical code passes from the main checkout or a shorter path. Also when
choosing where to place a socket file for a test suite or IPC channel.

## Do this

1. **Compare against the fixed socket-address limit before treating this as
   a code bug.** Unix domain socket addresses use a fixed-size `sun_path`
   buffer, not the filesystem's general path-length limit — macOS: 104 bytes;
   Linux: 108 bytes. A path well within the OS's normal file-path limit
   (1024 on macOS, 4096 on Linux) still overflows this buffer.
2. **Measure the candidate socket path's byte length**
   (`printf '%s' "$path" | wc -c`) before debugging further — a
   `.worktrees/<task-slug>/node_modules/.cache/...` prefix alone consumes
   60–80 bytes before the socket's own filename is appended.
3. **Choose the fix by where the path is generated:**

| Case | Do |
|------|----|
| Socket path comes from `os.tmpdir()` or another fixed short root | Keep it there regardless of cwd; derive nothing from the project directory |
| Socket path is derived from the repo/worktree root (`path.join(__dirname, ...)`, `process.cwd()`) | Redirect it to a short, fixed location outside the repo so worktree depth cannot affect it |
| Verifying whether a suite failure is this limit or a real regression | Run the identical suite from the main checkout (short path) alongside the worktree run; a pass in the short path and a listen failure in the worktree path is this limit |
| A path is already short but still fails | Check for a symlinked or resolved absolute path longer than the literal one written in code — `realpath` can lengthen a path that looked short |

4. **Read the failure from the library's own docs when in doubt.** Node's
   `net`/`http` server "will throw an error when the length of pathname is
   greater than the length of `sizeof(sockaddr_un.sun_path)`. Typical values
   are 107 bytes on Linux and 103 bytes on macOS" (one less than the raw
   buffer because the null terminator is excluded); on macOS the error
   surfaces as `listen EINVAL`, not as a path-length message.

## Edge cases

| Case | Then |
|------|------|
| The failing suite runs under several worktrees at once (parallel orchestration) | Give each worktree's sockets a short, run-scoped root outside any worktree path, keyed by run id rather than by worktree path |
| The socket must live inside the worktree for cleanup-on-delete semantics | Create a short symlink from a fixed short path into the worktree location, and point the socket at the symlink |
| Switching to `os.tmpdir()` still overflows | `TMPDIR` itself can be a long per-user path (macOS `/var/folders/...`, some CI images) — measure its length before assuming it is short |
| The error message is generic ("Failed to listen") with no path-length mention | The wrapping library does not always surface `bind(2)`'s errno clearly — reproduce the failing bind call directly (`node -e` with `net.createServer().listen(path)`) to see the underlying error code |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Debug application logic because a socket test fails only in CI or worktree checkouts | Compare the socket path's byte length against 104 (macOS) / 108 (Linux) first | The failure is a fixed protocol-level buffer limit unrelated to the code under test — nesting the checkout one directory deeper is enough to cross it |
| Derive a unix socket's path from the project or worktree directory "for locality" | Derive it from a short, run-scoped path outside the repo | The socket address buffer is far shorter than the filesystem's own path limit, so any project-rooted path is one refactor away from crossing it |

## Sources

- macOS SDK `sys/un.h` (confirmed on this host 2026-09-04, `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/un.h`): `char sun_path[104];  /* [XSI] path name (gag) */`
- https://man7.org/linux/man-pages/man7/unix.7.html — `struct sockaddr_un { sa_family_t sun_family; char sun_path[108]; }`
- https://nodejs.org/api/net.html — "It will throw an error when the length of pathname is greater than the length of `sizeof(sockaddr_un.sun_path)`. Typical values are 107 bytes on Linux and 103 bytes on macOS."
- Local reproduction 2026-09-04 (macOS, Node v26.7.0): `net.createServer().listen(<131-byte path>)` failed with `listen EINVAL: invalid argument <path>` — no `ENAMETOOLONG` and no mention of length in the message
- Field evidence 2026-08-19 (measured in a linkly-crew orchestration run): an IPC-listen test suite failed 14 cases from a git-worktree checkout and passed all of them from the main checkout; comparing the socket path's byte length against the worktree prefix explained the split
