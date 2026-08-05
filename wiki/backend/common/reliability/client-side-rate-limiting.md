---
id: backend-common-reliability-client-side-rate-limiting
domain: backend
category: reliability
applies_to: [general]
confidence: field-tested
sources:
  - https://developer.okta.com/docs/reference/rate-limits/
  - https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy/authentication-api-endpoint-rate-limits
last_verified: 2026-08-05
related: [backend-common-reliability-timeouts-and-retries]
---

# Client-Side Throttles That Miss Auth Requests

## When this applies

You added a requests-per-second throttle to an API client wrapper, yet the
provider still returns rate-limit errors — especially on the **first call of a
process**, or only on some days. Also when designing the throttle layer of any
client whose requests carry a token the client itself refreshes.

## Do this

1. **Route every HTTP request through the throttle, including token/auth
   acquisition.** Identity providers rate-limit their auth endpoints like any
   other endpoint (Auth0 limits its Authentication API endpoints; Okta's
   org-wide rate-limit buckets cover the OAuth2 endpoints), and a token POST
   plus the first real API call land in the same second — deterministically
   exceeding a low per-second cap.
2. **Audit the interceptor path.** Token refresh usually happens inside a
   header-builder or request interceptor, which sits *below* a wrapper-level
   throttle and silently bypasses it. The throttle must wrap the layer that
   actually performs HTTP, not the layer that composes calls.
3. **Stamp the throttle timestamp immediately before the request goes out**,
   not at wrapper entry — work done between the stamp and the send (like a
   nested token fetch) otherwise consumes the gap the stamp claimed.
4. **Check the initial state.** A `last_request_at = 0` default makes the
   first gap check pass trivially; the first two physical requests of the
   process then go out unthrottled.

## Edge cases

| Case | Then |
|------|------|
| The failure reproduces only on some days and looks like provider flakiness | Correlate failure timestamps with token issuance in logs: a cached token skips the extra request, so the bug only fires when the cache is cold/expired — that schedule-shaped intermittency is the signature |
| The provider counts limits per endpoint, not globally | The token POST may have its own (often stricter) limit; throttling it with the data calls is still safe, but its own 429 handling needs backoff too |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Dismiss first-call rate-limit errors as intermittent provider issues | Diff a failing day's log against a working day's around the first call | The extra token request is visible as one added line; the "intermittency" is the token cache's TTL |
| Throttle at the public-method layer of the client | Throttle at the transport layer every request traverses | Auth refresh, retries, and pagination helpers all issue requests the public layer never sees |

## Sources

- https://developer.okta.com/docs/reference/rate-limits/ — Okta's org-wide rate-limit buckets cover the OAuth2 endpoints; only the public metadata endpoints (`/oauth2/v1/keys`, the `.well-known` documents) are exempt
- https://auth0.com/docs/troubleshoot/customer-support/operational-policies/rate-limit-policy/authentication-api-endpoint-rate-limits — Auth0 limits the number of requests made to Authentication API endpoints, which include the token endpoint
- Field incident 2026-08-05 (`stock-trader` `kis_client.py`, 2 req/s provider cap): `_headers()` called `_get_token()` *after* `_throttle()`, so on token-issue days the log shows token POST at 00.354 → token issued 00.495 → balance call rejected 00.543; on cached-token days the identical code passed, which had the failure filed as intermittent
