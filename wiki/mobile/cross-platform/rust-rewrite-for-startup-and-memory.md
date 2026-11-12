---
id: mobile-cross-platform-rust-rewrite-for-startup-and-memory
domain: mobile
category: cross-platform
applies_to: [rust, electron, react-native, desktop, ios, android]
confidence: verified
sources:
  - https://www.it-connect.tech/discord-drops-electron-for-a-rust-rewrite-290-mb-ram-with-two-active-accounts/
  - https://x.com/svishnevskiy/status/2118081920194203799
  - https://github.com/expo/exact/blob/18b358e094d35d2a9faa49ac76458caf9b488ff9/README.md
  - https://news.hada.io/topic?id=36991
last_verified: 2026-11-12
related:
  [
    mobile-performance-startup-time,
    mobile-cross-platform-adopting-expo-exact,
    backend-common-llm-vendor-benchmark-claims-for-an-llm-tool,
    qa-deliverables-quantitative-claims-in-a-published-document,
  ]
---

# Rewriting a desktop or mobile client in Rust for startup time and memory

## When this applies

- You are deciding whether to rebuild a desktop or mobile client in Rust (or on a
  Rust-based UI framework such as GPUI or Expo Exact) to make it start faster or use
  less memory.
- The argument for it is a vendor's number ("290 MB instead of over 1 GB", "smoother
  than SwiftUI") rather than a measurement of your own client.

## Do this

1. Measure your own client first, under the workload you care about: cold start to
   first usable frame, and resident memory summed over every process the app spawns
   (an Electron app runs a browser, GPU and renderer process tree). Use the tools in
   `mobile-performance-startup-time` for mobile.
2. Split the cost into three buckets: the embedded runtime (browser engine, webview,
   JavaScript VM), work your code does before the first frame, and your steady-state
   app data. Then pick the row below for the largest bucket.

| Largest cost | Do |
|--------------|----|
| An embedded browser engine or JS runtime (Electron, CEF, a React Native JS bundle executed at launch) | The gain comes from removing that runtime, so compare every option that removes it: a native toolkit per platform, a Rust UI framework (Discord chose GPUI to replace Electron), or a plan/bytecode precompiled at build time (Exact runs no app JavaScript before the first pixel). Choose among them by the platforms you must ship |
| Work your own code does before the first frame (SDK init, sync, parsing) | Defer it past the first frame and bake constant data at build time; this works in any language, and a Rust rewrite that keeps the same launch work keeps the same delay |
| Steady-state app data (caches, message history, images) in a client that is already native (Swift, Kotlin) | Profile and bound the data structures; a language change keeps the same data and the same growth |
| Sharing logic between desktop and mobile is the goal | Put the shared logic in a Rust core and keep a native UI on each platform, as Discord announced for mobile |

3. Before committing, build one real screen on the candidate stack and measure it with
   the same method as step 1. Compare like with like: same accounts, same data, same OS.

## Edge cases

| Case | Then |
|------|------|
| The rewrite still needs web content (embeds, a video player, mini-apps) | Count the remaining webview: Discord keeps the system webview for YouTube and Activities, so its cost returns whenever those open |
| The vendor figure comes from one screenshot or a short video | Record its conditions next to the number: Discord's 290.2 MB is one Windows Task Manager screenshot of a first build with two accounts connected, with no CPU or benchmark data published |
| A claim compares the framework with a platform toolkit ("smoother than SwiftUI") | Find the published comparison before repeating it. Exact's README at 18b358e publishes one web comparison (RealWorld Conduit vs React 19 SSR: ready about 300 ms sooner, 26 KB vs 81 KB of code) and no SwiftUI comparison |
| The target framework is pre-1.0 or lacks a platform you ship | Decide with `mobile-cross-platform-adopting-expo-exact` (Exact) or the framework's own support matrix before any performance argument |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Promise a memory or startup gain because "Rust is faster" | State the bucket you measured and the runtime the rewrite removes | The large published gains come from dropping a browser runtime and launch-time JavaScript, which other stacks can drop too |
| Copy a vendor's RAM figure into a plan as the expected result | Measure your own client before and after one prototype screen | A figure taken under other accounts, data and OS predicts nothing about yours |

## Sources

- IT-Connect, 2026-11-06: Discord replaces Electron on desktop and React Native on
  mobile; desktop UI on GPUI; mobile keeps a native interface and shares app code
  through Rust; the system webview stays for YouTube and Activities; 290.2 MB in one
  Task Manager screenshot with two accounts; no CPU or benchmark figures; no release
  date. Primary post: Discord CTO Stanislav Vishnevskiy on X, 2026-11-04 (linked
  above; read through the IT-Connect report).
- expo/exact README at 18b358e, "Speed is king": the boot path executes and compiles
  nothing, TypeScript is compiled to Hermes bytecode at build time and loads after the
  first pixel, the first frame comes from data baked into the plan; the Conduit
  comparison figures.
- GeekNews topic 36991 (2026-11): summary of the Exact announcement and the Hacker News
  discussion.
