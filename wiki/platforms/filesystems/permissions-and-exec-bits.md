---
id: platforms-filesystems-permissions-and-exec-bits
domain: platforms
category: filesystems
applies_to: [macos, linux, windows]
confidence: field-tested
sources:
  - https://git-scm.com/docs/git-update-index
  - https://git-scm.com/docs/git-config
  - https://man7.org/linux/man-pages/man2/umask.2.html
  - https://man7.org/linux/man-pages/man7/inode.7.html
  - https://docs.docker.com/engine/containers/run/
  - https://docs.docker.com/engine/storage/bind-mounts/
last_verified: 2026-07-10
related: [platforms-filesystems-paths-case-and-line-endings]
---

# Exec Bits and File Ownership Lost Across git, Archives, and Containers

## When this applies

"Permission denied" running a script that exists; a script's executable bit
disappears after passing through Windows, a zip, or CI; docker bind-mount files
come out root-owned or unreadable; reviewing file-permission handling in a repo
or pipeline. (Docker rows are field-tested operational practice; git/umask rows
are doc-backed.)

## Do this

The executable bit is file METADATA that git tracks as part of the blob entry
(mode `100755` vs `100644`). It travels only if committed, and only through
channels that preserve modes.

| Case | Do |
|------|----|
| Script is not executable after a fresh clone | The bit was never committed. Run `git update-index --chmod=+x <file>` and commit — this records mode `100755` in the index directly. A local `chmod +x` fixes only your checkout until the mode change is committed |
| Surprise file-mode diffs, or a repo touched on Windows/a filesystem without exec bits | Check `git config core.fileMode` BEFORE hunting for who changed what. With `fileMode=false` git ignores working-tree mode changes (and git sets it per-repo where the filesystem can't represent the bit); `update-index --chmod` still commits the bit there |
| Files pass through zip or an artifact store that strips modes | Re-assert modes in the consuming step (`chmod +x` after extraction) or sidestep the bit by invoking through the interpreter — `bash script.sh` needs no exec bit |
| Container process gets "permission denied" on a bind mount | The container sees HOST uid/gid NUMBERS, not names: uid 1000 in the container writing a mount owned by host uid 501 fails. Run the container as the host owner (`docker run --user "$(id -u):$(id -g)"`) or `chown` the mount path for the container's user at build/entrypoint |
| Files a container created on a bind mount are root-owned on the host | Same numeric-uid rule in reverse — created files belong to the container process's uid (root by default). Set `--user` to your host uid before the container writes |
| A later pipeline stage can't read artifacts an earlier stage produced | Created-file modes are `mode & ~umask` — a restrictive umask in the producing step yields group/other-unreadable files. Set `umask 022` (or the mode you need) explicitly at the top of steps that share files |
| A directory is shared by several users/daemons | Group-own the directory, `chmod g+ws` it (setgid: files created inside inherit the directory's group), and put both users in the group |

## Edge cases

| Case | Then |
|------|------|
| git shows a mode diff you didn't intend (e.g. after copying the tree through FAT/exFAT or a mount without exec bits) | Restore with `git update-index --chmod=-x <file>` or re-checkout; setting `core.fileMode=false` in THAT clone stops the noise without touching the repo |
| You need a mode other than 755/644 tracked in git | git tracks only executable-or-not (`100755`/`100644`) — enforce fuller modes (setgid, 600 secrets) in a deploy/entrypoint step, not via git |
| Exec bit committed but Windows-checkout users still can't run it | Windows doesn't consume the POSIX exec bit; invoke via the interpreter there. Line-ending/casing breakage on the same journey: [platforms-filesystems-paths-case-and-line-endings] |
| Rootless Docker / userns-remap in play | uids are remapped, so host-uid matching arithmetic changes — verify with `ls -ln` on the host and `id` inside the container before choosing `--user` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `chmod 777` to make a permission error go away | Identify WHICH user/process needs WHICH access (`ls -ln` + the failing process's uid) and grant exactly that — owner change, group+setgid, or `--user` | 777 is an incident deferred: any local user/process can now modify or replace the file |
| `chmod +x` locally and moving on | `git update-index --chmod=+x <file>` and commit | The local bit doesn't reach the repo; every fresh clone and CI run re-breaks |
| Running the container as root because the mount "just works" that way | `--user` matching the host owner, or entrypoint `chown` | Root-in-container writes root-owned files onto the host and widens container-escape blast radius |

## Sources

- https://git-scm.com/docs/git-update-index — `--chmod=(+|-)x` sets execute permission in the index
- https://git-scm.com/docs/git-config — `core.fileMode`: whether git honors working-tree exec-bit changes
- https://man7.org/linux/man-pages/man2/umask.2.html — created-file mode = requested mode with umask bits turned off
- https://man7.org/linux/man-pages/man7/inode.7.html — setgid on a directory: files created inside inherit the directory's group
- https://docs.docker.com/engine/containers/run/ — container default user is root (uid 0); `--user`/`-u` overrides with `uid:gid`
- https://docs.docker.com/engine/storage/bind-mounts/ — bind-mount mechanics (host uid/gid visibility rows are field practice, not stated on this page)
