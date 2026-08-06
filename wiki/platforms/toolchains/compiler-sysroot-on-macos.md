---
id: platforms-toolchains-compiler-sysroot-on-macos
domain: platforms
category: toolchains
applies_to: [macos, clang, llvm]
confidence: verified
sources:
  - https://github.com/llvm/llvm-project/issues/137352
  - https://github.com/Homebrew/homebrew-core/issues/197277
  - https://clang.llvm.org/docs/UsersManual.html
  - https://clang.llvm.org/docs/DiagnosticsReference.html
  - https://discourse.llvm.org/t/stdio-h-not-found-on-mac-how-to-add-system-headers-includes-into-clang/77604
last_verified: 2026-08-05
related: [platforms-toolchains-version-management, platforms-environment-path-resolution, debugging-signals-reading-error-messages]
---

# A Non-Apple Compiler Resolving the macOS SDK

## When this applies

On macOS, a compiler installed outside Xcode (Homebrew LLVM, MacPorts, a
downloaded toolchain) fails with `'stdio.h' file not found`, `ld: library
'System' not found`, or a `-Wmissing-sysroot` warning naming an SDK directory
that does not exist. Also when a build works under `/usr/bin/clang` but not
under the newer toolchain a project requires.

## Do this

1. **Resolve the SDK at build time, never hardcode it**: `xcrun --show-sdk-path`
   (or `xcrun --sdk macosx --show-sdk-path`) returns the SDK the active developer
   directory currently provides. A path written into a script pins an SDK version
   that a Command Line Tools or Xcode update removes.

2. **Feed it in by the channel that matches who owns the command line:**

| You control | Do |
|-------------|-----|
| The compile command | Pass `-isysroot "$(xcrun --show-sdk-path)"` on the command line |
| Only the environment (a build script, generator, or test harness invokes the compiler internally) | Export `SDKROOT="$(xcrun --show-sdk-path)"`; clang reads it as the default sysroot |
| Neither, and headers still are not found | Export `CPATH="$SDK/usr/include"`, which the driver adds to the include search path regardless of the sysroot the driver picked |
| Neither, and the **link** step fails (Homebrew LLVM specifically) | Export `LIBRARY_PATH="$SDK/usr/lib"` (or pass `-L`) — Homebrew clang passes the SDK it was built with to `ld -syslibroot` and ignores `-isysroot`/`SDKROOT` for linking ([#197277 upstream issue]) |

3. **Read `-Wmissing-sysroot` as the cause, not as noise.** The driver emits it
   and then continues without system headers, so the build dies later at the
   first `#include` with a message that names a header instead of the SDK. Treat
   the first warning line as the diagnosis and stop reading the header error.

4. **Verify the fix with a two-line probe before re-running the real build**, so
   a toolchain problem is never re-diagnosed as a code regression:

```sh
printf '#include <stdio.h>\nint main(){return 0;}\n' > probe.c
"$CC" -isysroot "$(xcrun --show-sdk-path)" probe.c -o probe && echo "sysroot ok"
```

5. **Pin the toolchain and its environment together.** The `SDKROOT`/`CPATH`
   exports belong in the same committed setup script as the compiler version
   ([platforms-toolchains-version-management]); an environment assembled by hand
   per machine reproduces this failure on the next clone.

## Edge cases

| Case | Then |
|------|------|
| Headers resolve but linking still fails on a Homebrew LLVM | That toolchain passes the SDK it was **built** with to `ld -syslibroot` and ignores `-isysroot`/`SDKROOT` for the link step (an open upstream issue). Supply the library path separately: `LIBRARY_PATH="$SDK/usr/lib"` or explicit `-L` |
| The compiler lives in a keg-only/unlinked prefix and `command -v` finds nothing | Call it by absolute path, or prepend its `bin` to `PATH` in the setup script; a tool absent from `PATH` makes a harness take its "tool not installed" branch and report an unrelated failure |
| `xcrun` itself errors | The active developer directory is unset or points at a removed install; fix with `xcode-select` before touching compiler flags |
| A subset of a test suite fails only on the compiled path | Reproduce the same failure on an unmodified checkout of the base branch first; when it reproduces there, it is an environment precondition, not a regression in the change under review |
| Apple's `/usr/bin/clang` works but Homebrew's does not | That differential is the signature of this problem: the Apple driver resolves the SDK via xcrun automatically; the Homebrew build trusts its baked-in path |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Hardcode `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk` (or a versioned SDK path) into a build script | Resolve it with `xcrun --show-sdk-path` at build time | The versioned directory disappears on the next toolchain update, and the compiler degrades to a warning rather than failing at the point of the missing SDK |
| Report "N tests fail on this branch" from a run whose compile step warned about a missing sysroot | Fix the sysroot, or reproduce on the base branch and report it as an environment precondition | The failures are one step removed from their cause and read as a code regression |
| Set only `CPATH` and treat the toolchain as configured | Set the sysroot too, and check the link step separately | `CPATH` adds include directories; it does not give the linker a library search root |

## Sources

- https://github.com/llvm/llvm-project/issues/137352 — as of LLVM/Clang 20.1.2 `clang hello.c` on macOS fails with `ld: library 'System' not found` and `'stdio.h' file not found`; "one must manually populate the `SDKROOT` environment variable (or pass `-isysroot`): `export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"`" — the driver selects no default sysroot on macOS
- https://github.com/Homebrew/homebrew-core/issues/197277 — Homebrew clang "always passes the same value to `ld`'s `-syslibroot`": "the SDK that `llvm` was built with is always selected when linking instead of the value set by `xcrun` / in `SDKROOT` / with `-isysroot`"; compilation respects `-isysroot` while the link step does not (labelled an upstream issue)
- https://clang.llvm.org/docs/UsersManual.html — clang honors `SDKROOT` as the default `isysroot` when set, and an explicit `-isysroot` on the command line takes precedence
- https://clang.llvm.org/docs/DiagnosticsReference.html — `-Wmissing-sysroot` exists and is enabled by default (a warning, not an error)
- Local reproduction 2026-08-05 (macOS, Homebrew LLVM at `/opt/homebrew/opt/llvm`): `clang probe.c` emitted `warning: no such sysroot directory: '/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk' [-Wmissing-sysroot]` followed by `fatal error: 'stdio.h' file not found`; the same command with `-isysroot "$(xcrun --show-sdk-path)"` (an Xcode SDK path) compiled and linked successfully. A 69-task test suite driven by the toolchain failed en masse with header errors; `clang probe.c` reproduced the identical error; `clang -isysroot "$(xcrun --show-sdk-path)" probe.c` succeeded
