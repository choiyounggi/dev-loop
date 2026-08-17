---
id: backend-common-api-design-cors-and-preflight
domain: backend
category: api-design
applies_to: [general]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS
  - https://fetch.spec.whatwg.org/#http-cors-protocol
last_verified: 2026-08-17
related: [security-api-exposure-exposing-an-origin-http-api]
---

# Handling Browser CORS Requests and Preflight

## When this applies

A browser calls your API from a different origin (different scheme, host, or
port) via `fetch`/`XMLHttpRequest`, and the request fails in the browser
console with a CORS error even though a direct `curl` to the same endpoint
succeeds — CORS is enforced by the browser, not the server, so server-side
tools never reproduce it. Also applies when designing which endpoints need
`Access-Control-*` headers and whether the browser will send an OPTIONS
preflight before the real request.

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

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Set `Access-Control-Allow-Origin: *` on an endpoint that also sets `Access-Control-Allow-Credentials: true` | Echo back the validated request `Origin` as a single explicit value | The Fetch spec's CORS protocol forbids the wildcard on a credentialed response, and browsers enforce this by blocking the response even if the server sends it |
| Debug a CORS failure by relaxing the server to allow every origin | Read the exact console error (it names the missing/mismatched header) and add only that header for the specific origins that need it | A blanket allow-all reopens the endpoint to any site's browser-side JS, including credentialed requests if cookies are involved |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS — simple vs preflighted requests, response headers, wildcard-with-credentials prohibition
- https://fetch.spec.whatwg.org/#http-cors-protocol — CORS-safelisted methods/headers, preflight algorithm, non-wildcard credentialed response requirement
