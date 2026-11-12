---
id: mobile-cross-platform-adopting-expo-exact
domain: mobile
category: cross-platform
applies_to: [expo-exact, rust, ios, macos, web, linux, android, windows]
confidence: verified
sources:
  - https://github.com/expo/exact/blob/18b358e094d35d2a9faa49ac76458caf9b488ff9/README.md
  - https://github.com/expo/exact/blob/18b358e094d35d2a9faa49ac76458caf9b488ff9/AGENTS.md
  - https://github.com/expo/exact/blob/18b358e094d35d2a9faa49ac76458caf9b488ff9/docs/start-here.md
  - https://news.hada.io/topic?id=36991
last_verified: 2026-11-12
related:
  [
    mobile-cross-platform-agent-build-and-verify-loop-in-expo-exact,
    mobile-cross-platform-rust-rewrite-for-startup-and-memory,
    platforms-toolchains-version-management,
    mobile-release-staged-rollout-and-hotfix,
  ]
---

# Adopting Expo Exact for a new app

## When this applies

- You are choosing a stack for a new app and Expo's Exact (Contract UI language, a
  Rust runtime, TypeScript or Rust data code) is a candidate.
- You are starting an Exact app and need to fix which checkout it builds against and
  what it sends to Expo.

Exact was pre-1.0 at commit 18b358e (2026-11-12): no API stability, no backwards
compatibility, no migration guide, no releases, tags or npm package.

## Do this

Decide by the platforms you must ship and how the app changes after release.

| Case | Do |
|------|----|
| You ship on web, macOS, iOS or Linux, and you can rebuild when Exact changes | Exact fits: one `app.contract` runs on all four hosts with native controls (UIKit, AppKit, the browser's DOM) |
| You must ship to Google Play or distribute a Windows app | Choose another stack for now: Android builds, runs and is driven on emulators and phones, but delivery and store packaging do not exist; Windows control parity and delivery are unfinished |
| You need to ship TypeScript or Rust logic changes to installed apps without a store release | Choose another stack, or plan store releases for every logic change: signed delivery covers plans and assets, not TypeScript or Rust modules |
| You need camera access, grid/masonry virtualization, a general webview beyond `iframe`, or a devtools UI | Choose another stack: v1 leaves these out on purpose |
| The app's view logic needs loops, `await`, or I/O inside the UI layer | Put that work in a data source (`app.ts` or a Rust crate) and keep Contract declarative: Contract has no effects outside actions, no loops in actions, no `await` |

When Exact fits:

1. Pin the Exact checkout by commit. An app uses the checkout by path, so record the
   commit SHA you build against (in the app's README or a lock note) and move it on
   purpose. Run `bun exact.mjs update` after moving the checkout to see lock drift,
   and `bun exact.mjs lock` to refresh.
2. Install the pinned toolchain before the first build: rustup (the
   `rust-toolchain.toml` stable installs itself), Bun at the version `package.json`
   pins (1.4.2 at 18b358e), Chrome for the web agent, Xcode 27.1 or later for Apple
   hosts. Run `bun scripts/exact.mjs setup` once, then `setup --check`, which names
   what is missing without changing anything.
3. Set the feedback policy before the agent starts. Generated `AGENTS.md` tells the
   agent to record friction with `bun exact.mjs feedback note`; notes go to Expo when
   the project's answer is `always` or a yes to `ask` (the default). For a company or
   client project, run `bun exact.mjs feedback never` in the app, or export
   `EXACT_FEEDBACK=0` on the machine.
4. Start from the nearest pattern (`bun exact.mjs pattern`) and give the agent
   `docs/start-here.md` (`docs/start-here-site.md` for a website) as its only required
   reading; the long guides are lookup by section.
5. Build and verify with `mobile-cross-platform-agent-build-and-verify-loop-in-expo-exact`.

## Edge cases

| Case | Then |
|------|------|
| An agent finished the README's todo-app prompt in a stated time (57 minutes, or a faster run reported elsewhere) | Plan for first native builds of ten to fifteen minutes each on a laptop, then one to two minutes; the README's 57-minute run spent about 25 minutes on the first macOS and iOS builds with Cargo and Hermes caches warm |
| Several apps or worktrees share one Exact checkout | Each app has its own Cargo workspace that refers to the checkout by path; moving the checkout moves all of them, so pin per app or keep one checkout per pinned SHA |
| A guide or design comment cites `LLP <number>` | The LLP design record is a private repository; treat the citation as "a decision is recorded" and rely on the public `docs/` text |
| You need a permissive license for a commercial app | The workspace is MIT-licensed (`Cargo.toml`, `LICENSE`); check each optional add-on you pull in (`vendor/`, Snapback) separately |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Point an app at whatever Exact `main` is checked out today | Record the SHA and move it deliberately after reading the commits | Pre-1.0 Exact changes daily with no compatibility shims |
| Let an agent send feedback notes on a confidential project | Set `feedback never` or `EXACT_FEEDBACK=0` before the first agent run | Under the default `ask` policy a note leaves the machine after one yes |

## Sources

- expo/exact README at 18b358e: pre-1.0 note; "What works today, and what doesn't
  yet" (Android delivery and store packaging, Windows parity, production code updates,
  v1 omissions); Quick start tool versions; the 57-minute todo-app run; the
  Feedback section; MIT license.
- expo/exact `AGENTS.md` / `CLAUDE.md` at 18b358e: no releases, tags or npm package,
  app uses the checkout by path; feedback note required when building an app.
- expo/exact `docs/start-here.md` at 18b358e: `pattern`, `update`, `lock`,
  first-build timing.
- GeekNews topic 36991: announcement summary (pre-1.0, MIT, platform status).
