---
id: platforms-processes-parsing-cli-structured-output
domain: platforms
category: processes
applies_to: [macos, linux, general]
confidence: field-tested
sources:
  - https://man7.org/linux/man-pages/man1/jq.1.html
last_verified: 2026-08-04
related: [platforms-processes-non-interactive-cli-invocation, backend-common-integrations-externally-owned-defaults, platforms-processes-cloud-cli-invocation-bounds]
---

# Parsing Another Tool's `--json` Output From Automation

## When this applies

You are about to write automation that parses another CLI or tool's structured
output — field names, nesting depth, `--json`/`--format json` — to wrap a desktop
app's CLI, an orchestrator, or a cloud tool. You have the tool's prose docs but
have not seen its actual output for the verbs you will call.

## Do this

1. **Confirm every field path against real output before writing the parser.**
   Run the tool's **read-only** verbs — `list`, `status`, `show`, `ps`,
   `describe` — and read the JSON they emit. Build extraction only on paths you
   have observed in that output (`.result.startupTerminal.handle`, not a guessed
   `.handle`). Guessed field names produce code that looks correct and silently
   never matches.

2. **Get the schema from a read-only verb, never a state-mutating one.** A read
   verb returns the same object shape as `create`/`spawn`/`apply` without the side
   effect, so you can inspect the schema safely and repeatedly. Reserve the
   mutating verb for the one real run the automation performs.

3. **Pin a captured sample as a test fixture and parse the fixture, not the live
   tool.** Save one real JSON response to a file and write the parser's unit tests
   against it, so the parser is testable in CI with the tool absent and with zero
   live invocations. Re-capture the fixture when you upgrade the tool.

4. **Select fields with a tool that fails loudly on a missing path.** Pipe through
   `jq` with the exact path; a typo or a moved field yields `null` or a nonzero
   exit you can assert on, rather than an empty string that reads as "no data".

## Edge cases

| Case | Then |
|------|------|
| The tool has no read-only verb exposing the object | Run the mutating verb once against a throwaway target, capture its JSON as the fixture, then clean up — capture cost is one controlled run, not every test |
| Field is present only under some states (e.g. `handle` only when live) | Capture fixtures for each state and branch on a presence check, not on the field's truthiness |
| Output shape differs between tool versions | Record the tool version alongside the fixture; re-capture on upgrade (this is [platforms-toolchains-version-management] territory for pinning the version) |
| The call itself may hang or prompt before you get output | Make it non-interactive first — [platforms-processes-non-interactive-cli-invocation] owns stdin/timeout; this page assumes output already arrives |
| `jq` is absent on the target | Ship it as a pinned dependency, or parse in the host language against the same captured fixture |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Infer field paths from the tool's prose docs or from memory | Run a read-only verb and read the actual JSON | Docs lag and omit nesting; guessed paths compile but never match, and the failure is silent |
| Verify your parser by running the live `create`/`spawn` verb | Capture one sample and unit-test against the fixture | Mutating verbs have side effects and can't run in CI; a fixture makes the parser deterministically testable |

## Sources

- https://man7.org/linux/man-pages/man1/jq.1.html — `jq` filters by explicit path; a missing key yields `null`, and `-e`/`--exit-status` sets a nonzero exit when the result is null/false, giving a loud failure on a wrong path
- Field context (2026-08): building `orca-spawn.sh` / `orca-worktree-alive.sh` against the orca CLI — its read-only `terminal list` and `worktree ps --json` verbs exposed `handle`, `liveTerminalCount`, and `hasAttachedPty`, letting both wrappers be built and CI-tested against canned JSON with zero live spawns and no guessed field names
