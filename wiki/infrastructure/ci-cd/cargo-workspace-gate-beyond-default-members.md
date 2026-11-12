---
id: infrastructure-ci-cd-cargo-workspace-gate-beyond-default-members
domain: infrastructure
category: ci-cd
applies_to: [rust, cargo]
confidence: verified
sources:
  - https://doc.rust-lang.org/cargo/reference/workspaces.html
  - https://doc.rust-lang.org/cargo/commands/cargo-build.html
  - https://doc.rust-lang.org/cargo/commands/cargo-test.html
  - https://github.com/expo/exact/blob/18b358e094d35d2a9faa49ac76458caf9b488ff9/AGENTS.md
last_verified: 2026-11-12
related:
  [
    infrastructure-ci-cd-pipeline-structure,
    infrastructure-ci-cd-changed-files-only-gates,
    platforms-toolchains-version-management,
  ]
---

# CI gate for a Cargo workspace that declares `default-members`

## When this applies

- A Cargo workspace root sets `default-members` (or has a root package), and CI or a
  pre-merge check runs `cargo build` / `cargo test` / `cargo clippy` at the root
  without `-p` or `--workspace`.
- You are writing the merge gate for a Rust workspace, or a crate outside the default
  set broke on main while every check stayed green.

## Do this

At the workspace root with no package flag, Cargo operates on `default-members` only
(a root package when one exists; every member only in a virtual workspace without
`default-members`). A broken crate outside that set compiles nowhere in such a gate.

| Case | Do |
|------|----|
| The gate runs root-level cargo commands and the workspace sets `default-members` | Add `cargo check --workspace --all-targets --keep-going` as its own gate step; it compiles every member and every target (tests, examples, benches) and runs no tests |
| The default set is kept small on purpose so the blocking gate stays fast | Keep the fast steps on `default-members` and run the `--workspace` check beside them; run `cargo test --workspace` in a slower lane (per commit after merge, or nightly) |
| You change a crate outside `default-members` | Run that crate's tests by name before merging: `cargo test -p <crate> --lib --tests --no-fail-fast` (`--bins` for a bin-only crate) |
| The gate should report every broken crate and every failing test binary in one run | Pass `--keep-going` to `cargo build`/`check`/`clippy` and `--no-fail-fast` to `cargo test`; without them Cargo stops at the first failing crate or test binary |
| Clippy is part of the gate | Run `cargo clippy --all-targets --keep-going -- -D warnings` and `cargo fmt --all -- --check` as two commands, so a format failure and a lint failure both show |

Prove the gate before you rely on it: put a type error in a crate outside
`default-members` on a scratch branch and require the `--workspace` step to fail.

## Edge cases

| Case | Then |
|------|------|
| `cargo check --workspace` costs its full time again after `cargo build` | Expected: `check` produces metadata only and shares no compiled crate with `build`. Budget it as a separate step (Exact measured 2-5 s warm, 45-90 s after a touched core crate, 2.4 min cold on an 18-core Mac) |
| A member's build script needs a tool (a pinned Bun, a code generator) that the default members never invoked | Put that tool on the gate's `PATH` before the `--workspace` step; the first full-workspace run is where the missing tool appears |
| A crate is a static library that a platform build script links (an Apple `.a`, an Android `.so`) | Treat a green `--workspace` check as "it compiles", and run the platform build plus a launch of that app when the change can affect runtime behavior |
| The shell exports `CARGO_INCREMENTAL=0` | A hand-run dev build then recompiles whole crates (Exact: a touched kernel line took 17 s instead of 6); unset it for local loops and keep it set only where CI wants reproducible artifacts |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read a green root-level `cargo test` as "the workspace is healthy" | Add the `cargo check --workspace --all-targets --keep-going` step and read its result | `default-members` narrows every root command that has no package flag |

## Sources

- Cargo Book, Workspaces: "if the current directory is a workspace root, the
  `default-members` will be used"; in a virtual workspace without it, "all members will
  be used (as if `--workspace` were specified)".
- `cargo build --help` (cargo 1.98.0): `--keep-going  Do not abort the build as soon as
  there is an error`; `cargo test` documents `--no-fail-fast`.
- expo/exact `AGENTS.md` at 18b358e: the sixth blocking check was added after six things
  outside `default-members` were broken on main on 2026-10-11 while the other five
  checks were green; timing figures and the `CARGO_INCREMENTAL=0` measurement come from
  the same file.
- Local reproduction, 2026-11-12, cargo 1.98.0: workspace `members = ["a", "b"]`,
  `default-members = ["a"]`, crate `b` returning `&str` from a `u8` function.
  `cargo build --all-targets --keep-going` exit 0, `cargo test --tests --no-fail-fast`
  exit 0, `cargo check --workspace --all-targets --keep-going` exit 101 with
  "error: could not compile `b` (lib)".
