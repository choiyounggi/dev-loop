---
id: qa-environments-init-scripts-skipped-by-setcontent
domain: qa
category: environments
applies_to: [general, playwright, chromium, cdp]
confidence: verified
sources:
  - https://playwright.dev/docs/api/class-page
  - https://github.com/microsoft/playwright/issues/13274
  - https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html
  - "Local reproduction 2026-10-11 (playwright-core 1.63.0, Chromium 153.0.8010.12 headless shell): six registration/load cases, including a no-init-script control"
  - "Field origin 2026-10-11 (a reduced-motion probe; recorded by the originating session)"
last_verified: 2026-10-11
related: [qa-environments-browser-console-capture-gaps, testing-e2e-e2e-stability, testing-quality-harness-reverse-controls]
---

# A Probe's Init Script Skipped by `page.setContent`

## When this applies

A Playwright (or other CDP-driven) probe registers an init script —
`page.addInitScript`, `context.addInitScript` — to install counters, event
listeners or stubs before a page's own scripts run, and loads its HTML fixture
with `page.setContent(html)`; the probe's globals read `undefined`, or its
listener never fires on a page that provably has the behaviour. Also when
choosing how to load an inline HTML fixture so the init script runs first.

## Do this

1. **Load the fixture by a navigation, not by `setContent`.** Register the init
   script, intercept a URL, and `goto` it:

```js
await page.addInitScript(() => { window.__starts = { animationstart: 0 }; /* listeners here */ });
await page.route('**/probe.html', (route) =>
  route.fulfill({ contentType: 'text/html', body: html }));
await page.goto('http://probe.invalid/probe.html');
```

   `addInitScript` runs "whenever the page is navigated … after the document was
   created but before any of its scripts were run"; `setContent` "internally
   calls `document.write()`" on the document that is already there, so it is not
   a navigation and the script is never evaluated for it.

2. **Read what each load path gives the fixture's scripts** (measured; see Sources):

| Init script registered | Fixture loaded by | What the fixture's scripts see |
|---|---|---|
| `page.addInitScript` after `newPage()` | `page.setContent`, once or repeatedly | Nothing: globals `undefined`, listeners absent — the probe measures nothing and reads as "no events" |
| `page.addInitScript`, then `page.goto('about:blank')` | `page.setContent` | The globals the script set on the blank page (`document.write` keeps the Window), but none of its listeners: `document.open()` erases every listener on the document and its nodes |
| `context.addInitScript` before `newPage()` | `page.setContent` | Same as the row above: the script ran for the initial blank document; globals survive, listeners are erased |
| `page.addInitScript` or `context.addInitScript` | `page.route` + `page.goto` | The script's globals and listeners, installed before the fixture's own scripts; it runs again on every later `goto` |

3. **Prove the probe with a control before reading its verdict.** Load the same
   fixture through the same path without the init script (or with the behaviour
   under test removed) and confirm the reading changes; a probe that reads
   `undefined` or `0` both ways has not measured anything
   ([testing-quality-harness-reverse-controls]).

## Edge cases

| Case | Then |
|------|------|
| The fixture needs an origin (relative URLs, `fetch` to a same-origin path, cookies) | Pick the route URL on the origin the fixture expects and fulfill every path it requests; `page.goto` sets `location.href` to that URL, `setContent` leaves it at `about:blank` (measured) |
| `goto` fails with `net::ERR_NAME_NOT_RESOLVED` or a timeout | The route glob did not match the URL, so the request left for the network: match the glob to the exact path (`'**/probe.html'` for `http://probe.invalid/probe.html`) |
| The probe only stores state on `window` and reads it later, with no listeners | The `about:blank`-first and context-level rows above keep those globals, but the fixture's inline scripts still run after a `document.open()` that erased every listener; route + `goto` covers both kinds of probe with one load path |
| The check runs several fixtures or routes in one page | Each `goto` re-runs the init script and re-creates the JS world, so counters reset per load: read them before the next `goto` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `page.setContent(html)` after `page.addInitScript(...)` | `page.route` + `page.goto` on a URL you fulfill with `html` | `setContent` is `document.write()` on the existing document — no navigation, so the init script is not evaluated and the JS world is not re-created |
| `page.goto('about:blank')` first, then `setContent`, to "trigger" the init script | The same route + `goto` | The script's globals survive, but `document.open()` erases the listeners it attached (measured: the `animationstart` list stayed empty) |
| Read a probe's "0 events" as "no motion" or "no calls" | Run the no-init control and the removed-behaviour control first | A probe whose script never ran also reports 0 |

## Sources

- https://playwright.dev/docs/api/class-page — `addInitScript`: "Adds a script which would be evaluated in one of the following scenarios: Whenever the page is navigated. Whenever the child frame is attached or navigated. … The script is evaluated after the document was created but before any of its scripts were run."; `setContent`: "This method internally calls document.write(), inheriting all its specific characteristics and behaviors."
- https://github.com/microsoft/playwright/issues/13274 — maintainer comment (2022-04-03): "`page.setContent` does not run the init scripts, because JS world is not re-created, only navigation such as `page.goto` re-creates it."
- https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html — document open steps: "For each shadow-including inclusive descendant node of document, erase all event listeners and handlers given node."
- Local reproduction 2026-10-11 (playwright-core 1.63.0, Chromium 153.0.8010.12 headless shell; fixture: a 60 ms CSS animation plus an inline script recording `typeof window.__probe`; init script sets `window.__probe`, `window.__events = []` and a capturing `animationstart` listener on `document`): `page.addInitScript` + `setContent` (once or twice) → `__probe` `undefined`, inline script saw `undefined`, `__events` `undefined`, `location.href` `about:blank`; `page.addInitScript` + `route` + `goto` → `__probe` `1`, inline script saw `number`, `__events` `["animationstart"]`, `location.href` the routed URL; `page.addInitScript` + `goto('about:blank')` + `setContent`, and `context.addInitScript` + `newPage()` + `setContent` → `__probe` `1`, inline script saw `number`, `__events` `[]`; no init script + `route` + `goto` (control) → `undefined` throughout
- Field origin 2026-10-11 (a reduced-motion probe counting `animationstart`/`transitionrun`; recorded by the originating session): `page.evaluate(() => window.__starts)` returned `undefined` after `setContent` ("Cannot read properties of undefined (reading 'animationstart')"); the same init script with `page.route('**/probe.html', …)` + `page.goto('http://probe.invalid/probe.html')` recorded `{animationstart: 1, transitionrun: 12, transitionstart: 12}`
