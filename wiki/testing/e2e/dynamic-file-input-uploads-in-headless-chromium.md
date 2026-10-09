---
id: testing-e2e-dynamic-file-input-uploads-in-headless-chromium
domain: testing
category: e2e
applies_to: [chromium, playwright, puppeteer, expo]
confidence: verified
sources:
  - https://raw.githubusercontent.com/expo/expo/main/packages/expo-document-picker/src/ExpoDocumentPicker.web.ts
  - https://chromium.googlesource.com/chromium/src/+/main/content/public/browser/web_contents_delegate.cc
  - https://chromium.googlesource.com/chromium/src/+/main/headless/lib/browser/headless_web_contents_impl.cc
  - https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-setInterceptFileChooserDialog
  - https://playwright.dev/docs/input#upload-files
  - https://pptr.dev/api/puppeteer.page.waitforfilechooser
  - https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/cancel_event
  - https://dom.spec.whatwg.org/#dom-event-preventdefault
last_verified: 2026-10-06
related: [testing-e2e-e2e-stability, debugging-methodology-reproduce-first]
---

# Uploading a File Through a Dynamically Created File Input in Headless Chromium

## When this applies

A headless-browser test or agent drives an upload whose `<input type="file">` the
page creates and clicks itself when the user presses a button —
`expo-document-picker` on web, or any picker that does
`document.createElement('input')` and `dispatchEvent(new MouseEvent('click'))`.
The upload sends no request and the app behaves as if the user cancelled, while
the same flow works in a headed browser.

## Do this

1. **Know why it fails.** The picker resolves its Promise on whichever of
   `change` or `cancel` fires first. In the headless shell the click reaches
   Chromium's default `RunFileChooser`, which calls `FileSelectionCanceled()`
   at once, so `cancel` fires and the picker resolves
   `{ canceled: true }`. Files set afterwards land on an input whose Promise is
   already settled: nothing happens, and it reads as an app bug.
2. **Intercept the chooser instead of letting it open:**

| Driver | Do |
|--------|----|
| Playwright | Start `page.waitForEvent('filechooser')` before the click, click the button, then `fileChooser.setFiles(path)` |
| Puppeteer | `Promise.all([page.waitForFileChooser(), button.click()])`, then `chooser.accept([path])` |
| Raw CDP | Send `Page.setInterceptFileChooserDialog {enabled: true}` before the click; on `Page.fileChooserOpened` set the files with `DOM.setFileInputFiles` on the reported `backendNodeId` |
| Only page JavaScript is available (a REPL channel, no CDP), and the picker opens the input with `input.dispatchEvent(new MouseEvent('click'))` (expo-document-picker) | Before the click, wrap `EventTarget.prototype.dispatchEvent` so a `click` on an `input[type=file]` keeps the element and returns `true` without dispatching; after the click, set its `files` from a `DataTransfer` and dispatch `new Event('change', {bubbles: true})` |
| Only page JavaScript is available, and the picker opens the input with `input.click()` | Before the click, add a capture-phase `click` listener on `document` that calls `preventDefault()` for `input[type=file]` and keeps the element; then set `files` and dispatch `change` as in the row above |

   Interception keeps the native dialog closed, so `cancel` never fires and
   `change` alone delivers the file. The two page-JS rows are not
   interchangeable: `new MouseEvent('click')` is created with
   `cancelable: false`, so `preventDefault()` on it changes nothing, while
   `input.click()` bypasses `dispatchEvent`, so the wrapper never sees it.
   Read the picker's source to pick the row; when you cannot, take the
   Playwright, Puppeteer, or CDP row.
3. **Assert on the upload, not on the click**: wait for the upload request (a
   multipart body with the file name) and its response, then the UI state that
   follows.

## Edge cases

