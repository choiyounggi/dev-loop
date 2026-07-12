---
id: mobile-permissions-runtime-permissions
domain: mobile
category: permissions
applies_to: [ios, android, cross-platform]
confidence: field-tested
sources:
  - https://developer.android.com/training/permissions/requesting
  - https://developer.apple.com/design/human-interface-guidelines/privacy
  - https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources
  - https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
last_verified: 2026-07-10
related: [mobile-release-staged-rollout-and-hotfix]
---

# Requesting Runtime Permissions Without Burning the One Prompt

## When this applies

A feature needs camera / location / notifications / photos / contacts access;
users deny permissions at high rates; the app dead-ends or crashes after a
denial; deciding when and how to ask.

## Do this

1. **Request in context, not at launch.** Trigger the OS prompt from the user
   action that needs the access (the tap on the camera button), so the reason is
   self-evident. When the value is not self-evident, show a brief in-app
   explanation screen first, then the OS prompt. A launch-time permission wall
   maximizes denials and spends the prompt before the user has any reason to say yes.
2. **The OS prompt is a limited resource.** iOS shows the system prompt once per
   permission — after a denial, only the Settings app can change it. Android stops
   showing the dialog after repeated denials ("don't ask again" behavior). Spend
   the prompt only on an explicit user action, never on speculative access.
3. **Handle every outcome — a denial never dead-ends or crashes:**

| Outcome | Do |
|---------|----|
| Granted | Proceed with the feature |
| Denied once | Keep the feature reachable with a degraded path or an explanation of what it needs; re-request only on the user's next explicit attempt, showing the rationale UI when the platform signals it (`shouldShowRequestPermissionRationale`) |
| Permanently denied / restricted | Show how to enable it in Settings and deep-link to the app's settings page where the platform provides it (Android app-settings intent, iOS `openSettingsURLString`); everything else in the app stays functional |

4. **Check the current authorization status at every point of use**, not a cached
   "user granted once" flag. Users revoke in Settings at any time, and both
   platforms reset permissions of apps unused for months (Android auto-reset /
   app hibernation on Android 11+; iOS applies equivalent unused-app resets). Code
   that assumes granted and dereferences the nil location result is the classic
   post-revocation crash.
5. **Request the minimum scope that serves the feature:** coarse before fine
   location; selected-photos access before full-library; foreground-only before
   background. Background access has a separate, stricter request flow and
   heavier store-review scrutiny — add it only when a shipped feature requires it.
6. **Notifications: ask after the user has experienced the value.** Request after
   the first meaningful action that produces something worth notifying about, not
   on first launch. On iOS, use provisional authorization to deliver quietly
   without any prompt and let the user upgrade from a delivered notification.
7. **Declare and justify every permission for store review:** iOS purpose strings
   (`NS*UsageDescription`) and Android manifest declarations plus the Play data-safety
   form. Undeclared or unjustified access is a review rejection — plan it into the
   release checklist alongside mobile-release-staged-rollout-and-hotfix concerns.

## Edge cases

| Case | Then |
|------|------|
| Permission was granted last session but is denied now | OS-side revocation or unused-app auto-reset — re-run the request flow from the current status; no user "broke" anything |
| The feature is the app's core purpose (a camera app) | Ask on first entry into the core flow, preceded by the explanation screen — still not before the user reaches the flow |
| iOS location "Allow Once" was chosen | Status returns to not-determined on next launch — the flow must tolerate re-prompting on each use |
| User grants limited photo access (selected photos) | Treat it as granted and work within the selection; offer the picker to extend it — do not nag for full-library access |
| Android rationale signal returns false on first ever request | That is the normal first-request state, not "permanently denied" — request directly; distinguish permanent denial by denial-after-request with rationale false |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Request all permissions on first launch | Request each at its point of use, with in-context explanation | Launch-time walls maximize denial and burn the one prompt |
| Gate app entry on notification permission | Defer the ask until after the first meaningful action shows the value | Users deny what has shown no value; the app must work without it |
| Branch on a stored "hasGrantedLocation" flag | Query the platform's current authorization status before each use | Revocation and auto-reset invalidate the flag at any time |
| Assume granted and use the result directly | Handle granted / denied / permanently-denied as three explicit branches | The nil-result crash after denial is the top permission bug |
| Request background location together with foreground | Ship foreground-only; add background in a later release when a feature needs it | Background access has separate flows and stricter review |

## Sources

- https://developer.android.com/training/permissions/requesting — request in context, rationale API, denial handling, repeated-denial "don't ask again" behavior, auto-reset of unused apps' permissions
- https://developer.apple.com/design/human-interface-guidelines/privacy — ask at the moment the feature needs the data, with clear purpose
- https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources — protected-resource prompts and purpose strings
- https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications — notification authorization, provisional (quiet) authorization
