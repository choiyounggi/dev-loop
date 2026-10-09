---
id: platforms-filesystems-trailing-separator-under-realpath
domain: platforms
category: filesystems
applies_to: [general, rust]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/functions/realpath.html
  - https://doc.rust-lang.org/std/fs/fn.canonicalize.html
  - https://doc.rust-lang.org/std/path/index.html
  - https://www.gnu.org/software/coreutils/realpath
last_verified: 2026-09-28
related: [security-input-validation-at-trust-boundaries, platforms-tools-bsd-vs-gnu-cli, platforms-filesystems-paths-case-and-line-endings, infrastructure-config-path-valued-config]
---

# A Path Ending in a Separator Passed to realpath / canonicalize

## When this applies

Code resolves a path that may end in `/` (or `/.`) through `realpath(3)` —
Rust `std::fs::canonicalize`, C `realpath`, any binding over it — and the
result decides something: whether an untrusted relative path stays inside a
base directory, whether the entry is a file or a directory, whether it exists.
Also when such a check accepts on a developer's Mac and rejects on Linux CI, or
the reverse.

## Do this

1. **Decide the trailing-separator rule in your own code, before resolving.**
   POSIX says `realpath` "shall fail" with `ENOTDIR` when the name "ends with
   one or more trailing `<slash>` characters and the last pathname component
   names an existing file that is neither a directory nor a symbolic link to a
   directory"; glibc and musl do, macOS resolves `file/` to `file` and returns
   success. A verdict that depends on that error is a verdict that depends on
   the OS:

| libc / platform | `realpath("…/file/")` | `realpath("…/file/.")` |
|-----------------|-----------------------|------------------------|
| POSIX.1-2017 | shall fail, `ENOTDIR` | shall fail, `ENOTDIR` |
| glibc 2.41 (Linux) | `ENOTDIR` | `ENOTDIR` |
| musl (Alpine Linux) | `ENOTDIR` | `ENOTDIR` |
| macOS (Darwin 25.1) | `Ok("…/file")` | `Ok("…/file")` |
| GNU coreutils `realpath` command | "It ignores trailing slashes" (documented) | — |

2. **Check the raw string, not the path object.** Rust's `Path::join`,
   `PathBuf::push`, `components()` and `==` all "disregard trailing
   separators", yet the joined value handed to `canonicalize` still carries the
   bytes — `Path::new("a/b/") == Path::new("a/b")` is `true` while
   `canonicalize` receives `a/b/`. Test the string:
   `rel.ends_with(std::path::is_separator)` or `rel.ends_with("/.")`.
3. **Pick the action by what the input is allowed to name:**

| The input must name | Do |
|---------------------|----|
| A file | Reject a trailing separator (or `/.`) before resolving; report it the same way as a missing file |
| A file or a directory | Resolve, then when the raw input ended with a separator require `metadata(&resolved)?.is_dir()` — your check, not the resolver's error |
| A directory only | Resolve, then require `is_dir()` regardless of the suffix |

4. **Pin the `file/` case with a test and run it on both platforms.** The
   guard is invisible on Linux (the OS rejects anyway) and load-bearing on
   macOS; a mutation that removes the guard must turn the test red on macOS,
   and a CI matrix keeps the Linux verdict identical.

## Edge cases

| Case | Then |
|------|------|
| The last component is a symlink to a regular file, with a trailing slash | Same divergence — POSIX names "a symbolic link to a directory" as the only symlink case that resolves; apply the same string check |
| The suffix is `/.` rather than `/` | `ends_with(is_separator)` misses it; check `ends_with("/.")` too (macOS resolves it, glibc/musl return `ENOTDIR`) |
| The trailing slash arrives through a directory-only input (`out/`) | Legitimate on every platform: resolves to the directory. The rule fires only on a non-directory leaf |
| Containment is checked as `resolved.starts_with(base)` | Run the string check first; on macOS `base/report.md/` resolves inside `base` and passes containment while the caller asked for a directory that does not exist |
| Windows | `canonicalize` maps to `GetFinalPathNameByHandle`, not `realpath`; measure separately before assuming either row above |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Let `canonicalize`/`realpath` reject `file/` for you | Check the raw string and decide by intent (step 3) | macOS returns success on `file/`; only glibc/musl return `ENOTDIR` |
| Strip the trailing slash before resolving so both platforms agree | Reject it, or require `is_dir()` after resolving | Stripping accepts `report.md/` as `report.md`, which is exactly the macOS behavior you are trying not to depend on |
| Compare `Path` values to detect the slash | Compare the string (`ends_with(is_separator)`) | `Path` equality and `components()` normalize the separator away |
| Verify the containment check on the developer's Mac only | Add the `file/` case and run it on Linux CI too | The same input accepts on macOS and rejects on Linux; a single platform sees one verdict |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/functions/realpath.html — ERRORS, "shall fail": `[ENOTDIR]` "the file_name argument contains at least one non-<slash> character and ends with one or more trailing <slash> characters and the last pathname component names an existing file that is neither a directory nor a symbolic link to a directory"
- https://doc.rust-lang.org/std/fs/fn.canonicalize.html — "corresponds to the `realpath` function on Unix and the `CreateFile` and `GetFinalPathNameByHandle` functions on Windows"
- https://doc.rust-lang.org/std/path/index.html — "Several methods in this module perform basic path normalization by disregarding repeated separators, non-leading `.` components, and trailing separators"; "`Path::join` and `PathBuf::push` also disregard trailing slashes"
- https://www.gnu.org/software/coreutils/realpath — the coreutils command "ignores trailing slashes"
- Local reproduction 2026-09-28, libc `realpath` called through Python `ctypes` on a regular file `out/report.md`: macOS Darwin 25.1.0 → `Ok(out/report.md)` for both `out/report.md/` and `out/report.md/.`; `python:3-slim` (glibc 2.41) and `python:3-alpine` (musl) → `errno 20 Not a directory` for both. Rust (cargo 1.98.0, macOS): `base.join("out/report.md/")` keeps the slash (`ends_with(is_separator) == true`) and `std::fs::canonicalize` returns `Ok(…/out/report.md)`; `Path::new("out/report.md/") == Path::new("out/report.md")` is `true`
- Field evidence 2026-09-28 (a Rust CLI containing untrusted relative paths under an output directory, crew-run worktree t3-swap-flake; recorded by the originating session): the containment check accepted `…/out/report.md/` on macOS; a string guard on the trailing separator was pinned by a test named `path_entry_with_trailing_slash_is_missing_file_not_found`, and an independent auditor's mutation removing the guard turned it red
