---
id: mobile-release-staged-rollout-and-hotfix
domain: mobile
category: release
applies_to: [ios, android, cross-platform]
confidence: verified
sources:
  - https://support.google.com/googleplay/android-developer/answer/6346149
  - https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases
  - https://developer.apple.com/distribute/app-review/
  - https://developer.android.com/guide/playcore/in-app-updates
  - https://firebase.google.com/docs/crashlytics
last_verified: 2026-07-10
related: [mobile-performance-startup-time]
---

# Staged Rollouts and Hotfix Paths for Store Releases

## When this applies

Planning a mobile app release, deciding rollout strategy, or a critical bug has
shipped and you need remediation options. Also when designing kill switches,
forced-update, or API compatibility policy for mobile clients.

## Do this

1. **A mobile release is not a deploy.** Store review takes hours-to-days, and users
   update on their own schedule — old versions stay live for months. Two standing
   consequences: the API must stay backward-compatible with every shipped app version
   (server contract discipline lives in the backend domain, `wiki/backend/`), and
   remediation must not depend on users updating.
2. Pick the path by situation:

| Situation | Do |
|-----------|----|
| Normal release | Staged rollout: Google Play staged rollout (you set the %, increase over time); App Store phased release (7 days: 1→2→5→10→20→50→100% of auto-updating users). Widen each step only after crash-rate and key metrics for the new version pass your gate |
| Critical bug found mid-rollout | Halt the rollout (Play: halt staged rollout; App Store: pause phased release, up to 30 days). Fix, resubmit; on iOS request an expedited review for the critical-bug fix (granted case-by-case, include repro steps). Turnaround is still hours-to-days — the halt limits blast radius while you wait |
| Risky feature about to ship | Put it behind a server-side feature flag / kill switch checked at runtime, so you can disable it remotely for all shipped versions without any release |
| Security or data-corruption bug in shipped versions | Forced update: app checks a server-provided minimum-supported-version at launch and blocks below it (Android: Play in-app updates immediate flow; iOS: blocking screen linking to the App Store). Reserve for these cases only |

3. **Design the forced-update check into v1.** Versions shipped without the check can
   never be forced — you cannot retrofit it onto binaries already on devices.
4. **Wire crash monitoring, segmented by app version, into the rollout decision**
   (e.g., Crashlytics per-version crash-free rate). Each widening step is a go/no-go
   gate on the new version's numbers, not a calendar event.

## Edge cases

| Case | Then |
|------|------|
| Rollout halted, but some users already have the bad version | Halting stops new deliveries only — users who got it keep it. The server-side kill switch is your only remote lever for them |
| iOS phased release percentages | They apply to automatic updates only — any user can still manually update from the App Store mid-phase; expect early adopters beyond the daily % |
| Feature-flag service unreachable at app launch | Default to the last-known flag values cached on device; first-ever launch defaults risky features to off |
| Removing an old API the app no longer calls | Measure per-app-version traffic first; remove only after usage from old versions decays below your threshold |
| Play staged rollout scope | Applies to updates, not the initial app release; halted rollouts can be resumed after a fix via a new release |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ship a risky change without a remote kill switch | Flag it server-side first, ship dark, enable remotely | The store round-trip (hours-to-days) is otherwise your only off-switch |
| Treat a bad release like a backend incident and "fix forward" | Halt the rollout, flip the kill switch, then fix and resubmit | You cannot force users onto the fixed version |
| Ship a breaking API change together with the app release | Deploy the backward-compatible server change first; release the app against it | Months of old app versions still call the old contract |
| Widen rollout on a schedule | Gate each step on per-version crash-free rate and startup metric ([mobile-performance-startup-time]) | The staged % exists to catch regressions before full exposure |

## Sources

- https://support.google.com/googleplay/android-developer/answer/6346149 — Play staged rollout: percentages, halt/resume
- https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases — phased release schedule, pause up to 30 days, manual updates bypass
- https://developer.apple.com/distribute/app-review/ — expedited review for critical bug fixes (include repro steps)
- https://developer.android.com/guide/playcore/in-app-updates — immediate (blocking) in-app update flow
- https://firebase.google.com/docs/crashlytics — per-version crash monitoring and crash-free metrics
