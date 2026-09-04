---
id: debugging-methodology-silent-registration-failure-in-a-finder-launched-app
domain: debugging
category: methodology
applies_to: [macos]
confidence: field-tested
sources:
  - https://raw.githubusercontent.com/phracker/MacOSX-SDKs/master/MacOSX10.13.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/CarbonEventsCore.h
  - https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:)
  - https://github.com/Hammerspoon/hammerspoon/issues/1261
last_verified: 2026-09-03
related: [debugging-methodology-hypothesis-testing, debugging-methodology-probe-path-vs-operation-path, platforms-processes-background-services]
---

# Diagnosing a Silent OS-Level Registration Failure in a Finder-Launched App

## When this applies

A macOS app registers something with the OS at launch — a global hotkey through
`RegisterEventHotKey`, or another OS-level registration — and it "silently" stops
responding while the app itself runs normally, especially when the app was launched
from Finder or in the background, so no terminal shows its stderr.

## Do this

1. Probe liveness before restarting anything. Send a synthetic input that the
   registered handler must react to — `osascript -e 'tell application "System
   Events" to key code N'` for a hotkey — and observe an independently readable side
   effect, such as a window's `kCGWindowIsOnscreen` value from
   `CGWindowListCopyWindowInfo`, before and after. A toggle proves the handler is
   alive; no change proves it is dead, without guessing and without losing the
   running instance's state.
2. When the probe shows the handler dead, relaunch from a terminal where stderr is
   visible and read the registration error there. A Finder launch discards stderr,
   so a launch-time registration failure leaves no trace while the app appears to
   run normally.
3. Read `RegisterEventHotKey`'s failure by what the header documents:

| Result | Meaning |
|--------|---------|
| `eventHotKeyExistsErr` (-9878) without `kEventHotKeyExclusive` | This process already holds a registration for that hotkey — a duplicate init or a relaunch path that registers twice; registering the same combination from two different processes is not an error |
| `eventHotKeyExistsErr` with `kEventHotKeyExclusive` | Another process registered the same combination exclusively; find that process |
| No error, handler still silent | Registration succeeded; the loss is downstream (event handler not installed, window lookup failing) — probe each stage separately |

## Edge cases

| Case | Then |
|------|------|
| The handler's side effect is not a window (a menu-bar state, a sound, a log line) | Observe whatever external state the handler flips; the requirement is only that it can be read without asking the app itself |
| Registration fails from the terminal too, with nothing printed | The failure is earlier in startup, before the registration call; read the full startup output, not the call site alone |
| The synthetic key event does nothing even for a known-good instance | Accessibility permission for the sending process (Terminal, osascript) is missing; grant it under Privacy & Security before trusting a negative probe |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Restart the app as the first response to "the hotkey stopped working" | Send a synthetic key event and watch the window list first | A restart destroys the evidence and cannot tell a dead registration from a downstream fault |
| Assume another app "stole" the shortcut | Check for a duplicate registration in this process, then for an exclusive registration elsewhere | The header states that non-exclusive registration of the same hotkey in multiple processes is not an error |

## Sources

- https://raw.githubusercontent.com/phracker/MacOSX-SDKs/master/MacOSX10.13.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/CarbonEventsCore.h — `eventHotKeyExistsErr = -9878`: "Returned from RegisterEventHotKey when an attempt is made to register a hotkey that is already registered in the current process. (Note that it is not an error to register the same hotkey in multiple processes.) Also returned if an attempt is made to register a hotkey using the kEventHotKeyExclusive option when another process has already registered the same hotkey with the kEventHotKeyExclusive option."
- https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:) — "Generates and returns information about the selected windows in the current user session"; `kCGWindowIsOnscreen` is one of the returned keys
- https://github.com/Hammerspoon/hammerspoon/issues/1261 — "RegisterEventHotKey failed: -9878" reported in the field by a shipping hotkey tool
- Field reproduction 2026-08-18 (macOS menu-bar app with F7/F8 global hotkeys): a dead instance showed no `kCGWindowIsOnscreen` change on synthetic F7/F8 key codes; a freshly launched instance toggled onscreen 1 → false → 1 on the same events. The original hypothesis that another process had taken the key was replaced after reading the header
