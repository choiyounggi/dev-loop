---
id: backend-common-api-design-cors-and-preflight
domain: backend
category: api-design
applies_to: [general]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS
  - https://fetch.spec.whatwg.org/#http-cors-protocol
last_verified: 2026-09-06
related: [security-api-exposure-exposing-an-origin-http-api, debugging-methodology-probe-path-vs-operation-path, qa-environments-browser-console-capture-gaps]
---

# Handling Browser CORS Requests and Preflight

## When this applies

A browser calls your API from a different origin (different scheme, host, or
port) via `fetch`/`XMLHttpRequest`, and the request fails in the browser
console with a CORS error even though a direct `curl` to the same endpoint
succeeds — CORS is enforced by the browser, not the server, so server-side
tools never reproduce it. Also applies when designing which endpoints need
`Access-Control-*` headers and whether the browser will send an OPTIONS
preflight before the real request. Also when an instrumentation probe injected
into a page (a WKWebView/Tauri app, a browser under test) `fetch`-POSTs JSON to a
local collector you wrote and the collector logs nothing.

## Do this

| Case | Do |
|------|----|
| Request is a "simple request" (GET/HEAD/POST, only CORS-safelisted headers, `Content-Type` is one of `application/x-www-form-urlencoded`, `multipart/form-data`, or `text/plain`) | No preflight is sent; the browser makes the request directly and only checks `Access-Control-Allow-Origin` on the response before exposing it to JS |
| Request uses a non-safelisted method (PUT/DELETE/PATCH), a custom header, or another `Content-Type` (e.g. `application/json`) | Browser sends an `OPTIONS` preflight first; the server must answer it with `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, and `Access-Control-Allow-Headers` before the browser sends the real request |
| Public, unauthenticated endpoint (no cookies/credentials) | `Access-Control-Allow-Origin: *` is allowed |
| Endpoint reads cookies or `Authorization` and needs `credentials: 'include'` on the client | Respond with an explicit single origin (never `*`) in `Access-Control-Allow-Origin`, plus `Access-Control-Allow-Credentials: true` — the Fetch spec forbids the wildcard on any of `Access-Control-Allow-Origin`, `-Headers`, `-Methods`, or `-Expose-Headers` for a credentialed request, and the browser blocks the response client-side if you send it anyway |
| Allowlisting more than one origin | Do not join multiple origins with commas into one `Access-Control-Allow-Origin` value (browsers reject a header carrying more than one origin) — compute a per-request response: look up the request's `Origin` header against your allowlist and echo back only that single value, with `Vary: Origin` so caches don't serve one origin's response to another |
| Preflight fires on every request, adding a round trip | Set `Access-Control-Max-Age` (seconds) on the preflight response so the browser caches the result and skips re-preflighting the same method+headers+origin combination until it expires |

## Edge cases

| Case | Then |
|------|------|
| Preflight succeeds (200) but the real request still fails CORS | The preflight and the real response are checked independently — the real response also needs `Access-Control-Allow-Origin`; a proxy/CDN that strips CORS headers only from the real response is a common cause |
| A reverse proxy or API gateway sits in front of the origin | Confirm CORS headers are added at the layer that actually terminates OPTIONS — if the origin app never sees the preflight (the gateway auto-answers it), the origin's response headers still need to match or the real response is blocked |
| Non-browser client (server-to-server, mobile app, curl) reports a "CORS error" | It cannot — CORS is a browser-enforced restriction; the real failure is elsewhere (auth, network) and the report is misattributed |
| An injected probe POSTs JSON to a hand-rolled local collector (`http.createServer` branching on `POST` only) and nothing arrives, while a direct `curl -X POST` succeeds | `Content-Type: application/json` makes the browser send `OPTIONS` first; a server that answers only `POST` returns 404 to the preflight and the real POST is never sent — the page's `fetch(...).catch()` swallows it, so the probe looks unreachable rather than rejected. Run `curl -i -X OPTIONS <url>` and require a 2xx carrying `Access-Control-Allow-Origin`, `-Methods`, `-Headers`; then answer `OPTIONS` with 204 plus those headers and put `Access-Control-Allow-Origin` on the `POST` response as well |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Set `Access-Control-Allow-Origin: *` on an endpoint that also sets `Access-Control-Allow-Credentials: true` | Echo back the validated request `Origin` as a single explicit value | The Fetch spec's CORS protocol forbids the wildcard on a credentialed response, and browsers enforce this by blocking the response even if the server sends it |
| Conclude "the page never loads the probe" because the collector logged zero requests | Send one `curl -i -X OPTIONS` to the collector and one deliberate `fetch` from the page's console | A collector that 404s the preflight and a probe that never ran produce the same empty log; the OPTIONS probe separates them ([debugging-methodology-probe-path-vs-operation-path]) |
| Debug a CORS failure by relaxing the server to allow every origin | Read the exact console error (it names the missing/mismatched header) and add only that header for the specific origins that need it | A blanket allow-all reopens the endpoint to any site's browser-side JS, including credentialed requests if cookies are involved |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS — simple vs preflighted requests, response headers, wildcard-with-credentials prohibition
- https://fetch.spec.whatwg.org/#http-cors-protocol — CORS-safelisted methods/headers, preflight algorithm, non-wildcard credentialed response requirement
- Field reproduction 2026-09-02 (linkly-crew t2-live-visual-verify, Tauri/WKWebView app with a Node `collector.mjs`): the collector handled only `POST`; a full app rebuild and launch produced zero reports and `curl -X OPTIONS /report` returned 404. After adding an `OPTIONS` branch (204 with `access-control-allow-origin/methods/headers`) and the same headers on POST responses, the unchanged probe delivered 6 reports within 10 s
