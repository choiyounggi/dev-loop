---
id: platforms-tools-unpacked-extension-source-reload
domain: platforms
category: tools
applies_to: [chrome, chromium, edge, general]
confidence: verified
sources:
  - https://developer.chrome.com/docs/extensions/get-started/tutorial/hello-world
  - https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts
  - https://developer.chrome.com/docs/extensions/reference/api/runtime
last_verified: 2026-08-18
related:
  [
    platforms-tools-version-keyed-artifact-cache,
    backend-python-language-bytecode-cache-staleness,
    qa-environments-browser-console-capture-gaps,
  ]
---

# Getting an Edited Unpacked Extension to Actually Run

## When this applies

You edited a file of a Chromium extension loaded unpacked ("Load unpacked" /
developer mode) — a content script, the service worker, the manifest — and are
about to judge the change by exercising the browser. Also when the edit appears
to have no effect and you are about to look for the defect in the new code.

## Do this

1. **Match the reload action to the file you changed**, then re-exercise. The
   host page reload alone re-injects the copy the browser already holds:

| Edited file | Reload the extension | Reload the host page |
|---|---|---|
| Content script | Yes | Yes |
| Service worker / background | Yes | No (unless the page talks to it) |
| Manifest, static resources | Yes | Yes |
| Popup / options page HTML+JS | Yes | Re-open the popup |

2. **Confirm the new build is the running build before diagnosing anything
   else.** Put a version marker the running code exposes — a DOM attribute the
   content script writes, `chrome.runtime.getManifest().version`, a marker element
   — and read it from the page. A marker the page can show beats a log line,
   because content-script logs are collected from a different execution context
   ([qa-environments-browser-console-capture-gaps]).

3. **Automate the reload when the loop repeats.** The reload control on
   `chrome://extensions` sits behind three nested shadow roots —
   `extensions-manager` → `extensions-item-list` → `extensions-item` → the
   `#dev-reload-button` inside it — so a CDP `evaluate` that walks `shadowRoot` at
   each level can click it (measured on Chromium 2026-08; the selector is an
   internal detail of that page and is not part of any documented API — re-derive
   it from the live DOM when it stops matching).

4. **Read "the edit had no effect" as a staleness question first.** Ask which
   copy ran, and only then whether the code is wrong — the same question the
   bytecode-cache and version-keyed-cache cases resolve
   ([backend-python-language-bytecode-cache-staleness],
   [platforms-tools-version-keyed-artifact-cache]).

## Edge cases

| Case | Then |
|------|------|
| The extension is packed/store-installed rather than unpacked | The reload button does not exist; re-install the unpacked copy from the working tree for the dev loop, and keep the store copy disabled so two copies do not both inject |
| The content script uses `run_at: document_start` | Reload the extension, then reload the page with the devtools/network panel already open — a script that must run before parsing cannot be re-triggered by re-navigating within the loaded document |
| Changing the manifest's `matches`, permissions, or script list | Reload the extension and re-check the injection actually happens on the target URL — pattern changes silently reduce the injection set to zero |
| The old and new copy differ only in behaviour, not in visible markers | Add the marker first, reload, confirm the marker, then judge the behaviour — otherwise a failed reload and a failed fix look identical |
| An automated run drove the page and saw no effect | Re-run the reload step inside the same automation, not manually between runs, so the recorded evidence covers the state the run actually exercised |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Refresh the page and conclude the new content script is broken | Reload the extension, then refresh the page, then judge | Chrome's own tutorial lists content scripts as requiring an extension refresh "plus the host page"; the page refresh alone re-injects the loaded copy |
| Add logging to work out why the edit does nothing | Add a version marker the page exposes and check which build is running | Content-script logs land in an isolated execution context that page-bound collectors do not read, so absent logs prove nothing here |
| Hardcode the `#dev-reload-button` path into a long-lived tool | Re-derive it from the live DOM each run, and fail loudly when it is not found | It is an unversioned internal of `chrome://extensions`; a silent miss turns every later run into a stale-code run |

## Sources

- https://developer.chrome.com/docs/extensions/get-started/tutorial/hello-world — "After saving the file, to see this change in the browser you also have to refresh the extension"; its reload table lists content scripts as "Yes (plus the host page)"
- https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts — content scripts run in an isolated world, "a private execution environment that isn't accessible to the page or other extensions" — why a page-context log is not the staleness signal
- https://developer.chrome.com/docs/extensions/reference/api/runtime — `chrome.runtime.getManifest()` "Returns details about the app or extension from the manifest. The object returned is a serialization of the full manifest file." — read from the extension's own running code, which is what makes it usable as the step-2 marker
- Field measurement 2026-08-18 (okta-autofill, Chromium, unpacked): `content.js` replaced on disk, host page refreshed only → the target field stayed empty (`valueLen=0`); clicking `#dev-reload-button` through the three shadow roots on `chrome://extensions` and retrying the same flow → the field filled, the form submitted, and the browser reached the post-login page
