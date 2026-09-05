---
id: testing-strategy-executable-target-tests-in-swiftpm
domain: testing
category: strategy
applies_to: [swift, swiftpm, xctest]
confidence: verified
sources:
  - https://github.com/swiftlang/swift-package-manager/blob/main/CHANGELOG.md
  - https://github.com/swiftlang/swift-evolution/blob/main/proposals/0294-package-executable-targets.md
  - https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/LanguageGuide/AccessControl.md
  - https://github.com/swiftlang/swift-package-manager/blob/main/Sources/SPMBuildCore/BuildParameters/BuildParameters%2BTesting.swift
  - https://github.com/swiftlang/swift-package-manager/issues/6367
  - https://forums.swift.org/t/executable-target-testability/52351
last_verified: 2026-09-06
related: [testing-strategy-test-level-choice, testing-quality-minimum-case-set]
---

# Unit Tests for the Internals of a SwiftPM Executable Target

## When this applies

A SwiftPM package has an `.executableTarget` (a macOS app or CLI built without
an Xcode project) whose internal types — layout math, formatters, parsers —
need XCTest coverage, and you are about to drop the tests or split the code
into a library target because "an executable target cannot be imported by a
test target".

## Do this

1. **Depend on the executable target from the test target and `@testable
   import` it.** SwiftPM links the executable "as if it were a library": every
   symbol except the entry point is visible to the tests. This is available to
   packages whose `swift-tools-version` is `5.5` or newer.

```swift
// Package.swift
.executableTarget(name: "DeskBat", path: "Sources/DeskBat"),
.testTarget(name: "DeskBatTests", dependencies: ["DeskBat"]),
```

```swift
import XCTest
@testable import DeskBat   // internal types are visible
```

2. **Run with `swift test` and no extra flags.** `@testable import` requires
   the imported module to be compiled with testing enabled; `swift test` builds
   the debug configuration and SwiftPM enables testability whenever the
   configuration is debug (`explicitlyEnabledTestability ?? (configuration ==
   .debug)`).

| Case | Do |
|------|----|
| `swift test` on macOS or Linux, tools-version ≥ 5.5 | The two-line manifest change above; write the tests against the internal API directly |
| `swift-tools-version` below 5.5 | Raise it to `5.5` (or later) in `Package.swift` — `.executableTarget` itself needs 5.4 — then apply the row above |
| `swift test` on Windows and the executable uses a `@main` type | The link step fails with `lld-link: error: duplicate symbol: main` (swift-package-manager#6367, closed); extract the code under test into a library target for that platform's CI while keeping the direct dependency for macOS/Linux |
| The same code is consumed by two or more executables, or must ship as a `.library` product | Extract a library target and make each executable a thin wrapper — the split is justified by reuse, not by testability |
| `@testable import` fails with "module was not compiled for testing" under an Xcode scheme | Turn on the scheme's `ENABLE_TESTABILITY` for the configuration the tests build with; the executable-target dependency is not the fault |
| Running tests in release configuration | Pass testability explicitly, or drop `@testable` and test through public API — `swift test --disable-testable-imports` exists for the latter |

3. **Keep the entry point out of the test surface.** Top-level code in
   `main.swift` or the `@main` type's `main()` is the one part SwiftPM
   excludes; test the functions it calls, and test the built binary itself as
   a subprocess when the launch path matters ([testing-strategy-test-level-choice]).

## Edge cases

| Case | Then |
|------|------|
| The executable uses `main.swift` rather than a `@main` type | Same manifest; only the entry point is excluded in both forms |
| Tests must also run against the shipped binary's behavior (flags, exit codes) | Add a second test that launches the built product as a `Process` — the direct import covers the internals, the subprocess covers the launch contract |
| A pre-5.5 toolchain produced "undefined symbol" link errors for this setup | That is the pre-feature behavior the forum thread records; upgrade the toolchain and the tools-version together |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Skip unit tests for an executable target's logic | Add the executable target to `testTarget.dependencies` and `@testable import` it | Supported since tools-version 5.5 (SwiftPM CHANGELOG `#3316`); `swift test` enables testability for debug builds on its own |
| Split a library target out of the executable only to make it testable | Split only when the code has a second consumer or must be a library product | The split adds a module boundary and public API surface for no test benefit |
| Pass `-enable-testing` by hand in `unsafeFlags` | Run `swift test` as is | Debug configuration already enables testability; `unsafeFlags` blocks the package from being consumed as a dependency |

## Sources

- https://github.com/swiftlang/swift-package-manager/blob/main/CHANGELOG.md — Swift 5.5, `#3316`: "Test targets can now link against executable targets as if they were libraries, so that they can test any data structures or algorithms in them. All the code in the executable except for the main entry point itself is available to the unit test … This feature is available to tests defined in packages that have a tools version of `5.5` or newer"; `#4119`: `--disable-testable-imports` builds tests "without the testability feature"
- https://github.com/swiftlang/swift-evolution/blob/main/proposals/0294-package-executable-targets.md — SE-0294 `.executableTarget`, "Implemented (Swift 5.4)"
- https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/LanguageGuide/AccessControl.md — "a unit test target can access any internal entity, if you mark the import declaration for a product module with the `@testable` attribute and compile that product module with testing enabled"
- https://github.com/swiftlang/swift-package-manager/blob/main/Sources/SPMBuildCore/BuildParameters/BuildParameters%2BTesting.swift — `enableTestability` resolves to `explicitlyEnabledTestability ?? (self.configuration == .debug)`
- https://github.com/swiftlang/swift-package-manager/issues/6367 — "Running `swift test` works on macOS and Linux. Running `swift test` on Windows fails" with `lld-link: error: duplicate symbol: main`
- https://forums.swift.org/t/executable-target-testability/52351 — pre-5.5 "undefined symbol" link failures for this setup; with Swift 5.5 / Xcode 13 the executable target is testable
- Field evidence 2026-08-18 (desk-bat, macOS SpriteKit app as a single `.executableTarget`): adding `.testTarget(name: "DeskBatTests", dependencies: ["DeskBat"])` and `@testable import DeskBat` made `swift test` run 49/49 green, including tests of `OverlayWindow.bottomLeftFrame` and `HistoryFormatter` inside the executable target
