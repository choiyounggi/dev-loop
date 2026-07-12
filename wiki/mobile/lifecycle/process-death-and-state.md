---
id: mobile-lifecycle-process-death-and-state
domain: mobile
category: lifecycle
applies_to: [ios, android, cross-platform]
confidence: verified
sources:
  - https://developer.android.com/guide/components/activities/activity-lifecycle
  - https://developer.android.com/topic/libraries/architecture/saving-states
  - https://developer.apple.com/documentation/uikit/restoring-your-app-s-state
  - https://developer.android.com/privacy-and-security/keystore
  - https://developer.apple.com/documentation/security/keychain-services
last_verified: 2026-07-10
related: [mobile-offline-offline-first-sync]
---

# Surviving OS Process Death with User State Intact

## When this applies

Building any screen that holds in-progress user state — forms, multi-step wizards,
media playback position, selections — or investigating a report like "the app lost
my data when I switched apps / took a call / came back later".

## Do this

1. **Design for resurrection, not for staying alive.** The OS kills backgrounded app
   processes to reclaim memory at any time, and it kills the *process*, not the
   screen — no lifecycle callback (`onDestroy`, `applicationWillTerminate`) is
   guaranteed to run first. Treat every backgrounding as a potential kill.
2. Route each kind of state to its survival mechanism:

| State | Do |
|-------|----|
| Transient UI state — scroll position, selected tab, checked items, in-progress form field values, media position | Saved-state mechanism: Android `SavedStateHandle` / `onSaveInstanceState` / `rememberSaveable`; iOS state restoration (`NSUserActivity` / UIKit state restoration). Store only primitives and small strings — saved-state bundles are size- and serialization-speed-limited |
| Durable user data — draft content the user is composing | Persist to local storage (DB/file) **as the user types** (debounced autosave on each change). A kill delivers no exit callback, so save-on-exit loses the draft |
| Session / auth tokens | OS secure storage: iOS Keychain, Android Keystore-backed storage. Read at launch. A memory-only token turns every process kill into a logout |
| Refetchable server data | Refetch on restore, or serve from the local store — do not put it in the saved-state bundle |

3. **Test by actually killing the process.** A state bug you cannot reproduce is one
   you have not forced yet:

| Platform | Force process death |
|----------|---------------------|
| Android | Developer options → "Don't keep activities"; or background the app, then `adb shell am kill <package>` |
| iOS | Background the app in the Simulator, then terminate it (stop in Xcode / `xcrun simctl terminate`), then relaunch from the home screen |

   Then re-enter the screen and assert every item from the state table above survived.
4. **Deep link and notification entries rebuild full state.** The user can enter
   mid-flow with a cold process: the target screen must construct its complete
   expected state (loaded entity, back stack / parent context) from the entry
   parameters plus local storage — never from state assumed left over in memory.

## Edge cases

| Case | Then |
|------|------|
| Saved-state payload too large (Android `TransactionTooLargeException`) | Put an id/key in the saved-state bundle and the payload in local storage keyed by it |
| State survives rotation but not "return hours later" | ViewModel/in-memory state covers configuration changes only; process death needs the saved-state mechanism — wire `SavedStateHandle` (or iOS restoration) in addition |
| User force-quits (swipes the app away) | Same design covers it: autosaved drafts and keychain/keystore sessions survive; saved-state restoration behavior differs by platform, so durable data must not depend on it |
| Media/reading position (state changes without discrete input events) | Persist on an interval and on pause/background events, in addition to saved state |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Save the draft in `onDestroy` / `applicationWillTerminate` | Debounced autosave on each change | Those callbacks are skipped on process death |
| Keep the auth token only in a memory singleton | Keychain/Keystore-backed storage, loaded at launch | Every background kill becomes a logout |
| Close a "lost my data" bug as cannot-reproduce | Force a kill (adb / simulator terminate) and re-enter the screen | Process death rarely happens in a dev loop unless forced |
| Pass a full object graph through the deep-link entry assuming the app is warm | Pass ids; reload the entity and rebuild parent state on entry | Cold-process entry has no prior in-memory state |

## Sources

- https://developer.android.com/guide/components/activities/activity-lifecycle — system kills the process, not the activity; no guaranteed callback
- https://developer.android.com/topic/libraries/architecture/saving-states — SavedStateHandle, saved-state size limits, transient vs durable split
- https://developer.apple.com/documentation/uikit/restoring-your-app-s-state — iOS state restoration APIs
- https://developer.android.com/privacy-and-security/keystore — Android secure key/credential storage
- https://developer.apple.com/documentation/security/keychain-services — iOS secure storage for tokens/secrets
