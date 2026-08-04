---
id: backend-common-reliability-client-side-rate-limiting
domain: backend
category: reliability
applies_to: [general]
confidence: field-tested
sources:
  - https://developer.okta.com/docs/reference/rl2-token-oauth/
  - https://developer.ebay.com/api-docs/static/oauth-rate-limits.html
  - https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
  - https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/
last_verified: 2026-08-04
related: [backend-common-reliability-timeouts-and-retries, backend-common-auth-jwt-server-side, debugging-concurrency-intermittent-failures]
---

# Throttling Your Own Calls Against a Provider's Per-Second Quota

## When this applies

You wrapped an external API client in a throttle that spaces requests to stay
under a documented per-second or per-minute quota, and the provider still
returns rate-limit errors — particularly on the process's first call, or on
scattered days with no pattern in the payloads.

## Do this

1. **Count every HTTP request the wrapper causes, not every public method it
   exposes.** A throttle placed on the public methods misses requests issued from
   inside header building, auth refresh, interceptors, discovery/metadata lookups,
   and pagination follow-ups. Enumerate the wrapper's outbound calls by searching
   for the HTTP verb functions, not for the throttle decorator.
2. **Put the token/credential fetch through the same counter as the calls it
   authorizes.** Providers meter the token endpoint — Okta, eBay, and GitHub all
   publish limits attached to it — and even where the buckets are separate, a token
   POST and the API GET it enables leave in the same instant and land in the same
   quota window from the server's point of view.
3. **Stamp the throttle's clock immediately before the request leaves**, not when
   the wrapper method is entered. Work between the two — a token fetch, a signature
   computation, a retry sleep — is time the throttle believes it already spent.
4. **Give the cold-start state a real value.** A `last_request_at` initialised to
   `0`/`None` makes the first elapsed-time computation enormous, so the first call
   skips the wait entirely. Initialise it to the process start instant, or special-
   case the first request to take the full interval.
5. **Assert the throttle against a cold process, not a warm one**, and with the
   credential cache empty. A cold cache is the state where the hidden extra
   request exists.

## Edge cases

| Case | Then |
|------|------|
| Failures appear only on scattered days and never reproduce | Correlate the failing timestamps with credential issuance rather than with load — a token valid for N hours makes the extra request appear only on the day it is minted ([debugging-concurrency-intermittent-failures]) |
| The provider meters the token endpoint in its own bucket | Still serialise the two through one counter; the shared resource being protected is your own outbound concurrency, which the server sees as one client |
| Several processes or workers share the credentials | An in-process throttle bounds one process only; move the counter to a shared store or partition the quota per worker explicitly |
| The client library refreshes credentials on its own schedule (background thread, interceptor) | Wrap the library's transport layer instead of its methods, so the refresh cannot route around the counter |
| The provider returns `429` with `Retry-After` | Honour the header, then re-derive the throttle interval from the observed limit rather than keeping the value that was already too fast ([backend-common-reliability-timeouts-and-retries]) |
| The retry layer sits outside the throttle | Retries re-enter through the throttle, or the backoff and the spacing multiply into a slower client than either intends |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Decorate the public API methods with a rate limiter and call the client throttled | Instrument the transport layer every request passes through | Auth refresh and interceptor traffic never calls the public methods, so it bypasses a method-level throttle entirely |
| Treat first-call rate-limit errors as a provider flake | Reproduce with an emptied credential cache on a cold process | The failure is deterministic in that state and invisible in every other one |
| Initialise the last-request timestamp to zero | Initialise it to the process start instant | `now - 0` exceeds any interval, so the throttle waives exactly the request that is paired with an unaccounted token fetch |
| Record the throttle's timestamp on wrapper entry | Record it at the moment of dispatch | Any work between entry and dispatch is charged to the interval without any request having been sent |

## Sources

- https://developer.okta.com/docs/reference/rl2-token-oauth/ — OAuth 2.0 token endpoints carry their own published rate limits, separate from the org-wide API limits
- https://developer.ebay.com/api-docs/static/oauth-rate-limits.html — rate limits assigned to the token endpoint itself, varying by grant type
- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api — access-token requests are limited independently of REST API calls, and some request classes count towards separate buckets
- https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/ — client-side limiting and backoff belong at the layer that issues requests
- Field incident 2026-08-04 (brokerage API client, documented quota 2 requests/second): the wrapper's `_throttle()` ran on the public methods, then `_headers()` called `_get_token()` inside the same call, so a token `POST` and the following balance `GET` both left within one second. The failing-day logs (2026-07-23, 2026-08-04) show token POST at `00.354`, issuance at `00.495`, balance rejected at `00.543`; on days when the cached token was still valid the identical code path succeeded, which is what made it read as an intermittent fault
