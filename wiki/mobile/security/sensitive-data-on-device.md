---
id: mobile-security-sensitive-data-on-device
domain: mobile
category: security
applies_to: [ios, android, cross-platform]
confidence: field-tested
sources:
  - https://developer.apple.com/documentation/security/keychain-services
  - https://developer.android.com/privacy-and-security/keystore
  - https://developer.android.com/reference/android/view/WindowManager.LayoutParams#FLAG_SECURE
  - https://developer.apple.com/documentation/uikit/preparing-your-ui-to-run-in-the-background
  - https://developer.android.com/identity/data/autobackup
  - https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup
  - https://developer.android.com/develop/ui/views/touch-and-input/copy-paste
  - https://developer.apple.com/documentation/uikit/uipasteboard
last_verified: 2026-07-10
related: [mobile-lifecycle-process-death-and-state, security-data-pii-handling, frontend-auth-token-handling-client-side]
---

# Sensitive Data on Device — Storage Classes and Leak Surfaces

## When this applies

Storing tokens, credentials, or PII in a mobile app; choosing between storage
APIs (UserDefaults / SharedPreferences / files / Keychain / Keystore); reviewing
what leaks via app-switcher screenshots, backups, clipboard, logs, or WebViews.

## Do this

1. **Pick storage by sensitivity, not convenience:**

| Data | Store in |
|------|----------|
| Session tokens, credentials, cryptographic keys | OS secure storage only: iOS Keychain with an accessibility class scoped to actual need (when-unlocked or after-first-unlock — not the always-accessible class); Android Keystore-backed encryption (EncryptedSharedPreferences-style wrapper over a Keystore key) |
| Cached user PII (names, contacts, financial records) | Encrypted-at-rest local store, holding the minimum set per [security-data-pii-handling] |
| Non-sensitive preferences (theme, last tab, feature intro seen) | Plain UserDefaults / SharedPreferences |

   "App-private" plain prefs and files are readable on rooted/jailbroken devices
   and through backup-extraction paths — app-private is an access-control claim,
   not encryption at rest. Token survival across process death is covered in
   [mobile-lifecycle-process-death-and-state].
2. **Close each leak surface beyond storage:**

| Leak surface | Do |
|--------------|----|
| App-switcher snapshot (OS screenshots the last screen on backgrounding) | Mask or blur sensitive screens (payment, balances) when the app backgrounds: iOS — cover the window in the scene `willResignActive`/`didEnterBackground` hook before the snapshot is taken; Android — set `FLAG_SECURE` on the window, which also blocks screenshots and screen recording where that protection is warranted |
| Clipboard (OTPs, account numbers the user copies) | Flag sensitive copies: Android `ClipDescription.EXTRA_IS_SENSITIVE`; iOS `UIPasteboard` `localOnly` + `expirationDate` options. Never auto-copy secrets to the clipboard on the user's behalf |
| Backups (cloud/device backup restores files onto another device) | Exclude secure files: iOS `isExcludedFromBackup`; Android backup rules `<exclude>` (fullBackupContent / dataExtractionRules). A token restored onto another device via backup is a session-migration hole — pair exclusion with server-side token revocation (see wiki/backend/common/auth/) |
| Logs and crash reports (SDKs upload breadcrumbs and attachments) | Never log tokens or PII; scrub breadcrumbs, custom keys, and attachments in the crash-SDK callback before upload |
| Keyboard (third-party keyboards learn input; autofill echoes it) | Flag sensitive fields as secure text entry (iOS `isSecureTextEntry`; Android `textPassword`-class input types) — this also suppresses keyboard learning and autofill leaks |
| WebView (cookies/localStorage inside it outlive native storage discipline) | Keep native session tokens out of WebViews; hand the WebView a scoped, short-lived credential minted for it. Web-side handling inside the WebView follows [frontend-auth-token-handling-client-side] |

## Edge cases

| Case | Then |
|------|------|
| iOS Keychain items survive app uninstall | Treat a fresh install with a readable token as unauthenticated state: validate the token server-side or clear keychain entries on first launch after install |
| Background work needs the token while the device is locked | Use the after-first-unlock accessibility class for that item; when-unlocked items are unreadable during locked-device background refresh |
| Device has no passcode/lock screen set | Passcode-required accessibility classes fail to store; detect the store error and degrade (re-auth per session) instead of silently falling back to plain storage |
| FLAG_SECURE blocks a screenshot the user legitimately wants | Scope it to the windows/screens that show sensitive data, not app-wide |
| The masked snapshot still flashes content during transition | Apply the cover in `willResignActive` (before the snapshot), not in `didEnterBackground` only — the snapshot is taken between them |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Put a token in SharedPreferences/UserDefaults because "it's app-private" | iOS Keychain / Android Keystore-backed storage | App-private is access control, not encryption at rest — rooted devices and backup paths read it |
| Skip the app-switcher mask on a finance/balance screen | Mask on backgrounding (iOS scene hook cover; Android FLAG_SECURE) | The OS snapshot persists the screen to disk and shows it in the switcher |
| Let secure files ride the default backup | Exclude them (isExcludedFromBackup / backup rules) and keep server-side revocation | Backup restore migrates the session onto another device |
| Log the auth header while debugging an API call | Log a redacted marker; scrub crash-SDK breadcrumbs | Crash/log pipelines upload and retain whatever was logged |
| Inject the native session token into a WebView | Mint a scoped short-lived credential for the WebView | WebView cookies/localStorage escape your storage discipline and revocation |

## Sources

- https://developer.apple.com/documentation/security/keychain-services — Keychain storage for secrets, accessibility classes
- https://developer.android.com/privacy-and-security/keystore — Keystore-backed key and credential protection
- https://developer.android.com/reference/android/view/WindowManager.LayoutParams#FLAG_SECURE — secure window: excluded from screenshots and non-secure displays
- https://developer.apple.com/documentation/uikit/preparing-your-ui-to-run-in-the-background — background transition, snapshot preparation hooks
- https://developer.android.com/identity/data/autobackup — Auto Backup include/exclude rules (fullBackupContent, dataExtractionRules)
- https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup — excluding files from backup on iOS
- https://developer.android.com/develop/ui/views/touch-and-input/copy-paste — EXTRA_IS_SENSITIVE clipboard flag
- https://developer.apple.com/documentation/uikit/uipasteboard — localOnly and expirationDate pasteboard options
