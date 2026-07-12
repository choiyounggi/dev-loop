---
id: security-api-exposure-exposing-an-origin-http-api
domain: security
category: api-exposure
applies_to: [general, fastapi, http-api]
confidence: verified
sources:
  - https://owasp.org/www-project-secure-headers/
  - https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Content-Type-Options
  - https://www.starlette.io/middleware/
  - https://fastapi.tiangolo.com/tutorial/metadata/#docs-urls
last_verified: 2026-07-11
related: [security-input-validation-at-trust-boundaries, backend-common-api-design-error-responses]
---

# Exposing an Origin HTTP API to the Public Internet

## When this applies

You are putting an HTTP API written for internal/localhost use behind a public
entry point (reverse proxy, CDN, or tunnel such as Cloudflare Tunnel) so
untrusted clients reach it directly. This page owns the *code-side* controls; the
edge/platform owns TLS, rate limiting, and WAF.

## Do this

First draw the code-vs-edge line, then apply every code-side control:

| Concern | Code (origin) does | Edge/platform does |
|---------|--------------------|--------------------|
| Auth | Verify key/token per request, **fail closed** | Optional proxy-secret injection |
| TLS / HSTS | Serve plain HTTP bound to loopback only | Terminate TLS, set HSTS |
| Rate limit / request size | Nothing — do not build it in code | Rate-limit + WAF + body caps |
| Input validation | Whitelist/parse every param at the boundary | — |
| Response hardening | Security headers + sanitized errors + no schema | — |

Code-side controls, all required:

1. **Auth fail-closed and header-only.** Reject when no valid key is present; an
   empty allow-list must reject everything, not allow. Read keys from headers
   only — never from a query param (URLs are logged and cached).
2. **Set security response headers on _every_ response, including 5xx.** Minimum:
   `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`,
   `Content-Security-Policy: default-src 'none'`, `Cache-Control: no-store` on
   authenticated data, and overwrite `Server` to drop framework/version.
3. **Turn off interactive docs and the schema at the origin by default.** Serve
   `/docs` `/redoc` `/openapi.json` only behind an explicit opt-in — the schema
   hands an attacker every route, param, and type.
4. **Sanitize errors.** A 500 returns a generic body; log the real cause
   server-side only. Never return stack traces, file paths, or SQL.
5. **Validate every input at the boundary** so malformed/oversized/injection
   input is rejected before it reaches logic
   ([security-input-validation-at-trust-boundaries]); shape error bodies per
   [backend-common-api-design-error-responses].

## Edge cases

| Case | Then |
|------|------|
| 5xx responses miss your security headers | Error responses are emitted by the outermost error middleware, *outside* your header middleware (Starlette `ServerErrorMiddleware`, Express default handler). Set the headers **also inside the exception handler** — verify with a forced 500, not just a 2xx |
| A "dev mode" flag disables auth | One misset env var in prod = total exposure. Keep it out of prod config and log a warning at startup when it is on |
| Auth'd data cached by a shared CDN | `Cache-Control: no-store` (or `private`) on authenticated responses so a shared cache never serves one client's data to another |
| Pagination cursor exposes an internal sequential id | Acceptable when the id grants no access and the data is public; sign/opaque-encode the cursor when id enumeration or volume inference is sensitive |
| Reflected input echoed in a validation error | Safe in a JSON body with `nosniff` + `default-src 'none'`; still cap the input's length/charset at the boundary so nothing large or binary is echoed |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build rate limiting / IP allow-listing into the app | Enforce it at the edge (WAF/CDN) | The edge sees all traffic and sheds load before it reaches your process |
| Set security headers only in request middleware | Also set them in the 5xx/exception path | Error responses bypass request middleware and would ship bare |
| Leave Swagger UI / OpenAPI public "for convenience" | Disable at the origin; opt in explicitly | The schema is a free map of your attack surface |
| Accept an API key from a query parameter | Header only | Query strings land in access logs, proxies, and browser history |

## Sources

- https://owasp.org/www-project-secure-headers/ — recommended security response headers and values
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Content-Type-Options — nosniff MIME-type enforcement
- https://www.starlette.io/middleware/ — middleware ordering; ServerErrorMiddleware is outermost, so 5xx bypasses inner middleware
- https://fastapi.tiangolo.com/tutorial/metadata/#docs-urls — disabling docs_url/redoc_url/openapi_url
