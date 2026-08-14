---
id: qa-environments-headless-browser-bot-blocking
domain: qa
category: environments
applies_to: [general]
confidence: verified
sources:
  - https://raw.githubusercontent.com/chromium/chromium/main/headless/lib/browser/headless_browser_impl.cc
  - "Field reproduction 2026-08-14: dabangapp.com/map/apt — data APIs (markers, room-list) all HTTP 400 under the default headless UA while the page shell and map tiles loaded; after setting a desktop Chrome UA (Mozilla/5.0 … Chrome/131 …) the same URL loaded all data"
last_verified: 2026-08-14
related: [backend-common-integrations-robots-txt-and-source-selection, testing-e2e-e2e-stability]
---

# Empty Data from a Commercial Site Under a Headless Browser

## When this applies

You opened an external production site in a headless browser (QA, dogfooding,
smoke check) and the page shell renders — HTML, styles, maps, static assets —
but lists/data stay empty, often with a generic "temporary delay / try again"
toast. You are about to record the site as having a server-side outage.

## Do this

1. **Split the network log by response kind before diagnosing.** The
   bot-blocking signature is asymmetric: document and static assets return 200
   while the JSON data APIs alone return 4xx. A real outage usually takes the
   document down too, or returns 5xx across the board.
2. **Set a current desktop Chrome UA and reload the same URL.** Chromium builds
   the headless default user agent from the product name `HeadlessChrome`
   (`headless/lib/browser/headless_browser_impl.cc`,
   `kHeadlessProductName = "HeadlessChrome"` — "Product name for building the
   default user agent string"), so a gateway can classify the client as a bot
   from the UA token alone. Swapping the UA is the cheapest discriminating
   probe between "blocked" and "down".
3. **Data loads after the swap → record the finding as UA-based bot
   classification, not an outage.** Configure the QA client's UA in one place
   (browser launch config), and note in the run log that the block is an
   external policy that can change without notice.
4. **Data still missing after the swap → escalate past the UA layer.** Deeper
   fingerprinting (`navigator.webdriver`, TLS/canvas fingerprints, behavioral
   scoring) is in play; verify in a real headed browser profile before drawing
   any conclusion about the site's health.

## Edge cases

| Case | Then |
|------|------|
| The site's robots.txt names bot/client tokens | Check which `User-agent` group your token matches ([backend-common-integrations-robots-txt-and-source-selection]) — the block may be deliberate published policy; when the target is not yours to test, honor it rather than masking around it |
| Only some data endpoints 400 while others load | Per-route WAF rules; capture a per-endpoint status matrix in the bug report instead of a single verdict |
| Works on your machine, empty in CI | The CI run is headless while the local run was headed — apply the same UA probe in the CI environment before blaming the site or the test |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| File "server outage / temporary failure" from the on-page toast text | Run the UA probe and read per-request statuses | The toast is the frontend's generic fallback copy — it reports that a fetch failed, not why |
| Judge the site's health from the rendered page alone | Split document / static / data-API statuses in the network log | Shell-renders-but-data-empty is the classifier's signature, invisible in a screenshot |

## Sources

- https://raw.githubusercontent.com/chromium/chromium/main/headless/lib/browser/headless_browser_impl.cc — `kHeadlessProductName[] = "HeadlessChrome"` with the comment "Product name for building the default user agent string" (checked 2026-08-14): the headless default UA is distinguishable by construction
- Field reproduction 2026-08-14 (dabangapp.com/map/apt): default headless UA → page shell and map render, `markers`/`room-list` data APIs all HTTP 400 with "일시적 지연" toast; identical URL with a desktop Chrome UA → all data APIs 200 and the list populated
