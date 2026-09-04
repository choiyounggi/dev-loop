---
id: mobile-presentation-gating-nested-sheet-presentation
domain: mobile
category: presentation
applies_to: [ios, swiftui]
confidence: field-tested
sources:
  - https://developer.apple.com/documentation/swiftui/view/sheet(item:ondismiss:content:)
  - https://developer.apple.com/documentation/swiftui/view/fullscreencover(item:ondismiss:content:)
  - https://stackoverflow.com/questions/67180982
last_verified: 2026-09-03
related: [mobile-lifecycle-process-death-and-state, mobile-navigation-deep-links-and-entry-points]
---

# Gating a Screen-Level Error Sheet While a Child Presentation Is Open

## When this applies

A SwiftUI host view attaches several `.sheet` / `.fullScreenCover` modifiers,
including a screen-level error sheet bound to a shared store's error state
(`errorMessage: String?`); an error silently fails to appear while a form or cover
is open; an error sheet from one screen appears over a different tab; a container
keeps every tab mounted and each tab can trigger the same error sheet.

## Do this

1. Treat one host as able to drive one active presentation. A second sheet or
   cover requested from a host that is already presenting is refused with the
   runtime warning "Attempt to present … which is already presenting …"; it is
   neither queued nor swapped in. An error sheet bound directly to
   `errorMessage != nil` is dropped whenever a form or cover is open on that host.
2. Gate the error binding to `nil` while any child presentation is active: OR
   every child presentation flag on that host, and for a pushed screen add "this
   view is the top of the navigation path" — a `NavigationStack` root and every
   pushed screen below the visible one stay mounted and keep reacting to the same
   store's `errorMessage` while off screen.
3. Attach the error to the content that is already presented: while a form or
   cover is open, surface the same error as an `.alert` or nested `.sheet` on that
   cover's own content view, which is the one view currently allowed to present.
4. In a container that keeps every tab mounted (a persistent `TabView`), add a
   tab-active environment value to the gate so a background tab's error cannot
   present over the foreground tab.

| Case | Do |
|------|----|
| Host has N child sheets/covers plus an error sheet | Gate the error binding to `nil` while any of the N child flags is true |
| View is a screen pushed onto a `NavigationStack` | Add "is this view the top of the path" to the gate — a covered pushed screen still runs its error-sheet logic |
| The error must be visible while a child sheet/cover is open | Attach the alert or nested sheet to that child's own content, not the host |
| Container keeps every tab mounted | Add a tab-active environment value to the gate |

## Edge cases

| Case | Then |
|------|------|
| The error arrives after the child presentation dismisses | The gate evaluates false and the retained `errorMessage` presents on the next state update — keep the message in the store until it is shown |
| Verifying the gate without a full UI test | Host the view in a probe, drive `presentationActive` (or the store flag it reads) to `false`, and assert the sheet dismisses, its binding setter is called, and `onDismiss` fires |
| The same store drives error state for several screens | Clear the message on dismiss from the screen that showed it, so a screen that becomes active later does not re-present a stale error |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Bind the screen-level error sheet straight to `errorMessage != nil` on a host that also presents forms | Gate the binding on "no child presentation active and this view is on top" | The second presentation from an already-presenting host is refused, so the error vanishes |
| Add the error sheet to every tab's root view in a persistent `TabView` | Gate it on a tab-active environment value | A background tab's root stays mounted and presents its sheet over whichever tab is visible |

## Sources

- https://developer.apple.com/documentation/swiftui/view/sheet(item:ondismiss:content:) — item-driven sheet presentation API and its `onDismiss` callback
- https://developer.apple.com/documentation/swiftui/view/fullscreencover(item:ondismiss:content:) — item-driven full-screen-cover presentation API
- https://stackoverflow.com/questions/67180982 — "SwiftUI [Presentation] / Attempt to present View on … which is already presenting": the runtime warning for a second presentation requested from an already-presenting host
- Field evidence 2026-09-03 (SwiftUI app, three integration-review rounds): the same defect appeared in four places — a place form inside a route editor, a map full-screen cover, a list root under a pushed detail, and an A/B detail stack — each fixed by the gate above; a hosting probe confirmed sheet dismiss, binding setter call, and `onDismiss` firing when `presentationActive` was set to false. Apple's documentation states the API surface but not the single-presenter rule in prose, so the page is field-tested
