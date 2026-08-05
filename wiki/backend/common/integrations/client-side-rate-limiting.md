---
id: backend-common-integrations-client-side-rate-limiting
domain: backend
category: integrations
applies_to: [general]
confidence: field-tested
sources:
  - https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
  - https://developer.okta.com/docs/reference/rate-limits/
  - https://developers.openai.com/api/docs/guides/rate-limits
  - https://www.rfc-editor.org/rfc/rfc6585
last_verified: 2026-08-05
related: [backend-common-reliability-timeouts-and-retries, backend-common-integrations-externally-owned-defaults, debugging-concurrency-intermittent-failures, backend-common-auth-jwt-server-side]
---

# A Client-Side Throttle That the Client's Own Requests Bypass

## When this applies

You added a rate limiter to an API client wrapper and the provider still returns
429 / "too many requests" — especially on the first call after process start, or
only on some days. Also when a rate-limit failure is filed as "intermittent"
because a rerun minutes later succeeds.

## Do this

1. **Place the throttle where every outbound request passes**, at the transport
   layer — the interceptor, session hook, or `send()` override — not on the
   business-facing methods. Token refresh, discovery/metadata lookups, retries,
   and pagination prefetch are requests the provider counts and the wrapper's
   public methods do not name.
2. **Count auth and token issuance as requests.** Providers exempt only the
   endpoints they explicitly list, and the lists cited below name only public
   metadata endpoints (JWKS, discovery, a limit-status endpoint) — not token
   issuance. Treat "exempt" as a documented property: count every request whose
   endpoint you cannot find on the provider's exemption list.
3. **Stamp the throttle clock immediately before the request leaves**, not when
   the wrapper method is entered. Work between the two — a token fetch, a
   signature computation, a DNS resolution — moves the real send into the next
   window's neighbour.
4. **Give the first call of the process a defined starting state.** A "last
   request at" initialized to zero or epoch makes the first N calls skip the wait
   entirely, so a burst at startup exceeds a small per-second limit
   deterministically while a warm process never reproduces it.
5. **Read the provider's own accounting headers rather than modelling its
   limit.** Consume the remaining/reset/retry-after headers and back off from
   them; a client-side counter is a courtesy layer, and the server's numbers are
   the only authority on what has been spent.
6. **Honour `Retry-After` on 429 before any backoff of your own.** The status is
   defined for this case and the header carries the wait the server wants.

## Edge cases

| Case | Then |
|------|------|
| A cached credential hides the extra request on most runs | Reproduce with the cache cleared — the token-issuance day is the failing case, and the code path that only runs then is the one to inspect |
| The limit is per-second and the wrapper throttles per-minute averages | Enforce the shortest published window; an average that satisfies 120/min still sends 10 in one second |
| Several processes or workers share one credential and one quota | The quota is per credential, not per process — move the throttle to a shared store, or partition the budget explicitly per worker |
| The provider counts by cost/points rather than by request | Track the published cost unit; a request counter under-counts expensive calls and over-throttles cheap ones |
| Retries are added by an HTTP library beneath your throttle | Configure the library's retry policy through the same layer that throttles, or disable it and retry above the throttle; otherwise each logical call can emit several counted requests |
| A metadata/discovery endpoint is documented as exempt | Keep it outside the counter, and cite the doc line in a comment — the exemption is the provider's to change |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Wrap only the public API methods with the throttle | Throttle in the transport layer every request passes through | Auth refresh and retries happen inside lower layers, so they never reach a method-level limiter |
| Classify a rate-limit failure as intermittent because a rerun passed | Check whether the failing runs share a state the passing runs lack (cold cache, expired token, process start) | A failure conditional on cache state is deterministic given that state, and reruns silently supply the state that hides it |
| Model the provider's window in the client and trust the model | Consume the provider's remaining/reset headers and honour `Retry-After` | The server's accounting includes requests your model never saw, from other processes sharing the credential |
| Initialize "last request at" to zero so the first call is never delayed | Initialize so the first call is subject to the same spacing, or seed from the first send | The unthrottled prefix is exactly the startup burst that trips a per-second limit |

## Sources

- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api — requests count against the authenticated user's limit, and exemptions are named individually (`GET /rate_limit` "does not count against your primary rate limit"): exemption is an enumerated property, not a default for meta requests
- https://developer.okta.com/docs/reference/rate-limits/ — only specific public metadata endpoints (`/oauth2/v1/keys`, `/.well-known/openid-configuration`, `/.well-known/oauth-authorization-server`) are listed as not subject to rate limits, while OAuth endpoints such as `/oauth2/v1/authorize` are rate limited
- https://developers.openai.com/api/docs/guides/rate-limits — limits are enforced per window with the remaining/reset values returned in response headers for the client to consume
- https://www.rfc-editor.org/rfc/rfc6585 — 429 Too Many Requests, and `Retry-After` as the server-supplied wait before a further request
- Field observation 2026-08-05: an API client throttled inside its public methods issued the token POST from within its header-building path, after the throttle had already waited; on days the token cache was cold, the token POST and the following GET landed in the same second and exceeded a 2/second limit, while cache-warm days ran the identical code without failing — logged at 00.354 (token POST), 00.495 (token issued), 00.543 (rejected call)
