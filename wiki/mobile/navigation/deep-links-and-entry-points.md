---
id: mobile-navigation-deep-links-and-entry-points
domain: mobile
category: navigation
applies_to: [ios, android, cross-platform]
confidence: field-tested
sources:
  - https://developer.android.com/training/app-links/verify-android-applinks
  - https://developer.android.com/training/app-links/deep-linking
  - https://developer.android.com/guide/navigation/design/deep-link
  - https://developer.apple.com/documentation/xcode/supporting-associated-domains
  - https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content
last_verified: 2026-07-10
related: [mobile-lifecycle-process-death-and-state]
---

# Deep Links, Push Taps, and Multi-Entry-Point Routing

## When this applies

Implementing deep links / universal links / app links or push-notification tap
routing; links open the browser (or a disambiguation chooser) instead of the app;
deep-linked screens crash or strand users on cold start; pressing back from a
deep-linked screen exits the app.

## Do this

1. **Every link/push-reachable screen builds its own state on a cold process.**
   An app has many entry points — launcher, deep link, push tap, share sheet, app
   switcher — and a link can be the *first* thing that runs. The target screen
   executes parse → validate → load-or-fetch → render from the link parameters
   alone. Never read a global (current session, cart, selected entity) that an
   earlier screen populates — on a cold entry that screen never ran, and the null
   it left behind is the classic deep-link crash. Cold-process state mechanics:
   [mobile-lifecycle-process-death-and-state].
2. **Verified links — the file on the domain is what opens the app directly:**

| Platform | Do |
|----------|----|
| iOS universal links | Add the associated-domains entitlement in the app, and serve `apple-app-site-association` over HTTPS at `https://<domain>/.well-known/apple-app-site-association` listing the app ID and paths |
| Android app links | Add an intent filter with `android:autoVerify="true"`, and serve `assetlinks.json` at `https://<domain>/.well-known/assetlinks.json` listing the package name and every signing-cert fingerprint (including the Play App Signing cert) |

3. **Verification failures are silent** — the OS says nothing; links just open the
   browser (Android falls back to a chooser). Test on a physical device with the
   association files live on the real domain, not only via `adb`/Xcode direct launch.
4. **Synthesize the back stack.** A deep-linked detail screen gets its natural
   parent as the back destination, defined per target — not an empty stack that
   exits the app on back. Use the framework mechanism: Android
   `TaskStackBuilder`/`NavDeepLinkBuilder` (Navigation component inserts the graph's
   parent chain); on iOS, push the parent onto the navigation stack before the target.
5. **Auth-gated targets: preserve, authenticate, continue.** When a link points at
   a protected screen and the user is logged out: store the destination, run the
   auth flow, then navigate to the stored destination. Dropping the destination
   after login is the classic lost-intent bug.
6. **Invalid or expired payloads get a designed fallback screen** (deleted item,
   revoked invite): explain what happened and offer a next step. A crash or a
   silent redirect to home are both routing bugs.
7. **Push-notification taps go through the same routing layer as links** — one
   parse/validate/route contract for both, so every rule above applies to push
   payloads automatically.

## Edge cases

| Case | Then |
|------|------|
| assetlinks.json / AASA updated but a device still opens the browser | Verification results are fetched around install time and cached — reinstall the app or force re-verification (`adb shell pm verify-app-links`) before concluding the file is wrong |
| Android chooser still appears after setup | Verification failed: check `assetlinks.json` for the missing signing-cert fingerprint (Play App Signing uses a different cert than your upload key) and check the file is served as JSON over HTTPS without redirects |
| Universal link opens Safari for one user | The user previously chose "open in browser" (long-press to restore), or the AASA file was unreachable at install — re-test with the file live |
| Link arrives while the app is warm on another screen | Route it through the same routing layer; a separate warm-state shortcut path diverges from the cold path and hides cold-start bugs |
| Push payload carries a full object | Send ids only; the target screen fetches the entity — a stale serialized object bypasses validate/load and breaks on schema change |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assume in-memory state (session, cart, parent screen data) at a deep-link target | Rebuild from the link parameters: parse → validate → load-or-fetch → render | On a cold process, no earlier screen ran to populate it |
| Test deep links only against a warm, already-running app | Kill the process and cold-start every link target from the link itself | Warm tests never exercise the state-rebuild path users hit |
| Open a deep-linked detail screen on an empty back stack | Define a per-target parent and synthesize it (TaskStackBuilder / nav-graph parent chain) | Back exiting the app strands the user after one screen |
| Send a logged-out user to login and forget the link | Store the destination, authenticate, then continue to it | Losing the destination silently discards the user's intent |
| Handle push taps in a separate ad-hoc handler | Route push payloads through the deep-link routing layer | Two routing contracts drift; push inherits none of the link fixes |

## Sources

- https://developer.android.com/training/app-links/verify-android-applinks — autoVerify intent filters, assetlinks.json at the well-known path, verification states and re-verification commands
- https://developer.android.com/training/app-links/deep-linking — intent-filter deep links, reading data from the incoming intent
- https://developer.android.com/guide/navigation/design/deep-link — synthesized back stack for deep-linked destinations, TaskStackBuilder / NavDeepLinkBuilder
- https://developer.apple.com/documentation/xcode/supporting-associated-domains — associated-domains entitlement + apple-app-site-association over HTTPS
- https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content — universal links setup
