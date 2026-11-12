---
id: mobile-cross-platform-agent-build-and-verify-loop-in-expo-exact
domain: mobile
category: cross-platform
applies_to: [expo-exact, ios, macos, web, linux]
confidence: verified
sources:
  - https://github.com/expo/exact/blob/18b358e094d35d2a9faa49ac76458caf9b488ff9/README.md
  - https://github.com/expo/exact/blob/18b358e094d35d2a9faa49ac76458caf9b488ff9/docs/start-here.md
  - https://github.com/expo/exact/blob/18b358e094d35d2a9faa49ac76458caf9b488ff9/docs/testing.md
  - https://github.com/expo/exact/blob/18b358e094d35d2a9faa49ac76458caf9b488ff9/docs/agent-pitfalls.md
last_verified: 2026-11-12
related:
  [
    mobile-cross-platform-adopting-expo-exact,
    testing-async-async-testing,
    qa-process-completion-claims,
  ]
---

# Building and verifying an Expo Exact app with a coding agent

## When this applies

- A coding agent (or you) is writing an Exact app: `app.contract` for the view,
  `app.ts` or a Rust crate for data, `*.test.contract` for tests.
- You are deciding how the agent proves a screen works on web, macOS, iOS or Linux,
  or a drive/test is flaky, stale, or passes while the screen looks wrong.

## Do this

| Step | Do |
|------|----|
| Compile gate | Run `bun exact.mjs contract build app.contract --json --errors-only`; `[]` with exit 0 means no errors. It also rewrites the `app.contract.d.ts` that `app.ts` imports and type-checks it |
| Name every control | Give each control a `testId` and key every `for` (`key=t.id`); drives, tests and accessibility tools address controls by `testId` |
| Keep data in sources | Change data only through `mutation`/`send` to a source and `refreshes <resource>`; the view never edits a list itself |
| Leave presentation to the platform | Write structure (header heading and buttons, `tablist`, `buttonStyle="filled"` on the main action) and omit colour, font and size on platform controls; paint on a `button` or field turns it into your own box |
| Test | Write `app.test.contract` with `expect`, `tap`, `type`; run it with `bun exact.mjs test web` during the loop; `verify <host>` runs the same file unchanged on another host |
| Wait | Use the agent's clock: `clock settle` for what is in flight, `clock +<ms>` past an animation, `clock until state <path> == <literal> within <ms>` for state a protocol reaches later |
| Done | Run `bun exact.mjs verify` when features work, and `verify ios` once at the end for a phone app; it runs the tests, checks first and final screens in light and dark, at two widths and the largest text size. A clean run on the app's platform is done |
| Look | Open every screenshot the run produced; to compare with a design, `"screenshot .exact/home.png compare ref/home.png"` reports node-by-node differences in text |

Start each first native build (`bun exact.mjs ios --prebuild`, ten to fifteen
minutes) once, in the background with a completion notification, and keep working on
the web loop (about 0.1 s per edit) while it runs.

## Edge cases

| Case | Then |
|------|------|
| A screenshot right after a state change shows the old value | The transition is held by the driver's clock; add `clock settle` or `clock +N` before `screenshot` |
| Records the app writes during a drive are dated 2026-01-01 | The driver's clock starts at a fixed epoch; pass `--epoch now` (`epoch now` in a test file) to any drive or test that talks to a real service |
| A test asserts the loading state against a live backend | It races the real reply; assert loading against a stand-in server that answers late, and use `fail fetch` for the error state |
| The driver refuses to drive and names a rebuild after you added a helper script | Files in the app folder count as build inputs; keep drive scripts, evidence and logs in `.exact/`, and committed helpers that the app never reads in `tools/` |
| Two worktrees build the same app for iOS | They share a bundle id and can reuse each other's simulator; create one simulator per worktree with `xcrun simctl create` and set `EXACT_SIM=<udid>` for its builds, tests, verify and agent runs |
| The agent taps the simulator by screen coordinates (`axe tap -x -y`) | Give the control a `testId` and drive with `bun exact.mjs agent ios tree "tap <testId>"`; find targets with `tree` or `tree --ax` |
| A test passes but the layout spills off the screen | Fix the layout from the `verify` screen report; a passing `expect` checks text and tree, not overflow |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `sleep` or a fixed wait before an assertion | Use `clock settle` or `clock until state … within <ms>` | Nothing moves between two operations; the clock belongs to the agent, so a real-time wait adds flakes and time |
| Report the app done because `test` passed on the web | Run `verify` on the app's own platform and read its screens | `verify` adds dark mode, widths, largest text size and native touch checks that `test` skips |
| Run `contract build` before `verify`/`test`/`agent` | Run `verify`, `test` or `agent` directly | They compile, build and serve their own copy and report compile errors the same way |

## Sources

- expo/exact README at 18b358e: the ten agent operations (`tree · screenshot · tap ·
  type · state · layout · logs · clock · prefer · perf`), "The clock belongs to the
  agent", tests as scripts of operations, "Look at every screenshot, not just the
  test result", the todo app example with `testId`, keyed `for` and mutations.
- expo/exact `docs/start-here.md` at 18b358e: "The workflow" table (`contract build
  --json --errors-only`, `verify`, `agent`), screenshot compare, `.exact/` and
  `tools/`, "Pitfalls that cost the most" (styling platform controls).
- expo/exact `docs/testing.md` at 18b358e, "Waiting": `clock settle`, `clock data`,
  `clock until state … within`.
- expo/exact `docs/agent-pitfalls.md` at 18b358e, "Driving and testing": transition
  screenshots, fixed epoch and `--epoch now`, loading-state races, drive scripts making
  the build stale, simulators shared across worktrees, coordinate taps.
