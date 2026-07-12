---
id: mobile-performance-startup-time
domain: mobile
category: performance
applies_to: [ios, android, cross-platform]
confidence: verified
sources:
  - https://developer.android.com/topic/performance/vitals/launch-time
  - https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time
last_verified: 2026-07-10
related: [mobile-release-staged-rollout-and-hotfix]
---

# App Cold-Start Time Budget

## When this applies

Cold start feels slow, the startup-time metric regressed between versions, or you
are reviewing what runs at app launch (Application/AppDelegate init, SDK setup).

## Do this

1. **Measure first, on a low-end real device, cold start** (process not in memory —
   kill it before measuring). Emulator and flagship-device numbers mislead: they hide
   the I/O and CPU costs your slowest users pay.

| Platform | Measure with |
|----------|--------------|
| Android | Logcat `Displayed` line (time to initial display), `reportFullyDrawn()` (time to full display), Perfetto app-startup trace, Macrobenchmark for automated runs. Android vitals flags cold start ≥ 5s as excessive |
| iOS | Xcode Instruments — App Launch template; profile the launch phases it reports |

2. **Budget everything before the first meaningful frame**: only work the first
   screen needs runs before it renders. Defer the rest:

| Work found at launch | Do |
|----------------------|----|
| SDK / analytics init | Lazy-init after the first frame renders, or on first use |
| Heavy dependency-injection graph | Create components lazily; build only the first screen's subgraph at launch |
| Disk or network reads for first-screen data | Render cached data first, refresh after the frame is up |
| Synchronous main-thread I/O (prefs, DB, file reads) | Move off the main thread — it delays the first frame directly |

3. **Keep an explicit allowlist of true launch dependencies** — things that must run
   before the first frame (crash reporter, the flag values gating the first screen).
   Everything not on the list initializes on first use. New SDKs default to lazy;
   adding one to the allowlist is a reviewed decision.
4. **Track startup as a release-gated metric per app version**, wired into the staged
   rollout go/no-go alongside crash rate ([mobile-release-staged-rollout-and-hotfix]) —
   startup regressions ship silently when nothing gates them.

## Edge cases

| Case | Then |
|------|------|
| Fast on your dev device, slow in field metrics | Gate on field data (Android vitals / your APM percentiles per device class), not on local runs; reproduce locally on a device matching your slow-user percentile |
| Crash reporter deferred with the other SDKs | Keep it on the launch allowlist — crashes that happen before it initializes are invisible |
| Splash screen used to cover slow init | A splash hides the delay without removing it, and the OS still measures the launch; cut the work, use the platform splash API only for the transition |
| Warm/hot starts measured as cold | Cold = process not in memory. Kill the process (`adb shell am kill` / terminate in Xcode) before each measured run, or the pass is measuring a warm start |
| Regression appears with no code change to launch path | Diff added/updated dependencies — SDK updates add launch-time work (content-provider/init hooks) without touching your code |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Initialize every SDK in `Application.onCreate` / AppDelegate init | Init-on-first-use, with an explicit allowlist of true launch dependencies | Each eager init taxes every launch for work most sessions never use |
| Prove startup is fine with an emulator or flagship run | Cold-start measurement on a low-end real device | Your slowest users' hardware is the number that drives uninstalls and vitals |
| Accept "it's only 50ms" additions to launch | Charge it against the pre-first-frame budget; defer it if the first screen doesn't need it | Launch decays by accretion — each addition passes review alone |

## Sources

- https://developer.android.com/topic/performance/vitals/launch-time — cold/warm/hot definitions, TTID/TTFD, Displayed/Perfetto/Macrobenchmark, lazy-init guidance, vitals thresholds
- https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time — Instruments App Launch profiling
