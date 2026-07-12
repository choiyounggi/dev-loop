---
id: mobile-networking-calls-on-mobile-networks
domain: mobile
category: networking
applies_to: [ios, android, cross-platform]
confidence: verified
sources:
  - https://developer.android.com/develop/connectivity/preserving-battery
  - https://developer.android.com/topic/libraries/architecture/workmanager
  - https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler
  - https://developer.apple.com/documentation/foundation/urlsessionconfiguration/waitsforconnectivity
last_verified: 2026-07-10
related: [backend-common-reliability-timeouts-and-retries, mobile-offline-offline-first-sync]
---

# API Calls over Mobile Networks

## When this applies

Implementing any network call in a mobile app, or handling field reports of hangs,
battery drain, or timeouts that do not reproduce on office wifi.

## Do this

1. **Assume the network drops mid-request routinely** — elevator, subway, wifi↔cell
   handoff. Every call gets an explicit timeout and a defined failure UI state with a
   retry affordance. An infinite spinner is a missing state, not a loading state.
2. **Retry policy: inherit the server-side rules, add the mobile lever.** Base policy
   (retry idempotent operations only, capped exponential backoff with jitter, respect
   the deadline) is [backend-common-reliability-timeouts-and-retries]. On mobile, add:
   while the device is offline, retry on the connectivity-restored signal instead of
   blind timers — Android `NetworkCallback` / WorkManager `NetworkType.CONNECTED`
   constraint; iOS `URLSessionConfiguration.waitsForConnectivity` / `NWPathMonitor`.
   Timer-based retries against a dead radio burn battery and never succeed early.
3. **Batch by who initiated the request** — each cellular radio wake-up costs battery
   (the radio stays in a high-power state after every transfer):

| Request type | Do |
|--------------|----|
| User-initiated (tap, pull-to-refresh, form submit) | Send immediately — latency is the priority |
| Background sync, analytics, log upload | Coalesce into batches and schedule via the OS: Android WorkManager, iOS BGTaskScheduler — the OS aligns work with radio wake-ups and charging |
| Prefetch | Piggyback onto an already-scheduled batch or a user-initiated wake — never a wake-up of its own |

4. **Budget payloads for the slow tail.** Mobile networks have long tail latencies:
   paginate lists, enable response compression, and request sparse fields (only the
   fields the screen renders) where the API supports field selection.
5. **Test under degraded conditions before shipping**: toggle airplane mode
   mid-request and assert the failure state renders with retry; run the core flows
   under a throttled profile (iOS Network Link Conditioner "3G"; Android emulator
   network speed/latency settings).

## Edge cases

| Case | Then |
|------|------|
| Request in flight when the app is backgrounded | Expect suspension/process death mid-request: make the operation resumable — route user writes through the outbox in [mobile-offline-offline-first-sync] |
| Large upload/download | Use OS background transfer (iOS `URLSession` background session; Android WorkManager) so the transfer survives app suspension and process death |
| Wifi connected but no internet (captive portal) | Reachability says "connected" — treat the request timeout as the real signal and show the failure state; connectivity signals gate retries, they do not guarantee success |
| Server responds slowly but successfully after client timeout | The action may have been applied server-side — retry only with an idempotency key (policy in [backend-common-reliability-timeouts-and-retries]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Treat the office-wifi happy path as the baseline and add error handling later | Build timeout, retry, and offline UI states first, then the happy path | The field default is degraded; unbuilt states surface as hangs and 1-star reviews |
| Poll on a fixed timer while offline | Subscribe to connectivity-restored and retry then | Dead-radio retries drain battery and delay recovery to the next tick |
| Fire each analytics event as its own request | Queue and flush in scheduled batches | Every unbatched request is a radio wake-up |
| Ship after testing only on wifi | Airplane-mode-mid-request + throttled-3G pass on core flows | Drop-mid-request bugs never reproduce on stable wifi |

## Sources

- https://developer.android.com/develop/connectivity/preserving-battery — radio state machine, minimizing transfer impact, update-type categories
- https://developer.android.com/topic/libraries/architecture/workmanager — network-constrained, batched background work with backoff
- https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler — iOS deferrable background task scheduling
- https://developer.apple.com/documentation/foundation/urlsessionconfiguration/waitsforconnectivity — wait-for-connectivity instead of immediate failure
