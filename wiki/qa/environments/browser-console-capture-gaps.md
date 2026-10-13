---
id: qa-environments-browser-console-capture-gaps
domain: qa
category: environments
applies_to: [general, chrome, cdp]
confidence: verified
sources:
  - https://chromedevtools.github.io/devtools-protocol/tot/Runtime/
  - https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts
  - https://playwright.dev/docs/browsers
  - https://playwright.dev/docs/api/class-consolemessage
  - https://chromium.googlesource.com/chromium/src/+/bf4de3ff1c10a7ca6b1c4ca00451165f18fa1eef%5E!/
  - "Local reproduction 2026-10-11 (playwright-core 1.63.0; Chrome 155 and Chromium 153): favicon requests and console errors per launch mode, page, tab and context"
last_verified: 2026-10-11
related:
  [
    qa-environments-headless-browser-bot-blocking,
    platforms-tools-unpacked-extension-source-reload,
    platforms-processes-tool-diagnostics-without-a-failing-exit-code,
    testing-quality-tests-that-cannot-fail,
    qa-environments-element-crop-screenshots,
  ]
---

# Judging a Page by Console Output a Tool Never Collected

## When this applies

A browser-automation tool (CDP-based CLI, Playwright, an agent browser skill)
collects `console` output and you are about to read the result as a QA verdict —
"no errors", "the script did not run", "the extension is broken". Also when the
collected list is empty for a page you know logs on load, or when checking whether
a browser extension's content script executed.

## Do this

1. **Establish when the collector attaches, before reading a count.** Two
   attachment models produce opposite blind spots, and the empty list looks the
   same in both:

| Collector model | Blind spot | How to get the load-time records |
|---|---|---|
| Buffer attached by the tool's navigation helper *after* load completes | Everything logged while the document was parsing and scripts were initialising | Clear the buffer, `reload()`, then read — the listener is already attached across the second load |
| Listener you register yourself (`page.on('console', …)`) | Anything before your registration line runs | Register on the page object *before* calling `goto`/`openTab` |

2. **Prove the collector works on this page before trusting a zero.** Run one
   deliberate `console.log`/`console.error` through the same path you are
   measuring and require both to come back. A collector that returns zero for a
   known-noisy page is measuring nothing ([testing-quality-tests-that-cannot-fail]).

3. **Judge extension content scripts by DOM effects, not by their logs.** A
   content script runs in an isolated world — a separate execution context — so
   its `console` records carry a different `executionContextId`, and a collector
   bound to the page's main context reports none of them. Assert on what the
   script changes instead: field values it fills, elements it inserts, the URL
   transition it triggers.

4. **State the collection window with the verdict.** "No console errors after
   load, buffer attached post-navigation" and "no console errors across a full
   reload" clear different amounts of the page; the first leaves framework mount
   failures — the highest-value diagnostics — unmeasured.

## Edge cases