| Case | Then |
|------|------|
| The input exists in the DOM before the click (a static `<input type="file">`) | `locator.setInputFiles(path)` on that input sets the files with no chooser; step 2 is for inputs the page creates on demand |
| The picker passes `multiple` | Pass an array of paths (or several `DataTransfer` items); assert one asset per file |
| The JS-only route is used and the picker reads `input.files` in its `change` handler | Set `files` before dispatching `change` — the handler reads the property, not the event |
| The test runs Chrome's full headless mode (`--headless=new`, Playwright `channel: 'chromium'`) rather than the headless shell | The chooser is cancelled there too (measured below); apply step 2 unchanged |
| A page-JS interception was added and the picker still reports cancelled | Log `event.cancelable` in a capture listener: `false` means the picker dispatches a constructed click, so switch to the `dispatchEvent` wrapper row |
| You remove the click interception after the test passes | Keep it: without it the run returns to sending zero requests (measured below) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Click the upload button, then call `setInputFiles` on the created input | Arm the file-chooser wait before the click and set files on the chooser (step 2) | The headless chooser has already cancelled and settled the picker's Promise |
| File the empty upload as an app bug | Rerun with chooser interception first | The cancel comes from the headless browser, not the app |

## Sources

- https://raw.githubusercontent.com/expo/expo/main/packages/expo-document-picker/src/ExpoDocumentPicker.web.ts — creates a hidden input, registers `change` (resolves the assets) and `cancel` (resolves `{ canceled: true, assets: null }`), then `input.dispatchEvent(new MouseEvent('click'))`; read 2026-10-06
- https://chromium.googlesource.com/chromium/src/+/main/content/public/browser/web_contents_delegate.cc — default `WebContentsDelegate::RunFileChooser` body is `listener->FileSelectionCanceled();`
- https://chromium.googlesource.com/chromium/src/+/main/headless/lib/browser/headless_web_contents_impl.cc — the headless delegate overrides `EnumerateDirectory` but has no `RunFileChooser` override (0 occurrences, read 2026-10-06), so the default above applies
- https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-setInterceptFileChooserDialog — "When file chooser interception is enabled, native file chooser dialog is not shown. Instead, a protocol event `Page.fileChooserOpened` is emitted"
- https://playwright.dev/docs/input#upload-files — for an input "created dynamically", start `page.waitForEvent('filechooser')` before clicking, then `fileChooser.setFiles(...)`
- https://pptr.dev/api/puppeteer.page.waitforfilechooser — `Promise.all([page.waitForFileChooser(), …click()])` then `fileChooser.accept([...])`; `DOM.setFileInputFiles` takes `files` plus a `backendNodeId`, the field `Page.fileChooserOpened` reports (CDP `DOM.pdl`/`Page.pdl`, read 2026-10-06)
- https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/cancel_event — `cancel` fires when the file picker is dismissed without a selection
- https://dom.spec.whatwg.org/#dom-event-preventdefault — "set the canceled flag … if event's cancelable attribute value is true and event's in passive listener flag is unset, then set event's canceled flag, and do nothing otherwise"; `dictionary EventInit { … boolean cancelable = false; }`, so a bare `new MouseEvent('click')` cannot be cancelled
- Measurement 2026-10-06 (Playwright 1.58.2, Chromium 145.0.7632.6, both the headless shell and `channel: 'chromium'` full headless; a page reproducing the expo picker's change/cancel race): naive click then set files → `cancel` then `change`, result `canceled: true`; capture-phase `preventDefault()` → `cancelable: false`, `defaultPrevented: false`, still `canceled: true`; `waitForEvent('filechooser')` + `setFiles` → only `change`, file delivered; `dispatchEvent` wrapper → only `change`, file delivered. Same page with the picker calling `input.click()`: `cancelable: true`, the `preventDefault()` route delivered the file and the `dispatchEvent` wrapper did not
- Field measurement 2026-10-05 (an Expo web app driven by a headless browser): without click interception the upload sent 0 requests; with it a multipart request went out and returned 200
