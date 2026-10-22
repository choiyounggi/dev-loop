---
id: frontend-browser-apis-copying-text-from-a-tap
domain: frontend
category: browser-apis
applies_to: [general, javascript]
confidence: verified
sources:
  - https://webkit.org/blog/10855/async-clipboard-api/
  - https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API
  - https://developer.mozilla.org/en-US/docs/Web/API/Document/execCommand
  - https://w3c.github.io/clipboard-apis/
  - https://html.spec.whatwg.org/multipage/interaction.html
  - https://bugs.webkit.org/show_bug.cgi?id=193758
  - https://trac.webkit.org/changeset/251387
  - https://css-tricks.com/16px-or-larger-text-prevents-ios-form-zoom/
  - "Local measurement 2026-10-11 (Playwright 1.64.0, Chromium 156; jsdom 30.1.2)"
last_verified: 2026-10-11
related: [testing-quality-surviving-mutant-equivalence-triage]
---

# Copying Text to the Clipboard From a Tap

## When this applies

A button copies text (an account number, an invite code, a link) to the clipboard
in a web page or an in-app browser, and the page is also served over plain http on
a LAN address for device testing; deciding the fallback when `navigator.clipboard`
is missing or its write rejects, and what the user sees when the copy fails.

## Do this

1. **Call `navigator.clipboard.writeText(text)` inside the tap handler before any
   `await`**, when `typeof navigator.clipboard?.writeText === 'function'`. WebKit
   rejects a write made "outside the scope of a user gesture" immediately; Firefox
   and Safari require transient activation for writing, and Chromium requires the
   `clipboard-write` permission or transient activation.
2. **When the text needs async work first, start the write in the gesture with a
   promise:** `navigator.clipboard.write([new ClipboardItem({ 'text/plain': textPromise })])`
   — WebKit initializes each `ClipboardItem` with a promise per MIME type.
3. **When `navigator.clipboard` is absent, run the legacy copy synchronously in the
   same handler; when `writeText` rejects, run it once in the rejection callback:**
   a `<textarea readonly>` holding the text (position fixed,
   opacity 0, font-size 16px), appended, then `focus()`, `select()`,
   `setSelectionRange(0, text.length)`, `document.execCommand('copy')`; remove it
   and return focus to the element that had it. `true` means copied; `false` or a
   throw means not copied.
4. **Show an outcome for both results:** a confirmation on success; on failure,
   the text itself, selectable, with a line asking the user to copy it by hand.

| Situation | Path that runs | Outcome |
|---|---|---|
| https or `http://localhost`, write started in the tap | `writeText` | Resolves: copied |
| http on a LAN IP | No `navigator.clipboard` (measured: `isSecureContext` false, `typeof navigator.clipboard` `'undefined'`), so step 3 runs inside the tap | `execCommand` runs inside the user interaction that MDN requires for a `true` result |
| `writeText` rejects (gesture lost, permission denied) | Step 3 once in the rejection callback, after the tap's handler returned | MDN: `execCommand` "only returns `true` if it is invoked as part of a user interaction", so the result can be `false` here; `true` shows the confirmation, `false` or a throw shows the step-4 failure text |

## Edge cases

| Case | Then |
|------|------|
| The copy is triggered by script (`button.click()` from a timer) | Activation comes only from trusted `keydown`, `mousedown`, `pointerdown`, `pointerup` or `touchend` events, so a script-dispatched click carries none; start the copy from the user's own event |
| Time between the tap and the write | The HTML standard expects the transient activation duration to be "at most a few seconds"; start the write synchronously rather than budgeting against it |
| The fallback textarea zooms the page on iOS | Keep its font-size at 16px; the threshold comes from a secondary source (CSS-Tricks), and no WebKit or Apple statement was found |
| The on-screen keyboard opens during the fallback | `readonly` suppresses it: WebKit shows no keyboard for focused readonly inputs since iOS 13 (changeset 251387, stated for `<input>`; no primary source covers `<textarea>`) |
| Removing `setSelectionRange` because `select()` already selects | Keep it: iOS `select()` moved the caret to the end instead of selecting until WebKit bug 193758 was fixed in January 2019, and WebKit's own legacy example calls `setSelectionRange(0, input.value.length)` |
| Unit tests under jsdom | jsdom 30.1.2 has neither `navigator.clipboard` nor `document.execCommand` (calling it throws `TypeError`); stub both. Its `select()` already sets the full range, so a mutant deleting `setSelectionRange` survives → [testing-quality-surviving-mutant-equivalence-triage] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `await` a fetch or a state update, then call `writeText` | Start the write in the tap with a `ClipboardItem` promise, or prepare the text before the tap | WebKit rejects a write outside the gesture immediately |
| Ship `writeText` with no fallback | Feature-detect and fall back (step 3), then show the failure text (step 4) | `navigator.clipboard` is undefined on insecure origins such as http on a LAN IP (measured in Chromium) |
| Retry `execCommand('copy')` after it returned `false` | Show the text for copying by hand | Outside a user interaction it keeps returning `false` |

## Sources

- https://webkit.org/blog/10855/async-clipboard-api/ — "The API is limited to secure contexts, which means that `navigator.clipboard` is not present for `http://` websites."; "A call to `clipboard.write` or `clipboard.writeText` outside the scope of a user gesture (such as "click" or "touch" event handlers) will result in the immediate rejection of the promise returned by the API call."; "Each `ClipboardItem` is initialized with a mapping of MIME type to `Promise`"; the legacy example `input.focus(); input.setSelectionRange(0, input.value.length); document.execCommand("Copy");`
- https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API — Security considerations: Chromium "Writing requires either the clipboard-write permission or transient activation."; Firefox and Safari "Writing requires transient activation."
- https://developer.mozilla.org/en-US/docs/Web/API/Document/execCommand — deprecated; `copy` "Copies the current selection to the clipboard. Conditions of having this behavior enabled vary from one browser to another"; "`document.execCommand()` only returns `true` if it is invoked as part of a user interaction."
- https://w3c.github.io/clipboard-apis/ — `[SecureContext, SameObject] readonly attribute Clipboard clipboard;`
- https://html.spec.whatwg.org/multipage/interaction.html — "The transient activation duration is expected be at most a few seconds"; an activation triggering input event is a trusted `keydown` (not Esc or a reserved shortcut), `mousedown`, `pointerdown` from a mouse, `pointerup` from a non-mouse pointer, or `touchend`
- https://bugs.webkit.org/show_bug.cgi?id=193758 — removes "We don't want to select all the text on iOS"; "the select() method should still select all the contents of the text field, since that's what the HTML spec mandates"; committed r240452 on 2019-01-24
- https://trac.webkit.org/changeset/251387 — "we (intentionally) no longer show a keyboard when focusing `readonly` inputs" (iOS 13)
- https://css-tricks.com/16px-or-larger-text-prevents-ios-form-zoom/ — secondary: "If the font-size of an `<input>` is 16px or larger, Safari on iOS will focus into the input normally. But as soon as the font-size is 15px or less, the viewport will zoom into that input."
- Local measurement 2026-10-11 (Playwright 1.64.0, Chromium 156, a static page served on all interfaces): `http://127.0.0.1` → `isSecureContext` true, `typeof navigator.clipboard` `'object'`; `http://<LAN IPv4>` → `isSecureContext` false, `'undefined'`. jsdom 30.1.2 under Node 26.7.0: `typeof document.execCommand` `'undefined'`, calling it throws `TypeError`, `navigator.clipboard` undefined
- Field origin 2026-10-10 (linkly-invitation task t5 plan, the copy-routine decision; recorded by the planning session)
