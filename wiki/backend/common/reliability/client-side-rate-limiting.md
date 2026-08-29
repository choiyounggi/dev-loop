---
id: backend-common-reliability-client-side-rate-limiting
domain: backend
category: reliability
applies_to: [general]
confidence: verified
sources:
  - https://developer.okta.com/docs/reference/rate-limits/
  - https://support.auth0.com/center/s/article/What-is-the-rate-limit-applied-for-M2M-authentications-calls
  - https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
  - https://developers.openai.com/api/docs/guides/rate-limits
  - https://www.rfc-editor.org/rfc/rfc6585
last_verified: 2026-08-29
related: [backend-common-reliability-timeouts-and-retries, backend-common-auth-jwt-server-side, debugging-concurrency-intermittent-failures, backend-common-integrations-externally-owned-defaults]
---

# A Client-Side Throttle That the Client's Own Requests Bypass

## When this applies

You added a rate limiter (minimum interval, token bucket) to an API client
wrapper and the provider still returns 429 / rate-limit errors —
characteristically on the **first call after process start**, or on some days
and not others. Also when designing the throttle layer of any client whose
requests carry a credential the client itself refreshes.

## Do this

1. **Place the throttle at the lowest layer that issues HTTP** — the
   send/execute method, interceptor, or session hook — not on the
   business-facing methods. Token refresh, discovery lookups, retries, and
   pagination prefetch are requests the provider counts and the public methods
   never name; the transport layer is the only position auth refresh cannot
   bypass.
2. **Count auth and token issuance as requests.** Providers rate-limit their
   token endpoints as their own buckets (Okta's OAuth endpoints, Auth0's
   `/oauth/token`), and exemptions are individually enumerated (JWKS,
   `.well-known` metadata, GitHub's `GET /rate_limit`). Treat "exempt" as a
   documented property: count every request whose endpoint is not on the
   provider's exemption list.
3. **Stamp the throttle clock immediately before the request leaves**, not at
   wrapper entry. Work between the two — a nested token fetch, signing,
   serialization — shortens the real gap below the interval you think you
   enforce.
4. **Give the first call of the process a defined starting state.** A
   `last_request_at = 0` default exempts the first calls from waiting, so an
   unthrottled token POST plus the first data call land in the same second and
   deterministically exceed a small per-second cap.
5. **Consume the provider's accounting headers instead of only modelling its
   limit**, and honour `Retry-After` on 429 before any backoff of your own —
   the server's remaining/reset numbers include requests your model never saw.
6. **Reproduce with a cold credential cache.** Clear the cached token, run, and
   count the outbound requests: a live token removes the extra request, which
   is why the failure looks intermittent and gets filed as provider flakiness.

## Edge cases

| Case | Then |
|------|------|
| A cached credential hides the extra request on most runs | The token-issuance run is the failing case; correlate failure timestamps with token issuance in logs — that schedule-shaped intermittency is the signature |
| The limit is per-second but the wrapper throttles a per-minute average | Enforce the shortest published window; an average that satisfies 120/min still sends 10 in one second |
| Several processes/workers share one credential | The quota is per credential, not per process — move pacing to a shared store (e.g. Redis token bucket) or partition the budget explicitly per worker |
| The token is cached on disk and shared between runs | Only the first process after expiry pays the extra request — schedule a warm-up call at startup so the cost lands outside a user-facing request |
| The provider's limiter is a sliding window | Pace below the nominal limit; requests bunched at a window boundary breach a limit that per-second averaging satisfies |
| The provider counts by cost/points rather than requests | Track the published cost unit; a request counter under-counts expensive calls |
| Retries are added by an HTTP library beneath your throttle | Route the library's retries through the throttling layer or retry above it; otherwise one logical call emits several counted requests |
| The token endpoint has its own (often stricter) published limit | Throttling it with the data calls is still safe, but its own 429 handling needs backoff too |
| Mock/sandbox credentials have a lower quota than production | Pace to the environment's own limit, read from config at startup — a throttle tuned to production silently breaches in sandbox |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Wrap only the public API methods with the throttle | Throttle in the transport layer every request passes through | Auth refresh and retries happen in lower layers a method-level limiter never sees |
| Record the throttle timestamp at wrapper entry | Record it immediately before the send | A token refresh between the two makes the enforced interval shorter than the configured one |
| File a first-call rate-limit error as an intermittent provider fault | Re-run with the credential cache cleared and count outbound requests | The bug fires only on token-issuance runs; reruns silently supply the warm cache that hides it |
| Raise the throttle interval until the errors stop | Count the requests per second the client actually emits | Padding hides an uncounted request instead of counting it, and returns under any timing change |
| Model the provider's window client-side and trust the model | Consume the provider's remaining/reset headers and honour `Retry-After` | The server's accounting includes requests from other processes sharing the credential |

## Sources

- https://developer.okta.com/docs/reference/rate-limits/ — OAuth endpoints carry their own rate-limit buckets; only enumerated public metadata endpoints (`/oauth2/v1/keys`, `.well-known` documents) are exempt
- https://support.auth0.com/center/s/article/What-is-the-rate-limit-applied-for-M2M-authentications-calls — "M2M requests count towards the global authentication API rate limits"; example given: "the global authentication API rate limit for Enterprise customers is 100 requests per second (RPS) per tenant" — `/oauth/token` calls (M2M included) draw down this same published bucket
- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api — OAuth-app requests count against the user's limit; exemptions are named individually
- https://developers.openai.com/api/docs/guides/rate-limits — remaining/reset values returned in response headers for the client to consume
- https://www.rfc-editor.org/rfc/rfc6585 — 429 Too Many Requests and `Retry-After`
- Field incident 2026-08-05 (trading-API client, 2 req/s cap): `_headers()` called `_get_token()` *after* `_throttle()`; on cold-cache days the log shows token POST 00.354 → issued 00.495 → data call rejected 00.543; warm-cache days ran the identical code green, so the failure was filed as intermittent