| Case | Then |
|------|------|
| The tool exposes both a listener API and a buffer | Use the buffer and treat a silent listener as unimplemented rather than as evidence: measured on Aside CLI 1.26.810, `p.on('console', …)` yielded 0 records while `await p.console.logs()` returned them |
| Reloading is destructive (the page holds unsaved state, a one-shot token, a POST result) | Keep the post-load reading and record the window explicitly, or re-open a fresh instance of the same URL and reload that one |
| The page logs from an iframe or a web worker | Those are separate execution contexts too — select the frame/worker target explicitly before reading, or assert on DOM effects |
| Logs appear only in the browser's own DevTools window, not in the tool's list | That is the same context split — DevTools shows every context; a tool that binds one context shows one |
| The extension logs are what you actually need | Attach to the extension's own context (its service-worker / isolated-world target) rather than the page target, and confirm with one deliberate log through that path |
| The gate requires zero console errors and the app serves no favicon | Chrome and new-headless Chromium request `/favicon.ico` once per browser process and log its 404 as a console error on the first page that loads the origin; later pages, tabs and contexts of that browser do not request it again, and Playwright's default headless shell requests none. Serve an icon (`<link rel="icon" href="data:,">` also stops the request), or drop errors whose `location().url` ends in `/favicon.ico` before counting the rest |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Report "0 console errors" from a single post-navigation read | Clear, reload, read again, and report which window the zero covers | Measured 2026-08-18 (Aside CLI 1.26.810 / daemon 1.26.818.1059): a page logging one `log` and one `error` inline returned `[]` immediately after `openTab` and `[]` after 800 ms; after `console.clear()` + `reload()` the same read returned both records |
| Conclude a content script never ran because its startup log is absent | Check the DOM side effect the script owns | Isolated-world records do not reach a main-world collector, so absence of logs and absence of execution are indistinguishable from that reading |
| Add a longer `sleep` when the log list is empty | Re-check the attachment point | Waiting cannot recover records emitted before the listener existed — 800 ms produced the same empty list as 0 ms |
| Take the collector's empty result as the page's state | Send one deliberate log through the same path first | An empty list from a broken collector and from a clean page are the same value ([platforms-processes-tool-diagnostics-without-a-failing-exit-code]) |
| Expect exactly one favicon 404, or zero errors, on an app without an icon | Serve an icon, or filter the `/favicon.ico` 404 by `location().url` and require zero of the rest | The 404 appears on the first page of each Chrome launch only and never under the headless shell, so either fixed count fails on correct code in some mode or test order |

## Sources

- https://chromedevtools.github.io/devtools-protocol/tot/Runtime/ — `Runtime.consoleAPICalled` carries `executionContextId`, "Identifier of the context where the call was made"; `Runtime.executionContextCreated` carries an `ExecutionContextDescription` whose `auxData` is documented as "Embedder-specific auxiliary data"; the default/isolated/worker distinction is read from that data rather than from a documented field of its own
- https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts — "An isolated world is a private execution environment that isn't accessible to the page or other extensions"; "JavaScript variables in an extension's content scripts are not visible to the host page"
- Local reproduction 2026-08-18 (Aside CLI 1.26.810.1915, daemon 1.26.818.1059, local `python3 -m http.server` page logging one `log` + one `error` from an inline script): `openTab` → `[]`; after `sleep(800)` → `[]`; after `console.clear()` + `reload()` + `sleep(300)` → `["log:load-time-log","error:load-time-error"]`
- https://playwright.dev/docs/browsers — "Playwright ships a regular Chromium build for headed operations and a separate chromium headless shell for headless mode"; "You can opt into the new headless mode by using 'chromium' channel"; Google Chrome has "switched to a new headless mode implementation"
- https://playwright.dev/docs/api/class-consolemessage — `location()` returns `url`, the "URL of the resource"
- https://chromium.googlesource.com/chromium/src/+/bf4de3ff1c10a7ca6b1c4ca00451165f18fa1eef%5E!/ — `components/favicon/core/favicon_service.h`: "// Avoid repeated requests to download missing favicon." above `UnableToDownloadFavicon(const GURL& icon_url)` and `WasUnableToDownloadFavicon(const GURL& icon_url)`
- Local reproduction 2026-10-11 (playwright-core 1.63.0, a local server answering 404 for every path but its pages; per launch: page 1 `/`, the same page to `/two`, a second tab on `/`, a second context on `/`): `channel: 'chrome'` headless (Chrome 155.0.8059.39) and `channel: 'chromium'` (Chromium 153.0.8010.12, new headless) each logged one `Failed to load resource: … 404` with `location().url` ending in `/favicon.ico`, on the first page only, and requested `/favicon.ico` once; the default headless shell (Chromium 153.0.8010.12) logged 0 errors and never requested it. With `<link rel="icon" href="data:,">` in the page, Chrome 155 logged 0 errors and requested only `/`
- Field measurement 2026-08-18 (okta-autofill unpacked extension): a `console.log` at the top of `content.js` produced 0 records in the tool's buffer while the same run filled the OTP field and advanced the URL to the post-login page — the script had demonstrably executed
- Field origin 2026-10 (linkly-invitation task t7c, a Playwright check of an app without a favicon; recorded by the originating session): a "0 console errors" gate failed on correct code with one `/favicon.ico` 404 on the first page
